import 'package:clash_party/common/render_capability.dart';
import 'package:clash_party/widgets/liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 液态玻璃：按机器能力分档，弱机自动退回不模糊的纯色。
///
/// **为什么不打两个安装包**（用户问过）：同类客户端里 v2rayNG、sing-box for
/// Android 都是 minSdk 24，Clash Meta for Android 是 21，**没有一个按系统版本分
/// 包**。业界做法就是一个包、运行时判断——分包要维护双份构建与测试，用户还会下错。
///
/// **也不按安卓版本号分档**：版本号和性能没关系。安卓 16 的百元机扛不住实时模糊，
/// 安卓 8 的旗舰跑得动。判据取自设备自己的回答（低内存标记、物理内存、64 位 ABI）。
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required RenderTier tier,
    bool disableAnimations = false,
  }) async {
    RenderCapability.setTierForTest(tier);
    addTearDown(() => RenderCapability.setTierForTest(RenderTier.full));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: LiquidGlass(
              borderRadius: BorderRadius.circular(24),
              child: const SizedBox(width: 200, height: 48),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double? blurSigma(WidgetTester tester) {
    final filters = tester.widgetList<BackdropFilter>(
      find.byType(BackdropFilter),
    );
    if (filters.isEmpty) {
      return null;
    }
    // `ImageFilter` 没有公开的读取接口，但它的 toString 里带着 sigma。
    final text = filters.first.filter.toString();
    final match = RegExp(
      r'(?:sigmaX:\s*|ImageFilter\.blur\()([\d.]+)',
    ).firstMatch(text);
    return match == null ? null : double.parse(match.group(1)!);
  }

  testWidgets('完整档：有模糊，而且半径最大', (tester) async {
    await pump(tester, tier: RenderTier.full);
    expect(blurSigma(tester), 24.0);
  });

  testWidgets('减配档：仍然模糊，但半径减半', (tester) async {
    await pump(tester, tier: RenderTier.light);
    expect(blurSigma(tester), 12.0);
  });

  testWidgets('关闭档：完全不模糊', (tester) async {
    await pump(tester, tier: RenderTier.none);

    // 实时模糊是**逐帧重采样整块背景**，弱机上掉帧最明显的就是它。
    expect(
      find.byType(BackdropFilter),
      findsNothing,
      reason: '弱机上仍然在做模糊，那这个分档就白做了',
    );
  });

  testWidgets('关闭档必须给不透明底，不能只是半透明', (tester) async {
    await pump(tester, tier: RenderTier.none);

    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(LiquidGlass),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final color = (box.decoration as BoxDecoration).color!;
    // 半透明而**不模糊**，背后的文字会直接透上来和前景叠在一起——比没有效果还糟。
    expect(color.a, 1.0, reason: '不模糊时底色是半透明的，背后内容会透上来糊成一片');
  });

  testWidgets('系统开了「移除动画」时一律不模糊，哪怕机器扛得住', (tester) async {
    await pump(tester, tier: RenderTier.full, disableAnimations: true);

    // 这是用户明确表达的偏好，**优先于性能判断**。开这个开关的人往往对动态效果
    // 敏感（前庭功能障碍），给静态纯色才是对的。
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
