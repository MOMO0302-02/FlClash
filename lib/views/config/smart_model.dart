/// Smart 选路模型（`Model.bin`）的状态查询与手动下载。
///
/// **桌面端没有对应界面。** 桌面版只有 `src/main/core/smartModel.ts`，做的是把
/// 已经存在的 `Model.bin` 复制进配置检查用的临时目录（那是 PR #2110 修的另一件
/// 事），它既不显示模型状态，也没有下载按钮。所以这一整块是安卓端自己加的。
///
/// **为什么安卓端非加不可**：实测在模拟器上，配置里 `type: smart` 和
/// `uselightgbm: true` 都写对了、内核也接受了，但内核跑起来之后整个应用目录里
/// **找不到 `Model.bin`** —— 内核自带的那个下载器没能把文件拿下来，而应用生成的
/// 配置又是 `log-level: error`，内核那几行说明性日志（`[Smart] Can't find
/// Model.bin, start download`）全被滤掉了。结果就是：用户以为自己开着 LightGBM，
/// 实际上一直在空转，且**没有任何地方能看出来**。这个文件解决的就是"看得出来"
/// 和"能自己拿一次"。
///
/// **为什么不调内核的 `POST /upgrade/lgbm`**：安卓端的控制面不走 HTTP
/// （`lib/core/method.dart` 是一张固定的方法表，走 FFI/平台通道），表里没有
/// 触发模型更新的方法。要用那个接口就得改 `core/*.go` 加导出、再改
/// `lib/core/`——两处都不在本次改动范围内。而下载一个文件放到内核的工作目录，
/// Dart 侧自己就能干净地做完，不需要动任何一边。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clash_party/common/common.dart';
import 'package:path/path.dart';

/// 模型文件现在是什么状态。
enum SmartModelState {
  /// 文件不在。内核会退回"按延迟挑"，LightGBM 那个开关等于没开。
  missing,

  /// 文件在，但内容不完整。**这是最坏的一种**，比没有还糟：内核每次做配置检查
  /// 都会硬失败（`failed to load binary model`），整个内核起不来，而且它自己
  /// 重试又会再写一个残片，用户不手工删就永远出不来。
  damaged,

  /// 文件在且看着是完整的。
  ready,
}

class SmartModelStatus {
  const SmartModelStatus({required this.state, this.size = 0, this.modified});

  final SmartModelState state;
  final int size;
  final DateTime? modified;

  static const missing = SmartModelStatus(state: SmartModelState.missing);
}

/// 完整模型的开头。LightGBM 的文本格式，第一行就是 `tree`。
const _modelHeader = 'tree';

/// 完整模型的结尾。vernesong 那套模型最后一段是 `[target_enhance]`，
/// 收尾正好是这个闭合标记。
///
/// **这是启发式判断，不是格式规范**：真正的校验是把模型加载一遍，那件事只有
/// 内核（LightGBM 运行时）做得到。选这个标记是因为它能抓住实际发生过的那次
/// 事故——用户机器上那个 2,231,744 字节的残片和完整的 21,422,159 字节文件
/// **开头一模一样**（都是 `tree`），只有结尾能把它们分开：完整的收在
/// `[/target_enhance]`，残片断在一个数字中间。
///
/// 误判方向是安全的：万一将来的模型不带这一段，这里会说"不完整"，用户重新下
/// 一次就好；反过来把残片放过去，代价是内核起不来。
const _modelFooter = '[/target_enhance]';

/// 判断状态时只读文件的头尾各这么多字节，不把整个文件（最大 26 MB）读进内存。
const smartModelProbeSize = 64;

/// 光看头尾能不能认为这个模型是完整的。
///
/// 拆成纯函数是为了能直接测：给几段假字节就能验，不用真去下一个 26 MB 的模型。
bool smartModelLooksComplete({
  required List<int> head,
  required List<int> tail,
  required int length,
}) {
  if (length <= 0) {
    return false;
  }
  // 只比 ASCII，用 latin1 是为了任意字节都能解出来不抛异常。
  if (!latin1.decode(head, allowInvalid: true).startsWith(_modelHeader)) {
    return false;
  }
  return latin1
      .decode(tail, allowInvalid: true)
      .trimRight()
      .endsWith(_modelFooter);
}

