import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clash_party/common/app_style.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/card.dart';
import 'package:clash_party/widgets/chip_row.dart';
import 'package:clash_party/widgets/list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 钉住「切换界面风格是真的换了一套界面语言」。
///
/// 这组测试有来历，而且被打回过两次：
///
/// 1. 第一版四种风格只差圆角和一两个颜色，用户的原话是「我定制那些主题切换实际
///    没有效果」。于是有了第一条——**不看配置写没写进去，直接把界面画出来数像素**。
/// 2. 第二版把颜色钉住了，用户又说「其他 3 个只是改了最简单的颜色，没有改 UI」。
///    所以颜色那一条远远不够，后面几条钉的是**几何**：选中态到底画了什么、
///    设置分组摆成什么形状、卡片圆角有没有真的接到绘制上。
///
/// 加新风格或改现有风格时这里要跟着更新——如果新风格的「选中特征向量」或
/// 「分组几何签名」和已有的某一档撞了，说明它没有自己的界面语言。
void main() {
  const boundaryKey = ValueKey('boundary');

  /// 探针底色。取一个界面里绝不会出现的洋红，好把「这块画了东西没有」分清楚。
  const probe = Color(0xFFFF00FF);
  const probeRgb = 0xFF00FF;

  ThemeData themeFor(AppStyle style, Brightness brightness) {
    final tokens = AppStyleTokens.of(style);
    var scheme = ColorScheme.fromSeed(
      seedColor: tokens.seed,
      brightness: brightness,
      dynamicSchemeVariant: tokens.schemeVariant,
    );
    scheme = tokens.surfacesFor(brightness)?.applyTo(scheme) ?? scheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }

  /// 把 [body] 画出来，返回一个按坐标取像素的函数（0xRRGGBB）。
  ///
  /// 阴影在 flutter_test 里默认被关掉（`debugDisableShadows`），画出来是没模糊的
  /// 硬边方块。这里打开它，并在取完像素后**立刻**关回去——框架在测试体跑完、
  /// tearDown 之前就会校验绘制类调试开关有没有被改动，放 addTearDown 里太晚。
  Future<int Function(int x, int y)> shoot(
    WidgetTester tester, {
    required AppStyle style,
    required Widget body,
    required Size size,
    Brightness brightness = Brightness.dark,
  }) async {
    debugDisableShadows = false;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themeFor(style, brightness),
        home: Builder(
          builder: (context) {
            // globalState.theme 是 late 字段，分组用到的内边距常量要读它。
            globalState.theme = CommonTheme.of(context, 1);
            return RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(color: probe, child: body),
            );
          },
        ),
      ),
    );
    // 不用 pumpAndSettle：卡片有涟漪和淡入这类持续动画，会一直等到超时。
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

    final width = size.width.round();
    return (int x, int y) {
      final offset = (y * width + x) * 4;
      return (data.getUint8(offset) << 16) |
          (data.getUint8(offset + 1) << 8) |
          data.getUint8(offset + 2);
    };
  }

  void setUpView(WidgetTester tester) {
    addTearDown(() => debugDisableShadows = true);
    addTearDown(tester.view.reset);
  }

  bool near(int a, int b, [int tolerance = 6]) {
    for (final shift in [16, 8, 0]) {
      final da = (a >> shift) & 0xFF;
      final db = (b >> shift) & 0xFF;
      if ((da - db).abs() > tolerance) return false;
    }
    return true;
  }

  int rgbOf(Color color) => color.toARGB32() & 0xFFFFFF;

  double luminanceOf(int rgb) =>
      (0.2126 * ((rgb >> 16) & 0xFF) +
          0.7152 * ((rgb >> 8) & 0xFF) +
          0.0722 * (rgb & 0xFF)) /
      255;

  // ── 1. 配色：四种风格画出来两两都不一样 ────────────────────────────
  testWidgets('四种风格的配色画出来两两都不一样', (tester) async {
    setUpView(tester);

    final samples = <AppStyle, List<int>>{};
    for (final style in AppStyle.values) {
      final pixel = await shoot(
        tester,
        style: style,
        size: const Size(200, 220),
        body: const Column(
          children: [
            SizedBox(height: 60, width: 200),
            SizedBox(
              height: 60,
              width: 200,
              child: _Card(),
            ),
            SizedBox(
              height: 60,
              width: 200,
              child: _Card(isSelected: true),
            ),
          ],
        ),
      );
      // 三个采样点：页面区域 / 普通卡片中心 / 选中卡片中心。
      samples[style] = [pixel(100, 30), pixel(100, 90), pixel(100, 150)];
    }

    // 每种风格的「三点颜色」组合必须唯一——两种风格画出来一模一样，
    // 就是当初「切了等于没切」的那个问题。
    final signatures = samples.values.map((s) => s.join(',')).toList();
    expect(
      signatures.toSet().length,
      AppStyle.values.length,
      reason:
          '有风格画出来完全一样：\n'
          '${samples.entries.map((e) => '${e.key.label}: ${e.value.map((v) => v.toRadixString(16)).join(" ")}').join("\n")}',
    );

    // 卡片底色单独再钉一次：这是最一眼能看出来的差别。
    final cards = samples.values.map((s) => s[1]).toSet();
    expect(
      cards.length,
      greaterThanOrEqualTo(3),
      reason: '四种风格的卡片底色几乎都一样，切了看不出区别',
    );
  });

  // ── 2. 选中态：四种风格画的是四种不同的东西 ─────────────────────────
  //
  // 这一条直接针对用户那句「只是改了最简单的颜色，没有改 UI」。选中态是全 App
  // 出现频率最高的状态（代理节点、代理组、主题选择、模式选择全靠它），四种风格
  // 在这里必须画出四种不同的东西，而不是同一个形状换个色。
  group('选中态的画法', () {
    /// 一张卡片被选中时，画面上多出来的**特征**。
    ///
    /// 每一项都对应某种设计语言里的具体做法，不是抽象分类：
    /// - 第 1 位：整块变成强调色（Clash Party / HeroUI）
    /// - 第 2 位：左边缘一条强调色指示条（Windows 11）
    /// - 第 3 位：右上角一个强调色的勾（iOS）
    /// - 第 4 位：底色一点没变（只有 iOS 是这样）
    Future<(bool, bool, bool, bool)> featuresOf(
      WidgetTester tester,
      AppStyle style,
    ) async {
      const size = Size(240, 160);
      // 卡片 160×80 居中 → 左上角 (40,40)、右下角 (200,120)。
      const cardLeft = 40;
      const cardTop = 40;
      const cardRight = 200;

      Future<int Function(int, int)> render({required bool selected}) => shoot(
        tester,
        style: style,
        size: size,
        body: Center(
          child: SizedBox(
            width: 160,
            height: 80,
            child: _Card(isSelected: selected),
          ),
        ),
      );

      final plain = await render(selected: false);
      final plainCenter = plain(120, 80);
      final selected = await render(selected: true);
      final selectedCenter = selected(120, 80);

      final tokens = AppStyleTokens.of(style);
      final scheme = themeFor(style, Brightness.dark).colorScheme;
      final accent = rgbOf(tokens.accent(scheme));

      // 左边缘往里 1 像素、纵向正中：指示条宽 3，落在 x=40..42。
      final leftEdge = selected(cardLeft + 1, cardTop + 40);

      final fillsWithAccent = near(selectedCenter, accent);

      // 右上角那一小块，避开卡片自己的描边（描边最宽 1.5）。
      var cornerAccent = false;
      for (var y = cardTop + 7; y < cardTop + 23; y++) {
        for (var x = cardRight - 22; x < cardRight - 7; x++) {
          if (near(selected(x, y), accent)) cornerAccent = true;
        }
      }

      return (
        fillsWithAccent,
        // 「指示条」和「对勾」都要求整块**没有**被填成强调色，否则整张卡片变蓝的
        // Clash Party 会在每个角落都测出强调色，四个特征全变成真。
        near(leftEdge, accent) && !fillsWithAccent,
        cornerAccent && !fillsWithAccent,
        selectedCenter == plainCenter,
      );
    }

    testWidgets('四种风格的选中特征两两不同，且各自是它该有的那一套', (tester) async {
      setUpView(tester);

      final features = <AppStyle, (bool, bool, bool, bool)>{};
      for (final style in AppStyle.values) {
        features[style] = await featuresOf(tester, style);
      }

      String show() =>
          features.entries.map((e) => '${e.key.label}: ${e.value}').join('\n');

      // (整块填强调色, 左侧指示条, 右上角对勾, 底色没变)
      expect(
        features[AppStyle.clashParty],
        (true, false, false, false),
        reason: 'Clash Party 选中应当整块填成实心强调色\n${show()}',
      );
      expect(
        features[AppStyle.fluent],
        (false, true, false, false),
        reason: 'Fluent 选中应当是左侧指示条 + 底色微微提亮，不是整块变色\n${show()}',
      );
      expect(
        features[AppStyle.cupertino],
        (false, false, true, true),
        reason: 'iOS 选中应当底色一动不动，只在右上角打一个勾\n${show()}',
      );

      expect(
        features.values.toSet().length,
        AppStyle.values.length,
        reason: '有两种风格的选中态画得一模一样\n${show()}',
      );
    });

    testWidgets('浅色模式下选中卡片的字读得出来——白底白字是真出过的事故', (tester) async {
      setUpView(tester);

      // 为什么不摆一段文字进去数像素：`flutter test` 里没有任何字体，
      // `Text` 一个像素都不画（实测 contrasting=0，四种风格全一样），
      // 那样测的是"有没有字体"不是"字有没有颜色对"。
      //
      // 改成把卡片**真正下发给内容的前景色**取出来（按钮把 foregroundColor 通过
      // DefaultTextStyle 发给 child），再和画面上量到的卡片底色比亮度。
      for (final style in AppStyle.values) {
        Color? foreground;
        final pixel = await shoot(
          tester,
          style: style,
          brightness: Brightness.light,
          size: const Size(240, 160),
          body: Center(
            child: SizedBox(
              width: 160,
              height: 80,
              child: _Card(
                isSelected: true,
                child: Builder(
                  builder: (context) {
                    foreground = DefaultTextStyle.of(context).style.color;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
        // 卡片左上角一定是纯底色。
        final background = luminanceOf(pixel(50, 50));
        expect(foreground, isNotNull, reason: '${style.label}：没拿到前景色');
        final contrast = (luminanceOf(rgbOf(foreground!)) - background).abs();
        expect(
          contrast,
          greaterThan(0.25),
          reason:
              '${style.label}：浅色下选中卡片的字色和底色亮度差只有 '
              '${contrast.toStringAsFixed(3)}，基本读不出来。'
              '这正是 onAccent 被一视同仁用在四种选中方式上时的症状——iOS 那档'
              '底色根本没变（还是白的），字却按「填充式选中」给了白色。',
        );
      }
    });
  });

  // ── 3. 设置分组的几何 ───────────────────────────────────────────────
  group('设置分组的几何', () {
    /// 一组设置项画出来的几何签名。
    ///
    /// - 第 1 位 `left`：分组容器左边缘离屏幕多远（通栏平铺那档是 0）
    /// - 第 2 位 `dividerLeft`：分隔线从哪里开始（-1 表示这档不画分隔线）
    /// - 第 3 位 `gap`：条目之间一共空出多少行（只有「一行一张小卡片」不为 0）
    Future<(int, int, int)> geometryOf(
      WidgetTester tester,
      AppStyle style,
    ) async {
      const width = 320.0;
      final pixel = await shoot(
        tester,
        style: style,
        size: const Size(width, 260),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: generateSection(
            items: List.generate(
              3,
              (_) => const SizedBox(height: 40, width: double.infinity),
            ),
          ),
        ),
      );

      // 判定「这个像素是不是分组的底」时**必须认颜色，不能只认「不是探针色」**：
      // Clash Party 和 Fluent 的卡片带外阴影，阴影会把卡片外面的探针色染暗一片
      // （实测能一直糊到 x=0），按「非探针色」找左边缘会量到阴影上去，
      // Clash Party 会得出 左=0（真值 16），Fluent 的行间缝也会被阴影填满。
      final scheme = themeFor(style, Brightness.dark).colorScheme;
      final bodyColors = [
        rgbOf(scheme.surfaceContainerLow),
        rgbOf(scheme.surface),
      ];
      bool isBody(int x, int y) =>
          bodyColors.any((c) => near(pixel(x, y), c, 2));

      int firstBody(int y) {
        for (var x = 0; x < width; x++) {
          if (isBody(x, y)) return x;
        }
        return -1;
      }

      // 分组的纵向范围：从最上面画了底的一行到最下面画了底的一行。
      var top = -1;
      var bottom = -1;
      for (var y = 0; y < 220; y++) {
        if (firstBody(y) >= 0) {
          if (top < 0) top = y;
          bottom = y;
        }
      }
      expect(top, greaterThanOrEqualTo(0), reason: '${style.label}：分组根本没画出来');

      // 左边缘取「出现次数最多的那个值」，避开圆角和分隔线造成的个别行偏差。
      final leftCounts = <int, int>{};
      for (var y = top; y <= bottom; y++) {
        final first = firstBody(y);
        if (first >= 0) leftCounts[first] = (leftCounts[first] ?? 0) + 1;
      }
      final left =
          (leftCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;

      // 条目之间的空隙：分组内部一整行都没有底色的行数。
      var gap = 0;
      for (var y = top; y <= bottom; y++) {
        if (firstBody(y) < 0) gap++;
      }

      // 分隔线：分组内部某一行里「不是底色」的像素连成很长一条，
      // 但这一行本身还得有底色——否则「一行一张小卡片」的行间缝会被当成分隔线。
      var dividerLeft = -1;
      var dividerBest = 0;
      for (var y = top; y <= bottom; y++) {
        if (firstBody(y) < 0) continue;
        var count = 0;
        var first = -1;
        for (var x = left; x < width - left; x++) {
          if (!isBody(x, y)) {
            count++;
            if (first < 0) first = x;
          }
        }
        if (count > 150 && count > dividerBest) {
          dividerBest = count;
          dividerLeft = first;
        }
      }
      return (left, dividerLeft, gap);
    }

    testWidgets('四种风格把同一组设置项摆成四种形状', (tester) async {
      setUpView(tester);

      final geometry = <AppStyle, (int, int, int)>{};
      for (final style in AppStyle.values) {
        geometry[style] = await geometryOf(tester, style);
      }
      String show() => geometry.entries
          .map(
            (e) =>
                '${e.key.label}: (左=${e.value.$1} '
                '分隔线起点=${e.value.$2} 条目间隙=${e.value.$3})',
          )
          .join('\n');

      // 探针宽 320，分组左右各留 16 → 卡片 x 从 16 开始。
      expect(
        geometry[AppStyle.clashParty],
        (16, 32, 0),
        reason: 'Clash Party：一张 16 内缩的卡片，分隔线再往里缩 16（= 32）\n${show()}',
      );
      expect(
        geometry[AppStyle.fluent],
        (16, -1, 8),
        reason: 'Fluent：一行一张小卡片，行间留 4（两条缝共 8 行），不画分隔线\n${show()}',
      );
      expect(
        geometry[AppStyle.cupertino],
        (16, 72, 0),
        reason: 'iOS：圆角分组，分隔线从文字起始处开始（16 + 56 = 72）\n${show()}',
      );

      expect(
        geometry.values.toSet().length,
        AppStyle.values.length,
        reason: '有两种风格把设置项摆成了一模一样的形状\n${show()}',
      );
    });

    testWidgets('分组小标题只有 iOS 那档转成全大写', (tester) async {
      for (final style in AppStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: themeFor(style, Brightness.dark),
            home: Builder(
              builder: (context) {
                globalState.theme = CommonTheme.of(context, 1);
                return Scaffold(
                  // 必须带 key：不带的话四次 pumpWidget 传进去的是**同一个 const
                  // 实例**，Flutter 认出「widget 没变」直接跳过重建，四种风格量到的
                  // 都是第一次那份，测试永远是绿的。
                  body: ListHeader(key: ValueKey(style), title: 'Options'),
                );
              },
            ),
          ),
        );
        // 必须等够时间：MaterialApp 里的 AnimatedTheme 会在两套主题之间做插值
        // （kThemeAnimationDuration = 200ms），只 pump 一帧的话 t≈0，
        // AppStyleTokens.lerp 在 t<0.5 时返回**上一套**风格——四次循环量到的
        // 全是第一次那份，测试会一直是绿的。
        await tester.pump(const Duration(milliseconds: 400));
        final expected = style == AppStyle.cupertino ? 'OPTIONS' : 'Options';
        expect(
          find.text(expected),
          findsOneWidget,
          reason: '${style.label} 的分组标题应该显示成 $expected',
        );
      }
    });
  });

  // ── 4. 圆角确实接到了绘制上 ─────────────────────────────────────────
  //
  // 「四个 cardRadius 的数值不一样」只能证明配置写了，证明不了画出来不一样。
  // 这里分两步：① 同一种风格下把圆角调到 2 和 28，画出来必须明显不同（说明这个
  // 值真的通到了绘制）；② 四种风格的取值两两不同（说明它们的圆角不会撞车）。
  group('卡片圆角', () {
    testWidgets('圆角这个取值真的通到了绘制，不是写在配置里没人用', (tester) async {
      setUpView(tester);

      Future<int> cornerFilled(double radius) async {
        final pixel = await shoot(
          tester,
          style: AppStyle.clashParty,
          size: const Size(240, 160),
          body: Center(
            child: SizedBox(
              width: 160,
              height: 80,
              child: _Card(radius: radius),
            ),
          ),
        );
        final fill = pixel(120, 80);
        // 左上角 30×30 里还剩多少卡片本色：圆角越大，被切掉的越多。
        var filled = 0;
        for (var y = 40; y < 70; y++) {
          for (var x = 40; x < 70; x++) {
            if (near(pixel(x, y), fill, 4)) filled++;
          }
        }
        return filled;
      }

      final small = await cornerFilled(2);
      final large = await cornerFilled(28);
      expect(
        large,
        lessThan(small - 100),
        reason:
            '把圆角从 2 调到 28，卡片左上角剩下的本色面积只从 $small 变到 $large'
            '——说明 cardRadius 没有真的接到卡片的形状上，改它等于没改。',
      );
    });

    test('四种风格的圆角取值两两不同', () {
      final radii = AppStyle.values
          .map((s) => AppStyleTokens.of(s).cardRadius)
          .toList();
      expect(
        radii.toSet().length,
        AppStyle.values.length,
        reason: '有风格的卡片圆角撞车了：$radii',
      );
    });
  });

  // ── 5. 横排选择器不能把卡片阴影切断 ─────────────────────────────────
  //
  // 用户报的第一个浅色 bug：「主题切换页按钮下是灰色条」。根因不是颜色，是
  // **滚动视口和卡片一样高**——卡片的外阴影被视口在上下齐刷刷切断，在白底上就是
  // 一条上下沿笔直的灰带子。深色底上黑阴影本来就看不见，所以一直没人发现。
  testWidgets('横排选择器要给卡片阴影留出地方，不能齐刷刷切断', (tester) async {
    setUpView(tester);

    final pixel = await shoot(
      tester,
      style: AppStyle.clashParty,
      brightness: Brightness.light,
      size: const Size(200, 120),
      body: Column(
        children: [
          ChipRow(
            itemCount: 1,
            itemBuilder: (_, _) => const SizedBox(width: 120, child: _Card()),
          ),
        ],
      ),
    );

    // 卡片上边缘从画面上量出来，不写常量——写常量的话改了 ChipRow 的余量
    // 这条测试会跟着一起「自适应」，永远绿。
    // 卡片占 x=16..136（左内边距 16 + 宽 120），x=80 正好穿过它。
    final cardColor = pixel(80, 40);
    var cardTop = -1;
    for (var y = 0; y < 80; y++) {
      if (near(pixel(80, y), cardColor, 2)) {
        cardTop = y;
        break;
      }
    }
    expect(cardTop, greaterThanOrEqualTo(0), reason: '卡片没画出来');

    // 卡片正上方那一段里，必须能找到「既不是卡片本色、也不是纯探针色」的像素
    // ——那就是糊出来的阴影。视口贴着卡片切的话 cardTop=0，这一段根本不存在。
    var shadowPixels = 0;
    for (var y = 0; y < cardTop; y++) {
      for (var x = 20; x < 132; x++) {
        final p = pixel(x, y);
        if (!near(p, cardColor, 2) && !near(p, probeRgb, 2)) shadowPixels++;
      }
    }
    expect(
      shadowPixels,
      greaterThan(300),
      reason:
          '卡片上边缘在 y=$cardTop，它上面只找到 $shadowPixels 个阴影像素。'
          '横排选择器的滚动视口又变成和卡片一样高了——阴影被硬裁在视口边界上，'
          '白底下会看成一条上下沿笔直的灰带子横在按钮底下。',
    );
  });

  // ── 6. 浅色模式下四种风格都有自己的底色层 ───────────────────────────
  //
  // 曾经只有 Clash Party 配了浅色底色层，另外三种在浅色下会退回 Material 从各自
  // 种子推出来的带色味的灰——切到 Fluent 或 iOS，浅色模式下一点也不像。
  // **「Material You 除外」那条例外没了。** 那一档已删（它是唯一跟随系统壁纸
  // 取色、因此不配底色层的风格），剩下的三档没有例外——断言反而更强了。
  test('每一种风格深浅两套底色都得配齐', () {
    for (final style in AppStyle.values) {
      final tokens = AppStyleTokens.of(style);
      expect(tokens.darkSurfaces, isNotNull, reason: '${style.name} 没配深色底色层');
      expect(
        tokens.lightSurfaces,
        isNotNull,
        reason:
            '${style.label} 没配浅色底色层，浅色模式下会退回 Material 从种子推出来的'
            '带色味的灰，完全不是这套风格该有的样子',
      );
    }
  });
}

/// 测试里统一用的卡片。
///
/// **必须带 `onPressed`。** 不带的话按钮处在 disabled 状态，Material 会用
/// `disabledForegroundColor`（onSurface 的 38%）盖掉 `CommonCard` 自己算出来的
/// 前景色——曾经因此写出一条「怎么改都是绿」的假测试：故意把选中前景色改回
/// 一律 onAccent，测出来的却始终是那个禁用色，测试纹丝不动。
/// 而界面上这些卡片全都是可点的，disabled 根本不是它们的真实状态。
class _Card extends StatelessWidget {
  const _Card({this.isSelected = false, this.radius, this.child});

  final bool isSelected;
  final double? radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      isSelected: isSelected,
      radius: radius,
      onPressed: () {},
      child: child ?? const SizedBox.shrink(),
    );
  }
}
