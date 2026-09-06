import 'package:collection/collection.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/inherited.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'card.dart';
import 'input.dart';
import 'open_container.dart';
import 'scaffold.dart';
import 'sheet.dart';

sealed class _ListItemAction {
  const _ListItemAction();
}

final class _DefaultAction extends _ListItemAction {
  const _DefaultAction();
}

final class _RadioAction<T> extends _ListItemAction {
  final T value;
  final VoidCallback? onTap;

  const _RadioAction({required this.value, this.onTap});
}

final class _ToggleAction extends _ListItemAction {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleAction({required this.value, this.onChanged});
}

final class _CheckboxAction extends _ListItemAction {
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const _CheckboxAction({required this.value, this.onChanged});
}

final class _OpenAction extends _ListItemAction {
  final Widget widget;
  final double? maxWidth;
  final bool blur;
  final bool forceFull;
  final ValueChanged<dynamic>? onChanged;

  const _OpenAction({
    required this.widget,
    this.maxWidth,
    required this.blur,
    required this.forceFull,
    this.onChanged,
  });
}

final class _NextAction extends _ListItemAction {
  final Widget widget;
  final double? maxWidth;
  final bool blur;

  const _NextAction({required this.widget, this.maxWidth, required this.blur});
}

final class _OptionsAction<T> extends _ListItemAction {
  final List<T> options;
  final String title;
  final T value;
  final String Function(T value) textBuilder;
  final ValueChanged<T?> onChanged;

  const _OptionsAction({
    required this.title,
    required this.options,
    required this.textBuilder,
    required this.value,
    required this.onChanged,
  });
}

final class _InputAction extends _ListItemAction {
  final String title;
  final String value;
  final String? suffixText;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? resetValue;

  const _InputAction({
    required this.title,
    required this.value,
    this.suffixText,
    required this.onChanged,
    this.resetValue,
    this.validator,
    this.maxLength,
    this.keyboardType,
  });
}

