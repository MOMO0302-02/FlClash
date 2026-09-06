import 'package:clash_party/common/common.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/views/config/scripts.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScriptContent extends ConsumerWidget {
  const ScriptContent({super.key});

  void _handleChange(WidgetRef ref, int profileId, int scriptId) {
    ref.read(profilesProvider.notifier).updateProfile(profileId, (state) {
      return state.copyWith(
        scriptId: state.scriptId == scriptId ? null : scriptId,
      );
    });
  }

  void _toScripts(BuildContext context) {
    BaseNavigator.push(context, const ScriptsView());
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final scriptId = ref.watch(
      profileProvider(profileId).select((state) => state?.scriptId),
    );
    final scripts = ref.watch(scriptsProvider).value ?? [];
    final colorScheme = context.colorScheme;
    final accent = context.styleTokens.accent(colorScheme);

    if (scripts.isEmpty) {
      // 一个脚本都没有时原来是一片空白，只在最底下挂个「去配置脚本」的卡片。
      // 空状态是邀请用户做下一件事的地方，把说明和入口摆在中间。
      return SliverFillRemaining(
        hasScrollBody: false,
        child: NullStatus(
          label: appLocalizations.nullTip(appLocalizations.script),
          description: appLocalizations.scriptModeDesc,
          illustration: const ScriptEmptyIllustration(),
          action: FilledButton.icon(
            onPressed: () => _toScripts(context),
            icon: const Icon(Icons.add),
            label: Text(appLocalizations.goToConfigureScript),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单选组照桌面端的形态：一列带图标的行，选中的那条右边打一个蓝勾。
          // 原来每个脚本各占一张 filled 卡片、左边挂一个 Material 单选钮，
          // 那是安卓原生列表的样子。
          ...generateSection(
            title: appLocalizations.overrideScript,
            items: [
              for (final script in scripts)
                ListItem(
                  leading: Icon(
                    Icons.rocket,
                    size: 20,
                    color: scriptId == script.id
                        ? accent
                        : colorScheme.onSurface,
                  ),
                  title: Text(script.label),
                  trailing: scriptId == script.id
                      ? Icon(Icons.check, size: 20, color: accent)
                      : null,
                  // 再点一次取消选中：沿用原来 Radio 的 toggleable 行为。
                  onTap: () {
                    _handleChange(ref, profileId, script.id);
                  },
                ),
            ],
          ),
          ...generateSection(
            items: [
              ListItem(
                leading: const Icon(Icons.edit_note, size: 20),
                title: Text(appLocalizations.goToConfigureScript),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _toScripts(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
