// ignore_for_file: deprecated_member_use

import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/widgets/chip_row.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeModeItem {
  final ThemeMode themeMode;
  final IconData iconData;
  final String label;

  const ThemeModeItem({
    required this.themeMode,
    required this.iconData,
    required this.label,
  });
}

class FontFamilyItem {
  final FontFamily fontFamily;
  final String label;

  const FontFamilyItem({required this.fontFamily, required this.label});
}

class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return BaseScaffold(
      title: appLocalizations.theme,
      body: const CustomScrollView(
        slivers: [
          _ThemeModeItem(),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          _AppStyleItem(),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          _TextScaleFactorItem(),
          SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Widget child;
  final Info info;
  final List<Widget> actions;

  const ItemCard({
    super.key,
    required this.info,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 16,
      children: [
        InfoHeader(info: info, actions: actions),
        child,
      ],
    );
  }
}

class _ThemeModeItem extends ConsumerWidget {
  const _ThemeModeItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final themeMode = ref.watch(
      themeSettingProvider.select((state) => state.themeMode),
    );
    final List<ThemeModeItem> themeModeItems = [
      ThemeModeItem(
        iconData: Icons.auto_mode,
        label: appLocalizations.auto,
        themeMode: ThemeMode.system,
      ),
      ThemeModeItem(
        iconData: Icons.light_mode,
        label: appLocalizations.light,
        themeMode: ThemeMode.light,
      ),
      ThemeModeItem(
        iconData: Icons.dark_mode,
        label: appLocalizations.dark,
        themeMode: ThemeMode.dark,
      ),
    ];
    return SliverToBoxAdapter(
      // 三块设置依次浮上来。这一页只在用户主动打开时构建，之后不会被数据刷新
      // 重建，所以逐项入场不会变成反复抖动。
      child: StaggeredEntrance(
        index: 0,
        child: ItemCard(
          info: Info(
            label: appLocalizations.themeMode,
            iconData: Icons.brightness_high,
          ),
          child: ChipRow(
            itemCount: themeModeItems.length,
            itemBuilder: (_, index) {
              final themeModeItem = themeModeItems[index];
              return CommonCard(
                isSelected: themeModeItem.themeMode == themeMode,
                onPressed: () {
                  ref
                      .read(themeSettingProvider.notifier)
                      .update(
                        (state) =>
                            state.copyWith(themeMode: themeModeItem.themeMode),
                      );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Flexible(child: Icon(themeModeItem.iconData)),
                      const SizedBox(width: 8),
                      Flexible(child: Text(themeModeItem.label)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TextScaleFactorItem extends ConsumerWidget {
  const _TextScaleFactorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final textScale = ref.watch(
      themeSettingProvider.select((state) => state.textScale),
    );
    final String process = '${(textScale.scale * 100).round()}%';
    return SliverToBoxAdapter(
      child: StaggeredEntrance(
        index: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListItem.toggle(
                leading: const Icon(Icons.text_fields),
                horizontalTitleGap: 12,
                title: Text(
                  appLocalizations.textScale,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: textScale.enable,
                onChanged: (value) {
                  ref
                      .read(themeSettingProvider.notifier)
                      .update(
                        (state) => state.copyWith.textScale(enable: value),
                      );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                spacing: 32,
                children: [
                  Expanded(
                    // 开关关着时让 Slider **真的进入禁用态**（onChanged 传 null），
                    // 不再套 DisabledMask + ActivateBox。
                    //
                    // 原来那套是「照常渲染一个可用的滑块，再盖一层灰度滤镜，外面
                    // 用 IgnorePointer 拦手势」。灰度矩阵把实蓝 #006FEE 算成亮度
                    // 约 97 再提亮 30 ≈ 中灰 127——深色底上不显眼，**白底上就是一
                    // 条横贯半屏的深灰实条**，正是用户看到的那个。
                    //
                    // 换成真禁用还顺带修了两件事：读屏会播报"已停用"（灰度滤镜
                    // 不会），以及禁用色由 SliderDefaultsM3 统一管，不再有第二处
                    // 决定"禁用长什么样"。
                    child: SliderTheme(
                      data: SliderDefaultsM3(context),
                      child: Slider(
                        padding: EdgeInsets.zero,
                        min: minTextScale,
                        max: maxTextScale,
                        value: textScale.scale,
                        onChanged: !textScale.enable
                            ? null
                            : (value) {
                                ref
                                    .read(themeSettingProvider.notifier)
                                    .update(
                                      (state) => state.copyWith.textScale(
                                        scale: value,
                                      ),
                                    );
                              },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    // 这里**故意不用** AnimatedCount：百分比是滑块的读数，必须
                    // 和手指同步。加了缓动它就会落后指尖一截，看起来像卡了。
                    child: Text(
                      process,
                      style: context.textTheme.titleMedium?.copyWith(
                        // 读数跟着滑块一起淡下去，否则滑块禁用了、旁边的数字还是
                        // 满对比度，看着像"这个数还能改"。
                        color: textScale.enable
                            ? null
                            : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 界面风格选择器。
///
/// 这里只留四种风格，FlClash 原来那套「主色调色盘 / 配色方案 / 纯黑模式」已经
/// 删掉——每种风格自带一整套配色，再让用户单独挑主色只会互相打架。
class _AppStyleItem extends ConsumerWidget {
  const _AppStyleItem();

  /// 每种风格的预览色：底色 + 卡片色 + 强调色，三个色块摆一起就能看出差别。
  ///
  /// **按当前亮度取**。原来写死取 [AppStyleTokens.darkSurfaces]，于是浅色模式下
  /// 这排预览点全是深色的——用户正在看白底界面，预览却在给他看黑底，选之前根本
  /// 判断不出切过去长什么样。
  List<Color> _swatch(
    AppStyleTokens tokens,
    ColorScheme scheme,
    Brightness brightness,
  ) {
    final surfaces = tokens.surfacesFor(brightness);
    return [
      surfaces?.surface ?? scheme.surface,
      // 中间这颗取 containerHigh 而不是 container：浅色下 Clash Party 的
      // container 就是纯白，和第一颗的 surface 一模一样，两颗白点挨在一起等于
      // 只有一颗。containerHigh 在四种风格的深浅两套里都和 surface 拉得开。
      surfaces?.containerHigh ?? scheme.surfaceContainerHigh,
      tokens.accent(scheme),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      themeSettingProvider.select((state) => state.appStyle),
    );
    final scheme = context.colorScheme;
    final brightness = Theme.of(context).brightness;
    return SliverToBoxAdapter(
      child: StaggeredEntrance(
        index: 1,
        child: ItemCard(
          info: Info(
            label: context.appLocalizations.theme,
            iconData: Icons.style_outlined,
          ),
          child: ChipRow(
            itemCount: AppStyle.values.length,
            itemBuilder: (_, index) {
              final style = AppStyle.values[index];
              final tokens = AppStyleTokens.of(style);
              return CommonCard(
                isSelected: style == current,
                onPressed: () {
                  ref
                      .read(themeSettingProvider.notifier)
                      .update((state) => state.copyWith(appStyle: style));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final color in _swatch(tokens, scheme, brightness))
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: color,
                            // 预览块跟着这套风格的卡片圆角走，按 14 像素等比缩小。
                            // 于是 Material You（20）缩成一个圆点、Fluent（8）几乎
                            // 是方块、Clash Party 和 iOS 落在中间——**光靠配色在
                            // 浅色下分不出四种风格**（四套底色都接近白），加上圆角
                            // 才能一眼看出切过去是哪种界面语言。
                            borderRadius: BorderRadius.circular(
                              tokens.cardRadius * 14 / 40,
                            ),
                            border: Border.all(
                              color: scheme.onSurface.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(style.labelOf(context)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