class ListItem<T> extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsets padding;
  final ListTileTitleAlignment tileTitleAlignment;
  final bool? dense;
  final Widget? trailing;
  final _ListItemAction _action;
  final double? horizontalTitleGap;
  final TextStyle? titleTextStyle;
  final TextStyle? subtitleTextStyle;
  final double minVerticalPadding;
  final Color? color;
  final double? minTileHeight;
  final VisualDensity? visualDensity;
  final void Function()? onTap;

  const ListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    this.horizontalTitleGap,
    this.dense,
    this.onTap,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = const _DefaultAction();

  ListItem.open({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    required Widget widget,
    double? maxWidth,
    bool blur = true,
    bool forceFull = true,
    ValueChanged<dynamic>? onChanged,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _OpenAction(
         widget: widget,
         maxWidth: maxWidth,
         blur: blur,
         forceFull: forceFull,
         onChanged: onChanged,
       ),
       onTap = null;

  ListItem.next({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    required Widget widget,
    double? maxWidth,
    bool blur = true,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _NextAction(widget: widget, maxWidth: maxWidth, blur: blur),
       onTap = null;

  ListItem.options({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    required String dialogTitle,
    required List<T> options,
    required T value,
    required String Function(T value) textBuilder,
    required ValueChanged<T?> onChanged,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _OptionsAction<T>(
         title: dialogTitle,
         options: options,
         value: value,
         textBuilder: textBuilder,
         onChanged: onChanged,
       ),
       onTap = null;

  ListItem.input({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    required String dialogTitle,
    required String value,
    String? suffixText,
    required ValueChanged<String?> onChanged,
    FormFieldValidator<String>? validator,
    int? maxLength,
    TextInputType? keyboardType,
    String? resetValue,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _InputAction(
         title: dialogTitle,
         value: value,
         suffixText: suffixText,
         onChanged: onChanged,
         validator: validator,
         maxLength: maxLength,
         keyboardType: keyboardType,
         resetValue: resetValue,
       ),
       onTap = null;

  ListItem.checkbox({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.only(left: 16, right: 8),
    bool value = false,
    ValueChanged<bool?>? onChanged,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _CheckboxAction(value: value, onChanged: onChanged),
       trailing = null,
       onTap = null;

  ListItem.toggle({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.only(left: 16, right: 8),
    required bool value,
    ValueChanged<bool>? onChanged,
    this.horizontalTitleGap,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _ToggleAction(value: value, onChanged: onChanged),
       trailing = null,
       onTap = null;

  ListItem.radio({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(left: 12, right: 16),
    required T value,
    VoidCallback? onTap,
    this.horizontalTitleGap = 8,
    this.dense,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.color,
    this.minTileHeight,
    this.visualDensity,
    this.minVerticalPadding = 12,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _RadioAction<T>(value: value, onTap: onTap),
       leading = null,
       onTap = null;

  Widget _buildListTile({
    void Function()? onTap,
    Widget? trailing,
    Widget? leading,
  }) {
    return ListTile(
      key: key,
      dense: dense,
      visualDensity: visualDensity,
      tileColor: color,
      titleTextStyle: titleTextStyle,
      subtitleTextStyle: subtitleTextStyle,
      leading: leading ?? this.leading,
      horizontalTitleGap: horizontalTitleGap,
      title: title,
      minTileHeight: minTileHeight,
      minVerticalPadding: minVerticalPadding,
      subtitle: subtitle,
      titleAlignment: tileTitleAlignment,
      onTap: onTap,
      trailing: trailing ?? this.trailing,
      contentPadding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_action) {
      case final _OpenAction openDelegate:
        final child = openDelegate.widget;
        final onChanged = openDelegate.onChanged;
        return OpenContainer<dynamic>(
          closedBuilder: (context, action) {
            Future<void> openAction() async {
              final isMobile = globalState.container.read(isMobileViewProvider);
              if (!isMobile || kDebugMode) {
                final res = await showExtend(
                  context,
                  props: ExtendProps(
                    blur: openDelegate.blur,
                    maxWidth: openDelegate.maxWidth,
                    forceFull: openDelegate.forceFull,
                  ),
                  builder: (_) {
                    return child;
                  },
                );
                if (onChanged != null) {
                  onChanged(res);
                }
                return;
              }
              action();
            }

            return _buildListTile(onTap: openAction);
          },
          onClosed: onChanged,
          openBuilder: (_, action) {
            return child;
          },
        );
      case final _NextAction nextDelegate:
        final child = nextDelegate.widget;

        return _buildListTile(
          onTap: () {
            showExtend(
              context,
              props: ExtendProps(
                blur: nextDelegate.blur,
                maxWidth: nextDelegate.maxWidth,
              ),
              builder: (_) {
                return child;
              },
            );
          },
        );
      case final _OptionsAction options:
        final optionsDelegate = options as _OptionsAction<T>;
        return _buildListTile(
          onTap: () async {
            // Delivered through onSelected so a dismissed dialog is not
            // mistaken for picking a null option, which is a real choice for
            // callers such as the app language ("follow system").
            await globalState.showCommonDialog<void>(
              child: OptionsDialog<T>(
                title: optionsDelegate.title,
                options: optionsDelegate.options,
                textBuilder: optionsDelegate.textBuilder,
                value: optionsDelegate.value,
                onSelected: optionsDelegate.onChanged,
              ),
            );
          },
        );
      case final _InputAction inputDelegate:
        return _buildListTile(
          onTap: () async {
            final value = await globalState.showCommonDialog<String>(
              child: InputDialog(
                title: inputDelegate.title,
                value: inputDelegate.value,
                suffixText: inputDelegate.suffixText,
                resetValue: inputDelegate.resetValue,
                inputFormatters: inputDelegate.maxLength == null
                    ? null
                    : TextInputLimits.limit(inputDelegate.maxLength!),
                keyboardType: inputDelegate.keyboardType,
                validator: inputDelegate.validator,
              ),
            );
            inputDelegate.onChanged(value);
          },
        );
      case final _CheckboxAction checkboxDelegate:
        return _buildListTile(
          onTap: checkboxDelegate.onChanged == null
              ? null
              : () {
                  checkboxDelegate.onChanged!(!checkboxDelegate.value);
                },
          trailing: CommonCheckBox(
            value: checkboxDelegate.value,
            onChanged: checkboxDelegate.onChanged,
          ),
        );
      case final _ToggleAction toggleAction:
        return _buildListTile(
          onTap: toggleAction.onChanged == null
              ? null
              : () {
                  toggleAction.onChanged!(!toggleAction.value);
                },
          trailing: Switch(
            value: toggleAction.value,
            onChanged: toggleAction.onChanged,
          ),
        );
      case final _RadioAction radio:
        final radioDelegate = radio as _RadioAction<T>;
        // 桌面端的选项列表没有 Material 的圆点：选中的那条在右边打一个主色对勾。
        // 「选中与否」只有外层 RadioGroup 知道，从它的注册表里读 groupValue。
        final isSelected =
            RadioGroup.maybeOf<T>(context)?.groupValue == radioDelegate.value;
        return _buildListTile(
          onTap: radioDelegate.onTap,
          // 对勾**始终占位**，只改透明度和缩放。
          //
          // 原来是 `isSelected ? Icon : null`：选中的瞬间 trailing 从无到有，
          // 整行被挤窄一次，换选项时一列文字跟着抖。而且硬切没有过渡，看不出
          // 「勾从哪一条移到了哪一条」。
          trailing: trailing ?? _RadioCheck(selected: isSelected),
        );
      case _DefaultAction():
        return _buildListTile(onTap: onTap);
    }
  }
}

class ListHeader extends StatelessWidget {
  final String title;
  final String? subTitle;
  final List<Widget> actions;
  final EdgeInsets? padding;
  final double? space;

  const ListHeader({
    super.key,
    required this.title,
    this.subTitle,
    this.padding,
    List<Widget>? actions,
    this.space,
  }) : actions = actions ?? const [];

  /// 标题的样式与实际要显示的文字，由当前风格的 [SectionHeaderStyle] 决定。
  ///
  /// iOS 那一档连**文字本身**都要变（全大写），所以这里一并返回文字，不能只返回
  /// 样式让调用点自己拼。
  (String, TextStyle?) _resolveTitle(BuildContext context) {
    final tokens = context.styleTokens;
    final scheme = context.colorScheme;
    final textTheme = context.textTheme;
    return switch (tokens.headerStyle) {
      SectionHeaderStyle.standard => (
        title,
        textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant.opacity80,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Windows 11 的分组标题用正文色、更粗，比正文"硬"。
      SectionHeaderStyle.strong => (
        title,
        textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      // M3 设置页的分组标题是带主色的。
      SectionHeaderStyle.accent => (
        title,
        textTheme.labelLarge?.copyWith(
          color: tokens.accent(scheme),
          fontWeight: FontWeight.w500,
        ),
      ),
      // iOS 分组表头：全大写、小一号、字距拉开。
      SectionHeaderStyle.uppercase => (
        title.toUpperCase(),
        textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (titleText, titleStyle) = _resolveTitle(context);
    return Container(
      alignment: Alignment.centerLeft,
      padding: padding ?? listHeaderPadding,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 36,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleText, style: titleStyle),
                if (subTitle != null)
                  Text(
                    subTitle!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [...genActions(actions, space: space)],
          ),
        ],
      ),
    );
  }
}

/// 一组设置项。
///
/// 形态由当前风格决定，见 [ListSectionStyle]：Clash Party 是「小标题 + 一张带
/// 阴影的圆角卡片」，Fluent 是「一行一张小卡片」，Material You 是「通栏平铺」，
/// iOS 是「圆角分组 + 从文字开始的分隔线」。
///
/// 调用方不用管这些，一律 `generateSection(...)` 就行。
List<Widget> generateSection({
  String? title,
  required Iterable<Widget> items,
  List<Widget>? actions,
  bool isFirst = false,
  bool separated = true,
}) {
  if (items.isEmpty) return const [];
  return [
    if (title != null)
      ListHeader(
        title: title,
        actions: actions,
        padding: isFirst
            ? listHeaderPadding.copyWith(top: 8.ap)
            : listHeaderPadding,
      ),
    _SectionCard(items: items, separated: separated),
  ];
}

/// 一组设置项的容器。四种风格在这里分成**四种几何**，见 [ListSectionStyle]。
///
/// 只有这一处知道分组长什么样：调用方一律 `generateSection(...)`，换风格时
/// 全 App 的设置页一起跟着变。
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.items, required this.separated});

  final Iterable<Widget> items;
  final bool separated;

  Widget _divider(BuildContext context, AppStyleTokens tokens) {
    return Padding(
      // 左内缩由风格决定：Clash Party 从卡片内边距（16）开始，iOS 要从**文字**
      // 开始（56，把前面的图标位让出来）——这是 iOS 分组表最好认的一处细节。
      padding: EdgeInsets.only(left: tokens.dividerInset, right: 16),
      child: Divider(
        height: 0,
        color:
            tokens.dividerColor ??
            context.colorScheme.onSurface.withValues(
              alpha: tokens.dividerOpacity,
            ),
      ),
    );
  }

  /// 用 [Material] 而不是带背景色的 Container：里面装的是 ListTile，
  /// 普通容器会让它的水波纹画不出来（运行时会报 "ink splashes may be
  /// invisible"）。Material 既提供底色也提供墨水层。
  Widget _surface(
    BuildContext context, {
    required double radius,
    required Widget child,
  }) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: context.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.styleTokens;
    final radius = tokens.cardRadius;
    final entries = items.toList();

    switch (tokens.sectionStyle) {
      // ── Clash Party：一张带阴影和高光边的圆角卡片，分隔线内缩 ──
      case ListSectionStyle.card:
        final children = separated
            ? entries.separated(_divider(context, tokens)).toList()
            : entries;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: tokens.cardShadow,
              // 和磁贴一样的高光边，设置页的分组卡片才不是一块死板色块。
              border: Border.all(color: tokens.rim, width: 1),
            ),
            child: _surface(
              context,
              radius: radius,
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        );

      // ── Fluent：一行一张小卡片，行间留空，不画分隔线 ──
      //
      // Windows 11 设置页就是这个样子。分隔线在这里是多余的——每行自己有边界了。
      case ListSectionStyle.splitRows:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              for (final item in entries)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: tokens.cardShadow,
                    border: Border.all(color: tokens.rim, width: 1),
                  ),
                  child: _surface(context, radius: radius, child: item),
                ),
            ],
          ),
        );

      // ── Material You：通栏平铺，没有卡片也没有分隔线 ──
      //
      // 左右不留边，直接贴着页面底色——这是 M3 设置页的做法，也是四种里唯一
      // 「内容顶到屏幕两侧」的一档。
      case ListSectionStyle.flat:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: context.colorScheme.surface,
            child: Column(mainAxisSize: MainAxisSize.min, children: entries),
          ),
        );

      // ── iOS：Inset Grouped，圆角分组、不投影不描边、分隔线从文字开始 ──
      case ListSectionStyle.insetGrouped:
        final children = separated
            ? entries.separated(_divider(context, tokens)).toList()
            : entries;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _surface(
            context,
            radius: radius,
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        );
    }
  }
}

Widget generateSectionV2({
  String? title,
  required Iterable<Widget> items,
  List<Widget>? actions,
  bool separated = true,
}) {
  final genItems = items
      .map<Widget>((item) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CommonCard(
            type: CommonCardType.filled,
            radius: 0,
            child: item,
          ),
        );
      })
      .separated(const Divider(height: 2, color: Colors.transparent));
  return Column(
    children: [
      if (items.isNotEmpty && title != null)
        ListHeader(title: title, actions: actions),
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: [...genItems]),
      ),
    ],
  );
}

