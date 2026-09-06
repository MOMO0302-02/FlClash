import 'package:clash_party/common/common.dart';
import 'package:flutter/material.dart';

/// 输入框的统一取值。
///
/// Material 默认的输入框在深色下是「带色味的底 + 淡紫色的聚焦线」，一眼就能认出
/// 是 Material。桌面端的做法是深灰底 + 一圈很淡的白色描边，聚焦时描边换成实蓝。
/// 集中放在这里，由 [CommonControlTheme] 往整棵子树发，调用点不必各写一遍。
InputDecorationTheme commonInputDecorationTheme(BuildContext context) {
  final tokens = context.styleTokens;
  final colorScheme = context.colorScheme;
  final accent = tokens.accent(colorScheme);
  final borderRadius = BorderRadius.circular(tokens.controlRadius);
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: borderRadius,
    borderSide: BorderSide(color: color, width: width),
  );
  // rim 为全透明的风格（Material You / iOS）等于不画描边，正是它们该有的样子。
  return InputDecorationTheme(
    filled: true,
    fillColor: colorScheme.surfaceContainerHigh,
    border: border(tokens.rim, 1),
    enabledBorder: border(tokens.rim, 1),
    disabledBorder: border(tokens.rim, 1),
    focusedBorder: border(accent, 1.5),
    errorBorder: border(colorScheme.error, 1),
    focusedErrorBorder: border(colorScheme.error, 1.5),
    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
    floatingLabelStyle: TextStyle(color: accent),
    counterStyle: TextStyle(color: colorScheme.onSurfaceVariant),
  );
}

/// 开关未选中时那个滑块的颜色。见 [CommonControlTheme] 里的说明。
///
/// 单独提出来是为了让测试能直接钉住这条规则，不必去渲染一个开关再数像素。
Color unselectedSwitchThumbColor(ColorScheme scheme, Brightness brightness) =>
    _unselectedThumb(scheme, brightness);

Color _unselectedThumb(ColorScheme scheme, Brightness brightness) =>
    brightness == Brightness.dark ? const Color(0xFFFFFFFF) : scheme.outline;

/// 把输入框、按钮这类还留着 Material 默认长相的控件统一成桌面端的取值。
///
/// 强调色走 [AppStyleTokens.accent] 而不是 `colorScheme.primary`——深色下
/// Material 会把实蓝种子推成淡紫，跟桌面端对不上。
class CommonControlTheme extends StatelessWidget {
  final Widget child;

  const CommonControlTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.styleTokens;
    final colorScheme = theme.colorScheme;
    final accent = tokens.accent(colorScheme);
    final controlShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(tokens.controlRadius),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: commonInputDecorationTheme(context),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: tokens.onAccent(colorScheme),
            shape: controlShape,
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            shape: controlShape,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: tokens.rim),
            shape: controlShape,
          ),
        ),
        // Material 默认用 primary 画开关/勾选的选中态，同样会偏紫。
        switchTheme: theme.switchTheme.copyWith(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? tokens.onAccent(colorScheme)
                // 未选中时的滑块颜色**必须按亮度分开**。
                //
                // 深色下轨道是 #3F3F46 这类深灰，纯白滑块清清楚楚（桌面端 HeroUI
                // 就是白的）。浅色下轨道是 #E4E4E7，再放一个纯白滑块＝**白底上的
                // 白点**，用户的原话是"开关未选中时也是灰的"——看到的其实是那圈
                // 轨道，滑块根本没显出来。
                //
                // 浅色改用 outline：这既是 Material 自己在浅色下的取值，也是唯一
                // 能在浅灰轨道上读出来的。
                : _unselectedThumb(colorScheme, theme.brightness),
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? accent : null,
          ),
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accent;
            }
            // 关闭态描不描边由风格决定：Fluent 的 ToggleSwitch 和 M3 都描，
            // HeroUI 与 iOS 是实心轨道不描边。null 表示交回 Material 的默认
            // （它会画 outline 那一圈）。
            return tokens.switchOutline ? null : Colors.transparent;
          }),
        ),
        checkboxTheme: theme.checkboxTheme.copyWith(
          fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? accent : null,
          ),
          checkColor: WidgetStatePropertyAll(tokens.onAccent(colorScheme)),
        ),
        radioTheme: theme.radioTheme.copyWith(
          fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? accent : null,
          ),
        ),
        progressIndicatorTheme: theme.progressIndicatorTheme.copyWith(
          color: accent,
        ),
        // 分隔线深浅本来只有 list.dart 用上了 token，别处还是 Material 的
        // outlineVariant（在纯黑底上偏亮）。挂到主题上让所有 Divider 跟着走。
        // 只改颜色不改 space/thickness——那两个会动布局，不属于「长什么样」。
        dividerTheme: theme.dividerTheme.copyWith(
          color:
              tokens.dividerColor ??
              colorScheme.onSurface.withValues(alpha: tokens.dividerOpacity),
        ),
        // Material 默认的气泡是 inverseSurface（深色下是一块浅灰），在纯黑界面上
        // 白得刺眼。换成和卡片同一套：深灰底 + rim 描边 + 控件圆角。
        tooltipTheme: theme.tooltipTheme.copyWith(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(tokens.controlRadius),
            border: Border.all(color: tokens.rim),
            boxShadow: tokens.cardShadow,
          ),
          textStyle: TextStyle(
            color: colorScheme.onSurface,
            fontSize: theme.textTheme.bodySmall?.fontSize,
          ),
        ),
      ),
      child: child,
    );
  }
}

