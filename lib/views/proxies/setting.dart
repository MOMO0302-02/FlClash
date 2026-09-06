import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 代理页的设置面板。
///
/// 照桌面端来：桌面端右上角那个下拉面板是**一列带图标的行，选中的那条右边打勾**，
/// 分组标题就是一行小灰字。之前手机端做成了一排排胶囊按钮（横向滚动的 Wrap），
/// 和桌面端完全是两种东西——选项一多就得横滑，也看不出哪些是一组的。
///
/// 现在每组是一张圆角卡片，每个选项一行：左边图标、中间名称、选中的右边一个主色
/// 对勾。和设置页其它地方、以及桌面端都对得上。
class ProxiesSetting extends StatelessWidget {
  const ProxiesSetting({super.key});

  IconData _getIconWithProxiesSortType(ProxiesSortType type) {
    return switch (type) {
      ProxiesSortType.none => Icons.sort,
      ProxiesSortType.delay => Icons.network_ping,
      ProxiesSortType.name => Icons.sort_by_alpha,
    };
  }

  String _getStringProxiesSortType(BuildContext context, ProxiesSortType type) {
    final appLocalizations = context.appLocalizations;
    return switch (type) {
      ProxiesSortType.none => appLocalizations.defaultText,
      ProxiesSortType.delay => appLocalizations.delay,
      ProxiesSortType.name => appLocalizations.name,
    };
  }

  IconData _getIconWithProxiesIconStyle(ProxiesIconStyle style) {
    return switch (style) {
      ProxiesIconStyle.standard => Icons.image_outlined,
      ProxiesIconStyle.none => Icons.hide_image_outlined,
      ProxiesIconStyle.icon => Icons.apps,
    };
  }

  String _getTextWithProxiesIconStyle(
    BuildContext context,
    ProxiesIconStyle style,
  ) {
    final appLocalizations = context.appLocalizations;
    return switch (style) {
      ProxiesIconStyle.standard => appLocalizations.standard,
      ProxiesIconStyle.none => appLocalizations.none,
      ProxiesIconStyle.icon => appLocalizations.onlyIcon,
    };
  }

  /// 一组单选。每个选项一行，选中的右边打勾——桌面端下拉面板就是这个样子。
  List<Widget> _optionSection<T>({
    required BuildContext context,
    required String title,
    required List<T> values,
    required T current,
    required IconData Function(T value) iconOf,
    required String Function(T value) labelOf,
    required void Function(T value) onSelected,
    bool isFirst = false,
  }) {
    final accent = context.styleTokens.accent(context.colorScheme);
    return generateSection(
      title: title,
      isFirst: isFirst,
      items: [
        for (final value in values)
          ListItem(
            leading: Icon(
              iconOf(value),
              size: 20,
              color: value == current ? accent : context.colorScheme.onSurface,
            ),
            title: Text(labelOf(value)),
            trailing: value == current
                ? Icon(Icons.check, size: 20, color: accent)
                : null,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Consumer(
        builder: (_, ref, _) {
          final style = ref.watch(proxiesStyleSettingProvider);
          final notifier = ref.read(proxiesStyleSettingProvider.notifier);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._optionSection<ProxiesSortType>(
                context: context,
                title: appLocalizations.sort,
                values: ProxiesSortType.values,
                current: style.sortType,
                iconOf: _getIconWithProxiesSortType,
                labelOf: (value) => _getStringProxiesSortType(context, value),
                onSelected: (value) =>
                    notifier.update((state) => state.copyWith(sortType: value)),
              ),
              ..._optionSection<_InfoMode>(
                context: context,
                title: appLocalizations.infoMode,
                values: _InfoMode.values,
                current: _InfoMode.of(style.cardType),
                iconOf: (value) => value == _InfoMode.detailed
                    ? Icons.view_agenda_outlined
                    : Icons.view_headline,
                labelOf: (value) => value == _InfoMode.detailed
                    ? appLocalizations.detailedInfo
                    : appLocalizations.conciseInfo,
                onSelected: (value) => notifier.update(
                  (state) => state.copyWith(
                    cardType: value.cardType,
                    layout: value.layout,
                  ),
                ),
              ),
              ..._optionSection<ProxiesIconStyle>(
                context: context,
                title: appLocalizations.iconStyle,
                values: ProxiesIconStyle.values,
                current: style.iconStyle,
                iconOf: _getIconWithProxiesIconStyle,
                labelOf: (value) =>
                    _getTextWithProxiesIconStyle(context, value),
                onSelected: (value) => notifier.update(
                  (state) => state.copyWith(iconStyle: value),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 信息模式：桌面端只给「简洁信息 / 详细信息」两档，手机端原来拆成了「布局」和
/// 「尺寸」两组共六个选项，选起来很啰嗦、组合出来的效果也没那么多种。
///
/// 现在合并成两档，每档同时定死排布密度和卡片信息量：
/// * 详细——展开的卡片、标准密度，能看到节点的全部信息；
/// * 简洁——最小卡片、紧凑密度，一屏塞得下更多节点。
///
/// **没有新增存储字段**，仍然写回原来的 `cardType` 和 `layout`，当前处于哪一档
/// 直接由 `cardType` 反推。少一个字段就少一处会和界面对不上的状态。
enum _InfoMode {
  detailed(ProxyCardType.expand, ProxiesLayout.standard),
  concise(ProxyCardType.min, ProxiesLayout.tight);

  const _InfoMode(this.cardType, this.layout);

  final ProxyCardType cardType;
  final ProxiesLayout layout;

  static _InfoMode of(ProxyCardType cardType) =>
      cardType == ProxyCardType.expand ? detailed : concise;
}
