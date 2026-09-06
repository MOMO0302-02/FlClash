import 'dart:io';

import 'package:clash_party/common/app_style.dart';
import 'package:clash_party/common/render_capability.dart';
import 'package:clash_party/models/common.dart';
import 'package:clash_party/widgets/liquid_glass.dart';
import 'package:clash_party/widgets/popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 液态玻璃铺到哪些面上。
///
/// ## 这不是苹果那种真折射
///
/// 苹果对 Liquid Glass 的定义是四件事：模糊背景、反射周围光色、实时响应触摸、
/// **光线弯折折射**。Flutter 的 `BackdropFilter` 只收 `ImageFilter`，做不了逐像素
/// 位移，所以"边缘把背景掰弯"做不出来。这里做的是磨砂 + 高光，不假装有折射。
///
/// ## 三条纪律，每条都有对应的测试
///
/// 1. **只有 iOS 风格用玻璃。** Fluent 和默认风格保持不透明——玻璃是苹果那套语言，
///    套到别的风格上是四不像。
/// 2. **一律走 `LiquidGlass`，不写裸 `BackdropFilter`。** 这是能力分档的唯一入口。
///    `sheet.dart` 曾经是反例：用写死 sigma 5 的 `commonFilter`，既不看设备内存，
///    也不看系统的「移除动画」开关，低配机和前庭功能障碍用户都得不到保护。
/// 3. **阴影画在玻璃外面。** `BackdropFilter` 会裁掉自身范围之外的绘制。
void main() {
  ThemeData themeFor(AppStyle style) {
    final tokens = AppStyleTokens.of(style);
    var scheme = ColorScheme.fromSeed(
      seedColor: tokens.seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: tokens.schemeVariant,
    );
    scheme = tokens.surfacesFor(Brightness.dark)?.applyTo(scheme) ?? scheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }

  Future<void> pumpMenu(WidgetTester tester, AppStyle style) async {
    RenderCapability.setTierForTest(RenderTier.full);
    addTearDown(() => RenderCapability.setTierForTest(RenderTier.full));
    await tester.pumpWidget(
      MaterialApp(
        theme: themeFor(style),
        home: Scaffold(
          body: CommonPopupMenu(
            items: [
              PopupMenuItemData(
                icon: Icons.edit_outlined,
                label: 'edit',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('弹出菜单', () {
    testWidgets('iOS 风格：菜单是玻璃', (tester) async {
      await pumpMenu(tester, AppStyle.cupertino);
      expect(
        find.descendant(
          of: find.byType(CommonPopupMenu),
          matching: find.byType(LiquidGlass),
        ),
        findsOneWidget,
        reason: 'iOS 的上下文菜单本来就是玻璃，这是最能认出「这是 iOS」的一处',
      );
    });

    for (final style in [AppStyle.clashParty, AppStyle.fluent]) {
      testWidgets('${style.name} 风格：菜单不上玻璃', (tester) async {
        await pumpMenu(tester, style);
        expect(
          find.descendant(
            of: find.byType(CommonPopupMenu),
            matching: find.byType(LiquidGlass),
          ),
          findsNothing,
          reason:
              '玻璃是苹果那套设计语言，套到 ${style.name} 上是四不像。'
              '这一档的菜单必须是不透明的。',
        );
      });
    }

    testWidgets('阴影不画在玻璃里面', (tester) async {
      await pumpMenu(tester, AppStyle.cupertino);

      // **iOS 那一档 `cardShadow` 本来就是空的**（苹果的分组卡片不投影，靠底色差
      // 和分隔线分层，见 HIG「Color」那一节）。所以这里不能断言"有阴影"——那会
      // 变成一条永远红着的测试。
      //
      // 真正要守的是**方向**：万一以后给 iOS 补了阴影，它必须画在玻璃外面。
      // `BackdropFilter` 会裁掉自身范围之外的绘制，阴影塞进去就整个没了。
      final inside = find.descendant(
        of: find.byType(LiquidGlass),
        matching: find.byType(DecoratedBox),
      );
      final shadowInsideGlass = tester.widgetList<DecoratedBox>(inside).any((
        box,
      ) {
        final decoration = box.decoration;
        return decoration is BoxDecoration &&
            (decoration.boxShadow?.isNotEmpty ?? false);
      });
      expect(
        shadowInsideGlass,
        isFalse,
        reason:
            '玻璃**里面**画了阴影。BackdropFilter 会裁掉自身范围之外的绘制，'
            '这道阴影根本显不出来。要画就画在 LiquidGlass 外层的 DecoratedBox 上。',
      );
    });
  });

  group('不写裸 BackdropFilter', () {
    /// 扫源码：**能力分档只有 `LiquidGlass` 一个入口**，绕过它写裸
    /// `BackdropFilter` 的地方就拿不到分档保护。
    ///
    /// 这条是回归防线：`sheet.dart` 的底部弹层头部原来正是这样绕过去的。
    test('lib/ 里的悬浮面都走 LiquidGlass，没有裸的 BackdropFilter', () {
      final offenders = <String>[];
      // 允许清单：这两处是**整屏遮罩**（弹层背后压暗那一层），不是悬浮面板的材质，
      // 由 Flutter 的 showModalBottomSheet / showModalSideSheet 直接消费一个
      // ImageFilter，塞不进 LiquidGlass。
      const allowed = {
        'lib\\widgets\\liquid_glass.dart',
        'lib\\widgets\\sheet.dart',
        'lib\\state.dart',
      };
      final dir = Directory('lib');
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) {
          continue;
        }
        final relative = file.path;
        if (allowed.any((a) => relative.endsWith(a.replaceAll('\\', '/')) ||
            relative.endsWith(a))) {
          continue;
        }
        if (file.readAsStringSync().contains('BackdropFilter(')) {
          offenders.add(relative);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            '这些文件直接用了 BackdropFilter，绕过了 RenderCapability 的能力分档：\n'
            '${offenders.join("\n")}\n'
            '低配机会照样逐帧重采样整块背景，系统「移除动画」开关也失效。'
            '改成 LiquidGlass。',
      );
    });

    test('sheet.dart 的弹层头部不再用写死半径的 commonFilter', () {
      // **必须先剥掉注释再匹配。** sheet.dart 的注释里就写着
      // "原来是 `BackdropFilter(filter: commonFilter)`"，直接扫全文会把这段说明
      // 当成违规代码，测试永远红着。
      final source = File('lib/widgets/sheet.dart')
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      // commonFilter 是写死 sigma 5 的模糊，只该用在**整屏遮罩**上
      // （showModalBottomSheet / showModalSideSheet 的 filter 参数）。
      // 弹层头部那一处必须走 LiquidGlass。
      expect(
        source.contains('LiquidGlass('),
        isTrue,
        reason: '底部弹层头部应当走 LiquidGlass，才能受能力分档保护',
      );
      expect(
        RegExp(r'BackdropFilter\(\s*filter:\s*commonFilter').hasMatch(source),
        isFalse,
        reason:
            '又出现了 `BackdropFilter(filter: commonFilter)`——那是写死 sigma 5 的'
            '模糊，既不看设备内存也不看「移除动画」开关。',
      );
    });
  });
}