Widget generateSectionV3({
  String? title,
  required Iterable<Widget> items,
  List<Widget>? actions,
}) {
  final genItems = items.mapIndexed<Widget>((index, item) {
    final position = ItemPosition.get(index, items.length);
    if (position != ItemPosition.middle) {
      return ItemPositionProvider(position: position, child: item);
    }
    return item;
  });
  return Column(
    children: [
      if (items.isNotEmpty && title != null)
        ListHeader(title: title, actions: actions),
      Column(children: [...genItems]),
    ],
  );
}

List<Widget> generateInfoSection({
  required Info info,
  required Iterable<Widget> items,
  List<Widget>? actions,
  bool separated = true,
}) {
  final genItems = separated
      ? items.separated(const Divider(height: 0))
      : items;
  return [
    if (items.isNotEmpty) InfoHeader(info: info, actions: actions),
    ...genItems,
  ];
}

Widget generateListView(List<Widget> items) {
  return Builder(
    builder: (context) {
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, index) => items[index],
        // **顶部留白必须显式加上。** 悬浮胶囊占的高度是通过
        // `MediaQuery.padding.top` 发下来的；`ListView` 只有在 `padding` 为 null
        // 时才会自动吃掉它，这里设了 padding 就得自己加回来，否则第一项会被胶囊
        // 挡住。
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          bottom: 16,
        ),
      );
    },
  );
}

