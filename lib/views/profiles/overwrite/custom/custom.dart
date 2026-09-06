import 'package:clash_party/common/common.dart';
import 'package:clash_party/database/database.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'groups.dart';
import 'rules.dart';

class CustomContent extends ConsumerWidget {
  const CustomContent({super.key});

  void _handleUseDefault(WidgetRef ref, int profileId) async {
    final res = await globalState.showMessage(
      message: TextSpan(text: currentAppLocalizations.confirmOverwriteTip),
    );
    if (res != true) {
      return;
    }
    final clashConfig = await ref.read(clashConfigProvider(profileId).future);
    await database.setProfileCustomData(
      profileId,
      clashConfig.proxyGroups,
      clashConfig.rules,
    );
  }

  void _handleToProxyGroupsView(BuildContext context, int profileId) {
    BaseNavigator.push(context, CustomProxyGroupsView(profileId));
  }

  void _handleToRulesView(BuildContext context, int profileId) {
    BaseNavigator.push(context, CustomRulesView(profileId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    ref.listen(proxyGroupsProvider(profileId), (_, _) {});
    ref.listen(profileCustomRulesProvider(profileId), (_, _) {});
    ref.listen(customOverwriteDateProvider(profileId), (_, _) {});
    final proxyGroupNum =
        ref.watch(proxyGroupsCountProvider(profileId)).value ?? -1;
    final ruleNum = ref.watch(customRulesCountProvider(profileId)).value ?? -1;
    final vm2 = ref.watch(
      clashConfigProvider(profileId).select((state) {
        final clashConfig = state.value;
        return VM2(
          clashConfig?.proxyGroups.isNotEmpty ?? false,
          clashConfig?.rules.isNotEmpty ?? false,
        );
      }),
    );
    final hasDefaultGroups = vm2.a;
    final hasDefaultRules = vm2.b;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          // 两个入口收进一张圆角分组卡片，和覆写模式那一组是同一套语言；
          // 原来是两张各自独立的卡片，中间还留 4 像素缝，像两块散件。
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: generateSection(
              title: appLocalizations.custom,
              items: [
                ListItem(
                  leading: const Icon(Icons.workspaces, size: 20),
                  title: Text(appLocalizations.proxyGroup),
                  trailing: _EntryTrailing(count: proxyGroupNum),
                  onTap: () {
                    _handleToProxyGroupsView(context, profileId);
                  },
                ),
                ListItem(
                  leading: const Icon(Icons.pin_invoke, size: 20),
                  title: Text(appLocalizations.rule),
                  trailing: _EntryTrailing(count: ruleNum),
                  onTap: () {
                    _handleToRulesView(context, profileId);
                  },
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
        if ((proxyGroupNum == 0 && hasDefaultGroups) ||
            (ruleNum == 0 && hasDefaultRules) ||
            kDebugMode)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              // 原来是 MaterialBanner——安卓原生那条通知横幅，圆角、底色、
              // 内边距全是 Material 自己的一套，和这一页别的卡片对不上。
              // 换成走 tokens 的普通卡片：14 圆角 + 高光描边 + 淡阴影。
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: CommonCard(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            appLocalizations.configDataDetected,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CommonMinFilledButtonTheme(
                          child: FilledButton(
                            onPressed: () {
                              _handleUseDefault(ref, profileId);
                            },
                            child: Text(appLocalizations.quickFill),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 入口行右侧的「计数角标 + 箭头」。
///
/// 角标照桌面端 HeroUI `variant="bordered"` 的 Chip：空心蓝边 + 蓝字，内部透明。
/// 原来用的是 `Card.filled`，灰底实心块，是 Material 的默认样子。
/// 计数还没读出来时（provider 未就绪返回 -1）不画角标，别把 `-1` 摆给用户看。
class _EntryTrailing extends StatelessWidget {
  const _EntryTrailing({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final accent = context.styleTokens.accent(context.colorScheme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count >= 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: accent, width: 1),
              borderRadius: BorderRadius.circular(999),
            ),
            // 从代理组 / 规则的编辑页返回时，这个数会变。让它滚过去，用户一眼
            // 看得出「刚才那趟编辑改动了几条」；直接换数字的话，回到这一页只会
            // 觉得什么都没发生。
            child: AnimatedCount(
              value: count,
              builder: (_, value) => Text(
                '${value.round()}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_ios, size: 16),
      ],
    );
  }
}
