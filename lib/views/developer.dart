import 'package:clash_party/common/common.dart';
import 'package:clash_party/core/controller.dart';
import 'package:clash_party/models/common.dart';
import 'package:clash_party/providers/action.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeveloperView extends ConsumerWidget {
  const DeveloperView({super.key});

  /// 开发者选项。
  ///
  /// 原来用的是 `generateSectionV2`——每条自己是一张 18 圆角的填充卡片、彼此留空
  /// 隙，全 App 只有这一处这么长。改成和其它设置页同一个 `generateSection`：
  /// 一张 14 圆角的分组卡片，条目之间是缩进的细分隔线。
  List<Widget> _buildOptions(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return generateSection(
      title: appLocalizations.options,
      items: [
        ListItem(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(appLocalizations.messageTest),
          minVerticalPadding: 12,
          onTap: () {
            context.showNotifier(appLocalizations.messageTestTip);
          },
        ),
        ListItem(
          leading: const Icon(Icons.article_outlined),
          title: Text(appLocalizations.logsTest),
          minVerticalPadding: 12,
          onTap: () {
            for (int i = 0; i < 1000; i++) {
              globalState.container
                  .read(logsProvider.notifier)
                  .add(
                    Log.app(
                      '[$i]${utils.generateRandomString(maxLength: 200, minLength: 20)}',
                    ),
                  );
            }
          },
        ),
        if (globalState.canCrashCore)
          ListItem(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(appLocalizations.crashTest),
            minVerticalPadding: 12,
            onTap: () async {
              final res = await globalState.showMessage(
                message: TextSpan(text: appLocalizations.confirmForceCrashCore),
              );
              if (res != true) {
                return;
              }
              coreController.crash();
            },
          ),
        ListItem(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: Text(appLocalizations.clearData),
          minVerticalPadding: 12,
          onTap: () async {
            final res = await globalState.showMessage(
              message: TextSpan(text: appLocalizations.confirmClearAllData),
            );
            if (res != true) {
              return;
            }
            await globalState.container
                .read(storeActionProvider.notifier)
                .handleClear();
          },
        ),
        ListItem(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: Text(appLocalizations.pruneCache),
          minVerticalPadding: 12,
          onTap: () async {
            await globalState.container
                .read(storeActionProvider.notifier)
                .shakingStore();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      appSettingProvider.select((state) => state.developerMode),
    );
    return BaseScaffold(
      title: appLocalizations.developerMode,
      // 总开关原来是一张单独手写的 18 圆角卡片，圆角和内边距都和别处对不上。
      // 走同一个 generateSection（无标题）后，取值全部来自主题里的 tokens。
      body: generateListView([
        ...generateSection(
          items: [
            ListItem.toggle(
              leading: const Icon(Icons.developer_mode),
              title: Text(appLocalizations.developerMode),
              value: enable,
              onChanged: (value) {
                ref
                    .read(appSettingProvider.notifier)
                    .update((state) => state.copyWith(developerMode: value));
              },
            ),
          ],
        ),
        ..._buildOptions(context),
      ]),
    );
  }
}
