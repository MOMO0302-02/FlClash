import 'dart:math';

import 'package:clash_party/common/app_style.dart';
import 'package:clash_party/models/config.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/providers/state.dart';
import 'package:clash_party/widgets/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 语义色与桌面端对齐。
///
/// 钉住的是"删除按钮到底是什么红"这种没人会专门去看、但一偏就整片不对味的东西。
/// Material 会从蓝色种子自己推一个 error 色出来，推出来的是偏橙的红；桌面端
/// （HeroUI）的 danger 是偏玫红的 #F31260。
void main() {
  /// 按指定风格算出配色方案。
  ///
  /// **必须走 provider**：把危险色钉死是在 `_applyStyle` 里做的，那是私有函数，
  /// 只有经过 `genColorScheme` 才走得到。自己 `ColorScheme.fromSeed` 拼一个出来
  /// 测，测的就不是线上真正在用的那条路径了。
  ///
  /// 容器**用完立刻销毁**，不走 `addTearDown`：`testWidgets` 收尾时会断言「没有
  /// 还没跑完的定时器」，而 riverpod 的容器活着就挂着一个，addTearDown 是测试跑完
  /// 之后才执行的，来不及。
  ColorScheme schemeOf(AppStyle style, Brightness brightness) {
    final container = ProviderContainer(
      overrides: [
        themeSettingProvider.overrideWithBuild(
          (_, _) => ThemeProps(appStyle: style),
        ),
      ],
    );
    final scheme = container.read(genColorSchemeProvider(brightness));
    container.dispose();
    return scheme;
  }

  group('危险色', () {
    for (final brightness in Brightness.values) {
      test('${brightness.name}：Clash Party 风格用桌面端的 #F31260', () {
        final scheme = schemeOf(AppStyle.clashParty, brightness);
        expect(scheme.error, AppStyleTokens.danger);
        expect(scheme.onError, AppStyleTokens.onDanger);
      });
    }

    // 曾经有一条「Material You 不钉」的例外——那一档跟随系统壁纸取色，钉死危险色
    // 反而不对。那一档已删，现在**所有风格都钉**，上面那个循环已经覆盖全部。
  });

  group('语义色取值', () {
    test('和桌面端 HeroUI 的默认值逐个对上', () {
      expect(AppStyleTokens.danger, const Color(0xFFF31260));
      expect(AppStyleTokens.success, const Color(0xFF17C964));
      expect(AppStyleTokens.warning, const Color(0xFFF5A524));
    });

    test('success 与 warning 配黑字——亮度太高，白字读不出来', () {
      // 用相对亮度判断而不是硬比颜色值：真正要保证的是"字在底色上读得出来"。
      for (final pair in [
        (AppStyleTokens.success, AppStyleTokens.onSuccess),
        (AppStyleTokens.warning, AppStyleTokens.onWarning),
      ]) {
        expect(
          pair.$1.computeLuminance(),
          greaterThan(0.3),
          reason: '底色应该是亮色',
        );
        expect(pair.$2.computeLuminance(), lessThan(0.1), reason: '字应该是黑的');
      }
    });

    test('danger 配白字', () {
      expect(AppStyleTokens.danger.computeLuminance(), lessThan(0.3));
      expect(AppStyleTokens.onDanger.computeLuminance(), greaterThan(0.9));
    });
  });

  // ── 浅色模式：那些"给深色调好、搬到浅色就不成立"的取值 ──────────────
  //
  // 这一组全部来自用户实际看到的问题。共同的病因只有一个：**取值是照着深色底
  // 挑的，浅色下亮度关系整个反过来。**
  group('浅色模式', () {
    group('开关未选中时的滑块', () {
      test('深色下是纯白——桌面端 HeroUI 两种状态的滑块都是白的', () {
        final scheme = schemeOf(AppStyle.clashParty, Brightness.dark);
        expect(
          unselectedSwitchThumbColor(scheme, Brightness.dark),
          const Color(0xFFFFFFFF),
        );
      });

      test('浅色下必须和轨道有对比——白滑块压在浅灰轨道上等于看不见', () {
        final scheme = schemeOf(AppStyle.clashParty, Brightness.light);
        final thumb = unselectedSwitchThumbColor(scheme, Brightness.light);
        // 关闭态的轨道是 surfaceContainerHighest（浅色下 #E4E4E7）。
        final track = scheme.surfaceContainerHighest;
        // 用 WCAG 的对比度（亮的那个 +0.05 除以暗的那个 +0.05），不用亮度差：
        // 白 vs #E4E4E7 的亮度差有 0.23，看着"还行"，换成对比度只有 1.3:1
        // ——远低于界面控件要求的 3:1，也就是实际上根本分不出来。
        double ratio(Color a, Color b) {
          final la = a.computeLuminance();
          final lb = b.computeLuminance();
          return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
        }

        expect(
          ratio(thumb, track),
          greaterThan(3.0),
          reason:
              '浅色下未选中滑块和轨道的对比度只有 '
              '${ratio(thumb, track).toStringAsFixed(2)}:1（界面控件至少要 3:1）。'
              '纯白滑块 + #E4E4E7 轨道正是用户说的「开关未选中时也是灰的」——'
              '他看到的其实是那圈轨道，滑块根本没显出来。',
        );
      });
    });

    group('滑块禁用时的颜色', () {
      /// 拿到某种亮度下 [SliderDefaultsM3] 实际会用的那几个禁用色。
      Future<(Color, Color)> disabledColors(
        WidgetTester tester,
        Brightness brightness,
      ) async {
        late SliderThemeData data;
        // 用裸 Theme 而不是 MaterialApp：MaterialApp 里的 AnimatedTheme 会留一个
        // 没跑完的定时器，测试收尾时会以 `!timersPending` 断言失败。
        await tester.pumpWidget(
          Theme(
            data: ThemeData(
              useMaterial3: true,
              colorScheme: schemeOf(AppStyle.clashParty, brightness),
              extensions: const <ThemeExtension<dynamic>>[
                AppStyleTokens.clashParty,
              ],
            ),
            child: Builder(
              builder: (context) {
                data = SliderDefaultsM3(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        return (data.disabledActiveTrackColor!, data.disabledThumbColor!);
      }

      for (final brightness in Brightness.values) {
        testWidgets('${brightness.name}：禁用的滑块不能比页面上任何东西都重', (tester) async {
          final (track, thumb) = await disabledColors(tester, brightness);
          final scheme = schemeOf(AppStyle.clashParty, brightness);
          // 把半透明的禁用色压到页面底色上，量它实际画出来有多深。
          Color over(Color c) => Color.alphaBlend(c, scheme.surface);
          for (final color in [track, thumb]) {
            final contrast =
                (over(color).computeLuminance() -
                        scheme.surface.computeLuminance())
                    .abs();
            expect(
              contrast,
              lessThan(0.45),
              reason:
                  '禁用的滑块压在页面底色上，亮度差到了 '
                  '${contrast.toStringAsFixed(3)}。Material 默认的 '
                  'onSurface@38% 在深色下是很淡的一道灰，浅色下却变成压在白底上的'
                  '**深灰实条**——那正是用户说的"文本缩放的滑块在浅色下是深灰色的，'
                  '和整页格格不入"。禁用应当是"把控件自己的颜色调淡"，'
                  '不是"换成一块中性深灰"。',
            );
          }
        });
      }
    });
  });
}