class CommonSelectedListItem extends StatelessWidget {
  final bool isSelected;
  final bool isEditing;
  final Widget title;
  final VoidCallback onSelected;
  final VoidCallback onPressed;

  const CommonSelectedListItem({
    super.key,
    required this.isSelected,
    required this.onSelected,
    this.isEditing = false,
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        color: Colors.transparent,
        child: CommonCard(
          radius: 18,
          type: CommonCardType.filled,
          isSelected: isSelected,
          onPressed: () {
            if (isEditing) {
              onSelected();
              return;
            }
            onPressed();
          },
          child: ListTile(
            minTileHeight: 32 + globalState.measure.bodyMediumHeight,
            minVerticalPadding: 12,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            trailing: SizedBox(
              width: 24,
              height: 24,
              child: CommonCheckBox(
                value: isSelected,
                isCircle: true,
                onChanged: (_) {
                  onSelected();
                },
              ),
            ),
            title: title,
          ),
        ),
      ),
    );
  }
}

class DecorationListItem extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool? isSelected;
  final double? horizontalTitleGap;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onPressed;
  final double? minVerticalPadding;
  final bool invalid;

  const DecorationListItem({
    super.key,
    this.contentPadding,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
    this.isSelected,
    this.onPressed,
    this.horizontalTitleGap,
    this.minVerticalPadding,
    this.invalid = false,
  });

  @override
  Widget build(BuildContext context) {
    final proxyDecorator =
        ProxyDecoratorProvider.of(context)?.isProxyDecorator ?? false;
    final position = ItemPositionProvider.of(context)?.position;
    final isStart = [
      ItemPosition.start,
      ItemPosition.startAndEnd,
    ].contains(position);
    final isEnd = [
      ItemPosition.end,
      ItemPosition.startAndEnd,
    ].contains(position);
    final borderRadius = BorderRadius.vertical(
      top: isStart ? const Radius.circular(24) : Radius.zero,
      bottom: isEnd ? const Radius.circular(24) : Radius.zero,
    );
    return CommonCard(
      shape: proxyDecorator == true
          ? LinearBorder.none
          : RoundedSuperellipseBorder(borderRadius: borderRadius),
      isError: invalid,
      isSelected: isSelected,
      padding: EdgeInsets.zero,
      type: CommonCardType.filled,
      onPressed: proxyDecorator ? null : onPressed,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final isInfinite = constraints.maxHeight >= double.infinity;
          final tile = ListTile(
            leading: leading,
            contentPadding:
                contentPadding ?? const EdgeInsets.only(right: 16, left: 16),
            title: title,
            subtitle: subtitle,
            minVerticalPadding: minVerticalPadding ?? 6,
            minTileHeight: 54,
            horizontalTitleGap: horizontalTitleGap,
            trailing: trailing,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                fit: isInfinite ? FlexFit.loose : FlexFit.tight,
                child: tile,
              ),
              if (!invalid && proxyDecorator != true && !isEnd)
                const Divider(height: 0, indent: 14, endIndent: 14),
            ],
          );
        },
      ),
    );
  }
}

