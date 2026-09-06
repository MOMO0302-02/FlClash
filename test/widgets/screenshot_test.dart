import 'dart:io';
import 'dart:ui' as ui;

import 'package:clash_party/common/app_style.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 把真实组件渲染成 PNG 存到 `temp/shots/`，用来在**没有设备**的情况下看效果。
///
/// 为什么需要它：手机会掉线，模拟器在本机跑不起来（虚拟化未开）。布局测试只能
/// 回答「有没有溢出」，回答不了「长什么样」。这组测试把界面真画出来，落成图片。
///
/// 注意：`flutter test` 默认没有任何字体，中文会渲染成方块。这里从系统里加载
/// 黑体（`C:/Windows/Fonts/simhei.ttf`）解决。

const _outDir = 'temp/shots';
const _cnFont = 'ScreenshotCJK';

Future<void> _loadFont() async {
  final file = File('C:/Windows/Fonts/simhei.ttf');
  if (!file.existsSync()) {
    // 换机器时字体路径可能不同；没有字体只影响文字，不影响布局，不让测试失败。
    return;
  }
  final bytes = await file.readAsBytes();
  final loader = FontLoader(_cnFont)
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

/// 渲染 [child] 并写出 PNG。
Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget child, {
  Size size = const Size(400, 260),
}) async {
  // physicalSize 是物理像素，逻辑尺寸要除以 dpr。之前直接把 size 当物理像素塞
  // 进去，dpr=2 就等于把界面压到一半宽高渲染——卡片被挤到 15 像素高、真的溢出了。
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = size * 2.0;
  addTearDown(tester.view.reset);

  // globalState.theme 是 late 字段，必须在真正的界面构建前赋好
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          globalState.theme = CommonTheme.of(context, 1.0);
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  const tokens = AppStyleTokens.clashParty;
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: _cnFont,
        colorScheme: ColorScheme.fromSeed(
          seedColor: tokens.seed,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
        extensions: <ThemeExtension<dynamic>>[tokens],
      ),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  // 不用 pumpAndSettle：涟漪和淡入是持续动画，它会一直等到超时。
  await tester.pump(const Duration(milliseconds: 400));

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // 必须放在 runAsync 里：toImage / toByteData 由引擎线程完成，而测试默认跑在
  // 假异步时钟里，直接 await 会一直等不到结果——图片写出来了，用例却卡到超时。
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(_loadFont);

  // 每个用例只画一张图：在同一个用例里连续多次 pumpWidget + toImage 会卡住。

  testWidgets('卡片', (tester) async {
    await _shoot(
      tester,
      'cards',
      Row(
        children: [
          for (final selected in [true, false])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: SizedBox(
                  height: 80,
                  child: CommonCard(
                    isSelected: selected,
                    info: const Info(
                      label: '网络检测',
                      iconData: Icons.wifi_tethering,
                    ),
                    onPressed: () {},
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      alignment: Alignment.bottomLeft,
                      child: const Text('192.168.31.181'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      size: const Size(420, 130),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('空状态：带说明与动作', (tester) async {
    await _shoot(
      tester,
      'empty_with_action',
      NullStatus(
        label: '还没有订阅',
        description: '添加一个订阅后，节点和规则才会出现',
        action: FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('添加订阅'),
        ),
      ),
      size: const Size(420, 520),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