/// 整块字节的版本，下载完之后用。
bool smartModelBytesLookComplete(List<int> bytes) {
  if (bytes.length <= smartModelProbeSize) {
    // 比探测窗口还短的一定不是模型（最小的标准版也有 9 MB）。
    return false;
  }
  return smartModelLooksComplete(
    head: bytes.sublist(0, smartModelProbeSize),
    tail: bytes.sublist(bytes.length - smartModelProbeSize),
    length: bytes.length,
  );
}

/// 内核放 `Model.bin` 的地方。
///
/// 内核是以 `homeDir` 启动的（`lib/core/controller.dart:77` 把
/// `appPath.homeDirPath` 传进 `InitParams`），LightGBM 就在那个目录里认死
/// `Model.bin` 这个名字。
Future<String> get smartModelPath async {
  final home = await appPath.homeDirPath;
  return join(home, smartModelFileName);
}

/// 读一次磁盘，看模型现在什么样。
///
/// 任何异常都当成"没有"——这一行只是用来显示状态的，不该因为读不到文件就把
/// 整个设置页搞崩。
Future<SmartModelStatus> readSmartModelStatus() async {
  try {
    final file = File(await smartModelPath);
    if (!await file.exists()) {
      return SmartModelStatus.missing;
    }
    final stat = await file.stat();
    final length = stat.size;
    if (length <= smartModelProbeSize) {
      return SmartModelStatus(
        state: SmartModelState.damaged,
        size: length,
        modified: stat.modified,
      );
    }
    final handle = await file.open();
    try {
      final head = await handle.read(smartModelProbeSize);
      await handle.setPosition(length - smartModelProbeSize);
      final tail = await handle.read(smartModelProbeSize);
      final complete = smartModelLooksComplete(
        head: head,
        tail: tail,
        length: length,
      );
      return SmartModelStatus(
        state: complete ? SmartModelState.ready : SmartModelState.damaged,
        size: length,
        modified: stat.modified,
      );
    } finally {
      await handle.close();
    }
  } catch (_) {
    return SmartModelStatus.missing;
  }
}

/// 模型尺寸。
///
/// **为什么要做成可选**：内核内置的地址下的永远是标准版；想要更准的大模型，
/// 用户得先知道有三种尺寸、再自己找到 URL 填进输入框——等于把选择权藏起来了。
/// 三个地址与体积都实测确认过（HTTP 200 + Content-Length，2026-09-04）。
///
/// 模型越大选路越准，代价是下载流量和内存占用。手机上默认标准版是稳妥的。
enum SmartModelSize {
  /// 8.9 MB。内核内置地址用的就是这个。
  standard('Model.bin', 9345218),

  /// 17.5 MB。
  middle('Model-middle.bin', 18357364),

  /// 25.5 MB。
  large('Model-large.bin', 26787747);

  const SmartModelSize(this.fileName, this.bytes);

  /// 发布文件名。
  final String fileName;

  /// 实测字节数。只用于在界面上标出体积，**不用来校验下载结果**——
  /// 作者更新模型时体积会变，拿它当校验条件会把新模型判成损坏。
  final int bytes;

  String get url =>
      'https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/$fileName';
}

/// 内核内置的下载地址（vernesong 源码 `component/smart/lightgbm/lightgbm.go:571`）。
/// 用户在设置里留空时用它——就是标准版。
const defaultSmartModelUrl =
    'https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin';

/// 手动下一次模型。
///
/// 三条纪律，都是冲着"别把用户搞到比现在更惨"来的：
///
/// 1. **先下到临时文件，验过了再改名顶上去。** 改名在同一个目录里是原子的，
///    内核要么看到旧的、要么看到新的，绝不会读到半个。
/// 2. **验不过就什么都不动。** 原来那个模型哪怕是旧的，也比一个能让内核起不来
///    的残片强。
/// 3. **不先删旧的再下新的。** 网断在中间时用户至少还剩原来那个。
Future<SmartModelStatus> downloadSmartModel({String url = ''}) async {
  final target = File(await smartModelPath);
  final temp = File('${target.path}.download');
  try {
    final response = await request.getFileResponseForUrl(
      url.isEmpty ? defaultSmartModelUrl : url,
    );
    final Uint8List? bytes = response.data;
    if (bytes == null || !smartModelBytesLookComplete(bytes)) {
      throw currentAppLocalizations.smartModelInvalid;
    }
    await temp.safeWriteAsBytes(bytes);
    await temp.rename(target.path);
  } finally {
    // 成功时 rename 已经把临时文件挪走了，这里是空操作；失败时它负责收尾。
    await temp.safeDelete();
  }
  return readSmartModelStatus();
}
