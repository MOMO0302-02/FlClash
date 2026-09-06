import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/features/overwrite/rule.dart';
import 'package:clash_party/models/clash_config.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StandardContent extends ConsumerStatefulWidget {
  const StandardContent({super.key});

  @override
  ConsumerState createState() => _StandardContentState();
}

class _StandardContentState extends ConsumerState<StandardContent> {
  final _key = utils.id;
  late int _profileId;

  Future<void> _handleAddOrUpdate([Rule? rule]) async {
    final res = await globalState.showCommonDialog<Rule>(
      child: AddOrEditRuleDialog(rule: rule),
    );
    if (res == null) {
      return;
    }
    ref.read(profileAddedRulesProvider(_profileId).notifier).put(res);
  }

  void _handleSelected(int ruleId) {
    ref.read(itemsProvider(_key).notifier).update((selectedRules) {
      final newSelectedRules = Set<int>.from(selectedRules)
        ..addOrRemove(ruleId);
      return newSelectedRules;
    });
  }

  void _handleSelectAll() {
    final ids =
        ref
            .read(profileAddedRulesProvider(_profileId))
            .value
            ?.map((item) => item.id)
            .toSet() ??
        {};
    ref.read(itemsProvider(_key).notifier).update((selected) {
      return selected.containsAll(ids) ? {} : ids;
    });
  }

  Future<void> _handleDelete() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteMultipTip(appLocalizations.rule),
      ),
    );
    if (res != true) {
      return;
    }
    final selectedRules = ref.read(itemsProvider(_key));
    ref
        .read(profileAddedRulesProvider(_profileId).notifier)
        .delAll(selectedRules.cast<int>());
    ref.read(itemsProvider(_key).notifier).value = {};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileId = ProfileIdProvider.of(context)!.profileId;
  }

  void _handleToEditGlobalAddedRules() {
    BaseNavigator.push(context, _EditGlobalAddedRules(_profileId));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    _profileId = ProfileIdProvider.of(context)!.profileId;
    final addedRules =
        ref.watch(profileAddedRulesProvider(_profileId)).value ?? [];
    final selectedRules = ref.watch(itemsProvider(_key));
    return CommonPopScope(
      onPop: (_) {
        if (selectedRules.isNotEmpty) {
          ref.read(itemsProvider(_key).notifier).value = {};
          return false;
        }
        Navigator.of(context).pop();
        return false;
      },
      child: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // 用 ListHeader 而不是 InfoHeader：分组小标题在本项目里统一是
                // 一行小灰字（generateSection 内部用的就是它），InfoHeader 那
                // 套「图标 + 标题」是卡片头部的形态，两者混用会显得不成体系。
                ListHeader(
                  title: appLocalizations.addedRules,
                  actions: [
                    if (selectedRules.isNotEmpty) ...[
                      CommonMinIconButtonTheme(
                        child: IconButton.filledTonal(
                          onPressed: () {
                            _handleDelete();
                          },
                          icon: const Icon(Icons.delete),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    CommonMinFilledButtonTheme(
                      child: selectedRules.isNotEmpty
                          ? FilledButton(
                              onPressed: () {
                                _handleSelectAll();
                              },
                              child: Text(appLocalizations.selectAll),
                            )
                          : FilledButton.tonal(
                              onPressed: () {
                                _handleAddOrUpdate();
                              },
                              child: Text(appLocalizations.add),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (addedRules.isEmpty)
            SliverToBoxAdapter(
              // 一条规则都没有时原来是一片空白，用户看不出是没数据还是没加载。
              // 不给动作：上面那行标题右边已经有「添加」了，同屏两个一样的按钮
              // 是本项目踩过的坑。
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: NullStatus(
                  label: appLocalizations.nullTip(appLocalizations.rule),
                  illustration: const RuleEmptyIllustration(),
                ),
              ),
            ),
          Consumer(
            builder: (_, ref, _) {
              return SliverReorderableList(
                itemCount: addedRules.length,
                itemBuilder: (_, index) {
                  final rule = addedRules[index];
                  final position = ItemPosition.get(index, addedRules.length);
                  return ReorderableDelayedDragStartListener(
                    key: ObjectKey(rule),
                    index: index,
                    child: ItemPositionProvider(
                      position: position,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: RuleItem(
                          hasMatch: true,
                          isEditing: selectedRules.isNotEmpty,
                          isSelected: selectedRules.contains(rule.id),
                          rule: rule,
                          onSelected: () {
                            _handleSelected(rule.id);
                          },
                          onEdit: (rule) {
                            _handleAddOrUpdate(rule);
                          },
                        ),
                      ),
                    ),
                  );
                },
                itemExtent: ruleItemHeight,
                onReorderItem: ref
                    .read(profileAddedRulesProvider(_profileId).notifier)
                    .order,
              );
            },
          ),
          SliverToBoxAdapter(
            // 不再用 MoreActionButton：它写死 18 圆角、标题用等宽字体，跟
            // tokens.cardRadius(14) 和分组卡片对不上。换成同一条 generateSection。
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: generateSection(
                items: [
                  ListItem(
                    leading: const Icon(Icons.library_books, size: 20),
                    title: Text(appLocalizations.controlGlobalAddedRules),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _handleToEditGlobalAddedRules,
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _EditGlobalAddedRules extends ConsumerWidget {
  final int profileId;

  const _EditGlobalAddedRules(this.profileId);

  void _handleChange(WidgetRef ref, int profileId, bool status, int ruleId) {
    if (status) {
      ref.read(profileDisabledRuleIdsProvider(profileId).notifier).put(ruleId);
    } else {
      ref.read(profileDisabledRuleIdsProvider(profileId).notifier).del(ruleId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final disabledRuleIds =
        ref.watch(profileDisabledRuleIdsProvider(profileId)).value ?? [];
    final rules = ref.watch(globalRulesProvider).value ?? [];
    return BaseScaffold(
      title: appLocalizations.editGlobalRules,
      body: rules.isEmpty
          ? NullStatus(
              label: appLocalizations.nullTip(appLocalizations.rule),
              illustration: const RuleEmptyIllustration(),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemExtent: ruleItemHeight,
              itemBuilder: (context, index) {
                final rule = rules[index];
                final position = ItemPosition.get(index, rules.length);
                return ItemPositionProvider(
                  position: position,
                  child: RuleStatusItem(
                    status: !disabledRuleIds.contains(rule.id),
                    rule: rule,
                    onChange: (status) {
                      _handleChange(ref, profileId, !status, rule.id);
                    },
                  ),
                );
              },
              itemCount: rules.length,
            ),
    );
  }
}