class CommonMinFilledButtonTheme extends StatelessWidget {
  final Widget child;

  const CommonMinFilledButtonTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = context.styleTokens;
    final colorScheme = context.colorScheme;
    return FilledButtonTheme(
      data: FilledButtonThemeData(
        // 这里是整个替换而不是 copyWith，所以强调色要自己带上，
        // 否则被它包住的按钮会退回 Material 的淡紫 primary。
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent(colorScheme),
          foregroundColor: tokens.onAccent(colorScheme),
          elevation: 0,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      child: child,
    );
  }
}

class CommonMinIconButtonTheme extends StatelessWidget {
  final Widget child;

  const CommonMinIconButtonTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          iconSize: 20.ap,
        ),
      ),
      child: child,
    );
  }
}

class SliderDefaultsM3 extends SliderThemeData {
  SliderDefaultsM3(this.context) : super(trackHeight: 16.0);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  /// 滑块的填充部分是强调色。走 tokens 而不是 `colorScheme.primary`：
  /// 深色下 Material 会把实蓝推成淡紫，和桌面端对不上。
  late final Color _accent = context.styleTokens.accent(_colors);

  @override
  Color? get activeTrackColor => _accent;

  @override
  Color? get inactiveTrackColor => _colors.surfaceContainerHighest;

  @override
  Color? get secondaryActiveTrackColor => _accent.withValues(alpha: 0.54);

  /// 禁用时**不能**用 Material 默认的 `onSurface@38%`。
  ///
  /// 深色下 onSurface 是近白，38% 压在黑底上是一道很淡的灰，看着就是"这条现在
  /// 不能动"。浅色下 onSurface 是近黑，同样的 38% 变成压在白底上的**深灰实条**
  /// ——16 像素高、横贯半个屏幕，比整页任何东西都重，用户的原话是"滑块在浅色下
  /// 是深灰色的，和整页格格不入"。
  ///
  /// 改成「把控件自己的颜色调淡」：这既是桌面端 HeroUI 的禁用做法
  /// （`opacity-disabled`，不换色只降透明度），在深浅两种亮度下也都成立——
  /// 淡蓝在黑底和白底上都读得出"这是那条滑块，现在按不动"。
  @override
  Color? get disabledActiveTrackColor => _accent.withValues(alpha: 0.38);

  @override
  Color? get disabledInactiveTrackColor => _colors.surfaceContainerHighest;

  @override
  Color? get disabledSecondaryActiveTrackColor =>
      _accent.withValues(alpha: 0.20);

  @override
  Color? get activeTickMarkColor => context.styleTokens.onAccent(_colors);

  @override
  Color? get inactiveTickMarkColor => _colors.onSurfaceVariant;

  // 刻度点同理：Material 默认的 `onSurface` 在浅色下是**近黑的实心点**。
  // 一律走 onSurfaceVariant 加透明度，深浅两种亮度下都只是"淡一点的点"。
  @override
  Color? get disabledActiveTickMarkColor =>
      _colors.onSurfaceVariant.withValues(alpha: 0.38);

  @override
  Color? get disabledInactiveTickMarkColor =>
      _colors.onSurfaceVariant.withValues(alpha: 0.38);

  @override
  Color? get thumbColor => _accent;

  /// 同 [disabledActiveTrackColor]：淡掉的强调色，不是 38% 的 onSurface。
  @override
  Color? get disabledThumbColor => _accent.withValues(alpha: 0.38);

  @override
  Color? get overlayColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.dragged)) {
          return _accent.opacity10;
        }
        if (states.contains(WidgetState.hovered)) {
          return _accent.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _accent.opacity10;
        }

        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle => Theme.of(
    context,
  ).textTheme.labelLarge!.copyWith(color: _colors.onInverseSurface);

  @override
  Color? get valueIndicatorColor => _colors.inverseSurface;

  @override
  SliderComponentShape? get valueIndicatorShape =>
      const RoundedRectSliderValueIndicatorShape();

  @override
  SliderComponentShape? get thumbShape => const HandleThumbShape();

  @override
  SliderTrackShape? get trackShape => const GappedSliderTrackShape();

  @override
  SliderComponentShape? get overlayShape => const RoundSliderOverlayShape();

  @override
  SliderTickMarkShape? get tickMarkShape =>
      const RoundSliderTickMarkShape(tickMarkRadius: 4.0 / 2);

  @override
  WidgetStateProperty<Size?>? get thumbSize {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.hovered)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.focused)) {
        return const Size(2.0, 44.0);
      }
      if (states.contains(WidgetState.pressed)) {
        return const Size(2.0, 44.0);
      }
      return const Size(4.0, 44.0);
    });
  }

  @override
  double? get trackGap => 6.0;
}