class SelectedDecorationListItem extends StatelessWidget {
  final bool isSelected;
  final bool isEditing;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onSelected;
  final VoidCallback onPressed;
  final double? horizontalTitleGap;
  final Widget? leading;
  final bool invalid;
  final double? minVerticalPadding;

  const SelectedDecorationListItem({
    super.key,
    required this.isSelected,
    required this.onSelected,
    this.horizontalTitleGap,
    this.isEditing = false,
    this.invalid = false,
    required this.title,
    required this.onPressed,
    this.minVerticalPadding,
    this.subtitle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      title: title,
      minVerticalPadding: minVerticalPadding,
      contentPadding: const EdgeInsets.only(left: 16, right: 0),
      isSelected: isSelected,
      invalid: invalid,
      leading: leading,
      horizontalTitleGap: horizontalTitleGap,
      onPressed: () {
        if (isEditing) {
          onSelected();
          return;
        }
        onPressed();
      },
      subtitle: subtitle,
      trailing: CommonCheckBox(
        value: isSelected,
        isCircle: true,
        onChanged: (_) {
          onSelected();
        },
      ),
    );
  }
}

/// 单选行右侧的对勾。
///
/// 始终占位、只改透明度和缩放——见 `ListItem.radio` 里的说明。
class _RadioCheck extends StatelessWidget {
  const _RadioCheck({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1 : 0.7,
      duration: Motion.quick,
      curve: Motion.enter,
      child: AnimatedOpacity(
        opacity: selected ? 1 : 0,
        duration: Motion.quick,
        curve: Motion.enter,
        child: Icon(
          Icons.check,
          size: 20,
          color: context.styleTokens.accent(context.colorScheme),
        ),
      ),
    );
  }
}
