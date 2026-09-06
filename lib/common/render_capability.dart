import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';

/// 这台机器扛得住多重的实时绘制效果。
///
/// **为什么不按安卓版本号判断**：版本号和性能没关系。安卓 16 的百元机一样扛不住
/// 实时高斯模糊，而一台安卓 8 的旗舰跑得动。按版本号分档必然误判。
///
/// 也**不打两个安装包**。同类客户端（v2rayNG、sing-box for Android 都是 minSdk 24，
/// Clash Meta for Android 是 21）没有一个按系统版本分包的——业界做法就是一个包、
/// 运行时判断。分包的代价是双份构建与测试、用户还会下错。
enum RenderTier {
  /// 完整：实时模糊 + 边缘高光。
  full,

  /// 减配：模糊半径减半，去掉最贵的那层叠加。
  light,

  /// 关掉：只用半透明纯色。**实时模糊在弱机上是逐帧重采样整块背景**，
  /// 掉帧最明显的就是它。
  none;

  bool get blurs => this != RenderTier.none;
}

/// 判定结果。开销只在启动时算一次。
class RenderCapability {
  RenderCapability._();

  static RenderTier _tier = RenderTier.full;

  /// 桌面端一律给完整效果——那边有独显、也没有低内存设备这一说。
  static RenderTier get tier => _tier;

  /// 启动时算一次。
  ///
  /// 判据全部取自**设备自己的回答**，不是猜的：
  /// * `isLowRamDevice` —— 安卓系统自己的 `ActivityManager.isLowRamDevice()`。
  ///   厂商在低配机上会置位，这是最权威的一条。
  /// * `physicalRamSize` —— 实际物理内存（MB）。
  /// * `supported64BitAbis` —— 只有 32 位 ABI 的机器都很老，GPU 也弱。
  static Future<void> init() async {
    final info = await DeviceInfoPlugin().deviceInfo;
    if (info is! AndroidDeviceInfo) {
      _tier = RenderTier.full;
      return;
    }
    if (info.isLowRamDevice || info.supported64BitAbis.isEmpty) {
      _tier = RenderTier.none;
      return;
    }
    // 单位是 MB。3 GB 以下的机器跑实时模糊会明显掉帧；6 GB 以上才给完整效果。
    final ram = info.physicalRamSize;
    _tier = ram >= 6144
        ? RenderTier.full
        : ram >= 3072
        ? RenderTier.light
        : RenderTier.none;
  }

  /// 结合无障碍设置得到最终档位。
  ///
  /// 系统里的「移除动画」是用户明确表达的偏好——**它比性能判断优先**。开了它的人
  /// 往往对动态效果敏感（前庭功能障碍），给他们静态的纯色底才是对的。
  static RenderTier effective(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return RenderTier.none;
    }
    return _tier;
  }

  /// 只给测试用：直接指定档位。
  @visibleForTesting
  static void setTierForTest(RenderTier tier) => _tier = tier;
}
