import 'dart:convert';
import 'dart:io';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/core/core.dart';
import 'package:clash_party/models/common.dart';
import 'package:clash_party/models/core.dart';
import 'package:clash_party/providers/action.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef UpdatingMap = Map<String, bool>;

class ProvidersView extends ConsumerStatefulWidget {
  const ProvidersView({super.key});

  @override
  ConsumerState<ProvidersView> createState() => _ProvidersViewState();
}

class _ProvidersViewState extends ConsumerState<ProvidersView> {
  /// 整批同步正在跑。
  ///
  /// 顶栏那个同步按钮点下去界面上没有任何变化（每一行的转圈只受各自的
  /// isUpdatingProvider 控制），所以用户很自然会再点一下——于是同一批提供者
  /// 会被并发拉两遍，失败提示对话框也会叠着弹两个。订阅页那个同样的批量按钮
  /// 早就有这道闸（profiles.dart 的 _isUpdating），这里漏了。
  bool _isUpdating = false;

  Future<void> _updateProviders() async {
    if (_isUpdating) {
      return;
    }
    _isUpdating = true;
    final ref = globalState.container;
    final providers = ref.read(providersProvider);
    final List<UpdatingMessage> messages = [];
    try {
      final updateProviders = providers.map<Future>((provider) async {
        final message = await ref
            .read(proxiesActionProvider.notifier)
            .updateProvider(provider, showLoading: true);
        if (message.isNotEmpty) {
          messages.add(UpdatingMessage(label: provider.name, message: message));
        }
      });
      await Future.wait(updateProviders);
    } finally {
      // 放在 finally 里：中途抛异常时闸门不放开的话，同步按钮就永久失灵了。
      _isUpdating = false;
    }
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
    if (messages.isNotEmpty) {
      globalState.showAllUpdatingMessagesDialog(messages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final providers = ref.watch(providersProvider);
    final proxyProviders = providers
        .where((item) => item.type == 'Proxy')
        .map((item) => ProviderItem(provider: item));
    final ruleProviders = providers
        .where((item) => item.type == 'Rule')
        .map((item) => ProviderItem(provider: item));
    final proxySection = generateSection(
      title: appLocalizations.proxyProviders,
      items: proxyProviders,
    );
    final ruleSection = generateSection(
      title: appLocalizations.ruleProviders,
      items: ruleProviders,
    );
    return AdaptiveSheetScaffold(
      actions: [IconButtonData(icon: Icons.sync, onPressed: _updateProviders)],
      // generateSection 对空列表返回空数组，所以没有提供者时整页会是一片空白，
      // 看起来像没加载出来。给个明确的空状态。
      body: providers.isEmpty
          ? NullStatus(
              label: appLocalizations.nullTip(appLocalizations.providers),
            )
          : generateListView([...proxySection, ...ruleSection]),
      title: appLocalizations.providers,
    );
  }
}

class ProviderItem extends StatelessWidget {
  final ExternalProvider provider;

  const ProviderItem({super.key, required this.provider});

  Future<void> _handleUpdateProvider() async {
    if (provider.vehicleType != 'HTTP') return;
    final ref = globalState.container;
    await globalState.safeRun(() async {
      final message = await ref
          .read(proxiesActionProvider.notifier)
          // showLoading 不传就是 false，于是 isUpdatingProvider 永远为假，
          // 下面那个转圈分支一次都没被走到过——「同步」按钮点下去毫无反应，
          // 而且因为按钮没被换成转圈，可以随便连点，同一个提供者被并发拉多遍。
          .updateProvider(provider, showLoading: true);
      if (message.isNotEmpty) throw message;
    }, silence: false);
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
  }

  Future<void> _handleSideLoadProvider() async {
    final ref = globalState.container;
    await globalState.safeRun<void>(() async {
      final platformFile = await picker.pickerFile();
      if (platformFile == null || provider.path == null) return;
      final bytes = await platformFile.readBytes();
      // Decode and let the core validate before touching the existing file:
      // a rejected or non-UTF-8 pick must not destroy a working provider.
      final data = utf8.decode(bytes);
      final providerName = provider.name;
      final message = await coreController.sideLoadExternalProvider(
        providerName: providerName,
        data: data,
      );
      if (message.isNotEmpty) throw message;
      await File(provider.path!).safeWriteAsBytes(bytes);
      ref
          .read(providersProvider.notifier)
          .setProvider(await coreController.getExternalProvider(provider.name));
    });
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
  }

  String _buildProviderDesc(BuildContext context) {
    final baseInfo = provider.updateAt.getLastUpdateTimeDesc(context);
    final count = provider.count;
    return switch (count == 0) {
      true => baseInfo,
      false => '$baseInfo  ·  ${context.appLocalizations.entriesCount(count)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListItem(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(provider.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (provider.updateAt.microsecondsSinceEpoch > 0)
            Text(_buildProviderDesc(context)),
          const SizedBox(height: 4),
          if (provider.subscriptionInfo != null)
            SubscriptionInfoView(subscriptionInfo: provider.subscriptionInfo),
          const SizedBox(height: 8),
          Wrap(
            runSpacing: 6,
            spacing: 12,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CommonChip(
                avatar: const Icon(Icons.upload),
                label: context.appLocalizations.upload,
                onPressed: _handleSideLoadProvider,
              ),
              if (provider.vehicleType == 'HTTP')
                Consumer(
                  builder: (_, ref, _) {
                    final isUpdating = ref.watch(
                      isUpdatingProvider(provider.updatingKey),
                    );
                    return isUpdating
                        ? const SizedBox(
                            height: 30,
                            width: 30,
                            child: Padding(
                              padding: EdgeInsets.all(2),
                              child: HeroSpinner(),
                            ),
                          )
                        : CommonChip(
                            avatar: const Icon(Icons.sync),
                            label: context.appLocalizations.sync,
                            onPressed: _handleUpdateProvider,
                          );
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
