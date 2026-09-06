import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clash_party/common/app_style.dart';
import 'package:clash_party/widgets/card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 卡片的阴影与描边必须和桌面端画出来一样。
///
/// **对照组不是「读源码猜的值」，是真的把桌面端那段 CSS 用 Chrome 无头渲染出来
/// 逐像素量的。** 复现方法（探针留在 `temp/rim-probe.html`、`temp/shadow-probe.html`）：
/// 把卡片 `#18181b`、圆角 14、加上 HeroUI 的 `shadow-medium`，页面底色分别用
/// 纯黑和中灰 `#808080`，`chrome --headless --force-device-scale-factor=1
/// --screenshot`，再用 PIL 读像素。实测结果：
///
/// 描边（页面纯黑、卡片本色 24）：
///
/// | 画法 | 边缘像素 |
/// |---|---|
/// | 什么都不画 | 24 |
/// | 桌面端 `inset 0 0 1px rgb(255 255 255/.15)` | **26** |
/// | `inset 0 0 0 1px`（实线边框，= 之前安卓端的画法） | 58 |
///
/// 深色阴影（中灰底 128，卡片下边缘往下数）：
/// +0→109、+10→119、+20→125、+32→128。
///
/// 浅色阴影（同上，用浅色那组 CSS）：+0→117、+10→125、+20→127。
///
/// 这组测试就是把上面这些数字钉住。**改 `cardShadow` / `rim` 之前先回去重测，
/// 别凭 CSS 里的 0.15 直接当边框透明度用**——那正是把边缘画到 58 的原因。
void main() {
  const boundaryKey = ValueKey('parity');

  /// 中灰底。桌面端深色页面是纯黑，黑阴影在黑底上根本看不见，量不出任何东西；
  /// 换成中灰才能把阴影的形状显出来。这不改阴影本身，只是让它可测。
  const probeBackground = Color(0xFF808080);

  const viewSize = 300;
  const cardWidth = 120;
  const cardHeight = 80;
  // 卡片居中：左 90 右 210、上 110 下 190（190 是卡片外面第一行）。
  const cardLeft = (viewSize - cardWidth) ~/ 2;
  const cardTop = (viewSize - cardHeight) ~/ 2;
  const cardBottom = cardTop + cardHeight;
  const centerX = viewSize ~/ 2;

  ThemeData themeFor(Brightness brightness) {
    const tokens = AppStyleTokens.clashParty;
    var scheme = ColorScheme.fromSeed(
      seedColor: tokens.seed,
      brightness: brightness,
      dynamicSchemeVariant: tokens.schemeVariant,
    );
    scheme = tokens.surfacesFor(brightness)?.applyTo(scheme) ?? scheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: const <ThemeExtension<dynamic>>[tokens],
    );
  }

  /// 画一张卡片，返回取像素的函数。
  Future<List<int> Function(int x, int y)> shoot(
    WidgetTester tester, {
    required Brightness brightness,
    bool isSelected = false,
  }) async {
    // 阴影在 flutter_test 里默认被关掉（debugDisableShadows），画出来是没模糊的
    // 硬边方块。不打开这个开关，量到的东西和真机毫无关系。
    //
    // 必须在**取完像素之后立刻关回去**：框架在测试体跑完、tearDown 之前就会校验
    // 「绘制类调试开关有没有被改动」，放 addTearDown 里太晚，会额外炸一条
    // debugAssertAllPaintingVarsUnset。
    debugDisableShadows = false;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themeFor(brightness),
        home: RepaintBoundary(
          key: boundaryKey,
          child: ColoredBox(
            color: probeBackground,
            child: Center(
              child: SizedBox(
                width: cardWidth.toDouble(),
                height: cardHeight.toDouble(),
                child: CommonCard(
                  isSelected: isSelected,
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // 不用 pumpAndSettle：卡片带涟漪和淡入这类持续动画，会一直等到超时。
    await tester.pump(const Duration(milliseconds: 400));

    final boundary =
        tester.renderObject(find.byKey(boundaryKey)) as RenderRepaintBoundary;
    late ByteData data;
    // toImage / toByteData 由引擎线程完成，必须放进 runAsync，
    // 否则测试的假异步时钟等不到结果。
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      image.dispose();
    });
    debugDisableShadows = true;
    return (int x, int y) {
      final offset = (y * viewSize + x) * 4;
      return [
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      ];
    };
  }

  void setUpView(WidgetTester tester) {
    addTearDown(() => debugDisableShadows = true);
    tester.view.physicalSize = Size(viewSize.toDouble(), viewSize.toDouble());
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('深色：卡片那圈描边和桌面端一样几乎看不见', (tester) async {
    setUpView(tester);
    final pixel = await shoot(tester, brightness: Brightness.dark);

    final body = pixel(centerX, cardTop + 40)[0];
    final topEdge = pixel(centerX, cardTop)[0];
    final leftEdge = pixel(cardLeft, cardTop + 40)[0];

    expect(body, inInclusiveRange(22, 26), reason: '卡片本色应为 content1 #18181b');

    // 桌面端实测边缘 26、卡片本色 24，只抬高 2/255。留 3 的余量给抗锯齿。
    // 按 0.15 画实线边框会抬到 58，这条会当场变红。
    expect(
      topEdge - body,
      lessThanOrEqualTo(3),
      reason:
          '上边缘比卡片本色亮了 ${topEdge - body}/255。桌面端那圈是带 1px 模糊的内阴影，'
          '糊完只抬高 2/255（实测 24→26）；抬到 30 以上说明又把 CSS 里的 0.15 '
          '原样当边框透明度用了（那样会画成 58）。',
    );
    expect(leftEdge - body, lessThanOrEqualTo(3), reason: '左边缘同上');
  });

  testWidgets('深色：卡片外阴影的衰减曲线和 Chrome 画出来的一致', (tester) async {
    setUpView(tester);
    final pixel = await shoot(tester, brightness: Brightness.dark);

    // Chrome 无头实测（中灰底 128）：紧贴下边缘 109、+10 是 119、+20 是 125、
    // +32 已经回到 128。容差 ±4：Flutter 和 Chromium 走同一个 Skia 模糊换算，
    // 实测两边落差不超过 2。
    const expected = <int, int>{0: 109, 10: 119, 20: 125, 32: 128};
    expected.forEach((distance, want) {
      final got = pixel(centerX, cardBottom + distance)[0];
      expect(
        got,
        inInclusiveRange(want - 4, want + 4),
        reason: '下边缘往下 $distance 像素处应为 $want 左右，实际 $got',
      );
    });
  });

  testWidgets('浅色：阴影用的是浅色那组值，不是深色那组', (tester) async {
    setUpView(tester);
    final pixel = await shoot(tester, brightness: Brightness.light);

    // Chrome 无头实测浅色 shadow-medium（中灰底 128）：+0 是 117、+10 是 125、
    // +20 是 127。深色那组在同一位置是 109/119/125——明显更重，所以这三个点
    // 足以分辨「有没有按亮度分开取值」。
    const expected = <int, int>{0: 117, 10: 125, 20: 127};
    expected.forEach((distance, want) {
      final got = pixel(centerX, cardBottom + distance)[0];
      expect(
        got,
        inInclusiveRange(want - 4, want + 4),
        reason:
            '浅色下边缘往下 $distance 像素处应为 $want 左右，实际 $got。'
            '偏暗说明浅色又在用深色那组阴影（0.06/0.22），桌面端浅色是 0.03/0.08。',
      );
    });
  });

  testWidgets('选中的卡片不往外冒光', (tester) async {
    setUpView(tester);
    final selected = await shoot(
      tester,
      brightness: Brightness.dark,
      isSelected: true,
    );

    // 桌面端选中只把底色换成 bg-primary，阴影原封不动。冒蓝光的话卡片外面的像素
    // 会明显偏蓝：按原来那组 accentGlow 算，下方 10 像素处约为 (112,126,142)，
    // 蓝比红高 30。
    final outside = selected(centerX, cardBottom + 10);
    expect(
      outside[2] - outside[0],
      lessThanOrEqualTo(8),
      reason:
          '选中卡片外面的像素偏蓝（R=${outside[0]} B=${outside[2]}），说明还在往外冒光。'
          '桌面端选中的卡片阴影和没选中时是同一个 shadow-medium。',
    );

    // 顺带确认底色确实换成了实心主色 #006FEE。
    final body = selected(centerX, cardTop + 40);
    expect(body[0], lessThan(60), reason: '选中卡片底色应为实心 #006FEE');
    expect(body[2], greaterThan(200), reason: '选中卡片底色应为实心 #006FEE');
  });

  test('阴影每一层的透明度都对得上桌面端 CSS', () {
    // 像素测试量的是整条衰减曲线，对**最外那层大范围淡阴影**不敏感——它峰值只有
    // 几个 255 分之一，改错了也落在容差里（实测把浅色第一层从 .03 调到 .06，
    // 像素测试不变红）。所以这里再按层钉一次透明度。
    //
    // 对照的是 `@heroui/theme/dist/chunk-HUBDRSA4.mjs:27-42` 里 shadow-medium 的
    // 原文：
    //   深色 0 0 15px rgb(0 0 0/.06), 0 2px 30px rgb(0 0 0/.22), inset ...
    //   浅色 0 0 15px rgb(0 0 0/.03), 0 2px 30px rgb(0 0 0/.08), 0 0 1px rgb(0 0 0/.3)
    List<int> alphas(List<BoxShadow> shadows) =>
        shadows.map((s) => (s.color.a * 255).round()).toList();

    expect(
      alphas(AppStyleTokens.clashParty.cardShadow),
      [15, 56],
      reason: '深色两层应为 .06*255≈15 和 .22*255≈56',
    );
    expect(
      alphas(AppStyleTokens.clashParty.cardShadowLight),
      [8, 20, 77],
      reason: '浅色三层应为 .03*255≈8、.08*255≈20、.3*255≈77',
    );
    expect(
      AppStyleTokens.clashParty.cardShadow
          .map((s) => s.blurRadius)
          .toList(),
      [15.0, 30.0],
      reason: '模糊半径照搬 CSS 的 15/30——Flutter 和 Chromium 是同一个 Skia 换算',
    );
  });

  testWidgets('取 token 时会按当前亮度换成对应的那一套', (tester) async {
    late AppStyleTokens darkTokens;
    late AppStyleTokens lightTokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: themeFor(Brightness.light),
        home: Builder(
          builder: (context) {
            lightTokens = context.styleTokens;
            return Theme(
              data: themeFor(Brightness.dark),
              child: Builder(
                builder: (context) {
                  darkTokens = context.styleTokens;
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(
      darkTokens.cardShadow,
      isNot(equals(lightTokens.cardShadow)),
      reason: '深浅两种亮度必须拿到两组不同的阴影，否则等于没按亮度分开',
    );
    expect(darkTokens.cardShadow, AppStyleTokens.clashParty.cardShadow);
    expect(lightTokens.cardShadow, AppStyleTokens.clashParty.cardShadowLight);
    expect(darkTokens.rim, AppStyleTokens.clashParty.rim);
    expect(lightTokens.rim, AppStyleTokens.clashParty.rimLight);
  });
}
