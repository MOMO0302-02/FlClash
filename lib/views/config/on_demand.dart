import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/plugins/app.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/profiles/overwrite/custom/widgets.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_ssid/wifi_ssid.dart';

class OnDemandView extends ConsumerStatefulWidget {
  const OnDemandView({super.key});

  @override
  ConsumerState createState() => _OnDemandViewState();
}

class _OnDemandViewState extends ConsumerState<OnDemandView>
    with UniqueKeyStateMixin {
  void _handlePermanentlyDeniedLocationPermission() {
    if (system.isMacOS) {
      final appLocalizations = context.appLocalizations;
      globalState.showMessage(
        title: appLocalizations.locationPermissionRequired,
        cancelable: false,
        message: TextSpan(
          style: context.textTheme.bodyMedium,
          text: appLocalizations.locationPermissionGuide(appName),
        ),
      );
    } else if (system.isAndroid) {
      app?.openAppSettings();
    }
  }

  Future<void> _handleRequestLocationPermission() async {
    final appLocalizations = context.appLocalizations;
    final permission = ref.read(locationPermissionsProvider);
    if (permission == WifiSsidPermission.granted) {
      return;
    }
    if (permission == WifiSsidPermission.permanentlyDenied) {
      _handlePermanentlyDeniedLocationPermission();
      return;
    }
    final res = await wifiSsidManager.requestPermission();
    globalState.container.read(locationPermissionsProvider.notifier).value =
        res;
    if (!mounted) {
      return;
    }
    switch (getLocationPermissionFollowUp(res)) {
      case LocationPermissionFollowUp.none:
        return;
      case LocationPermissionFollowUp.openSettings:
        _handlePermanentlyDeniedLocationPermission();
        return;
      case LocationPermissionFollowUp.showDeniedMessage:
        break;
    }
    final needGo = await globalState.showMessage(
      title: appLocalizations.locationPermissionRequired,
      message: TextSpan(text: appLocalizations.locationPermissionDeniedMessage),
      confirmText: appLocalizations.go,
    );
    if (needGo != true) {
      return;
    }
    app?.openAppSettings();
  }

  void _handleOpenBatteryOptimizationSettings() {
    final isDisabled = ref.read(batteryOptimizationDisableProvider);
    if (isDisabled) {
      return;
    }
    permissions.needWaitingBatteryOptimizationSettings = true;
    app?.openBatteryOptimizationSettings();
  }

  Future<void> _handleAddOrUpdate([String? ssid]) async {
    final ssids = ref.read(excludeSSIDsProvider);
    final appLocalizations = context.appLocalizations;
    final newSSID = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: ssid == null
            ? appLocalizations.addSsid
            : appLocalizations.editSsid,
        value: ssid ?? '',
        maxLength: 32,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip('SSID').trim();
          }
          if (ssids.contains(value) && ssid != value) {
            return appLocalizations.existsTip('SSID').trim();
          }
          return null;
        },
      ),
    );
    if (newSSID == null || ssid == newSSID) {
      return;
    }
    globalState.container.read(excludeSSIDsProvider.notifier).update((state) {
      final newSSIDS = state.toSet();
      if (ssid != null) {
        newSSIDS.remove(ssid);
      }
      return [...newSSIDS, newSSID];
    });
  }

  void _handleReorder(int oldIndex, newIndex) {
    globalState.container.read(excludeSSIDsProvider.notifier).update((value) {
      return value.copyAndReorder(oldIndex, newIndex);
    });
  }

  Widget _buildItem({
    required String ssid,
    required int index,
    required int length,
    required bool isSelected,
    required bool isEditing,
  }) {
    final position = ItemPosition.get(index, length);
    return ReorderableDelayedDragStartListener(
      key: ValueKey(ssid),
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ItemPositionProvider(
          position: position,
          child: SelectedDecorationListItem(
            isEditing: isEditing,
            minVerticalPadding: 8,
            title: TooltipText(
              text: Text(ssid, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            isSelected: isSelected,
            onSelected: () {
              ref.read(itemsProvider(key).notifier).update((state) {
                final newState = Set<String>.from(state)..addOrRemove(ssid);
                return newState;
              });
            },
            onPressed: () {
              _handleAddOrUpdate(ssid);
            },
          ),
        ),
      ),
    );
  }

  void _handleSelectAll() {
    final excludeSSIDs = ref.read(excludeSSIDsProvider).toSet();
    ref.read(itemsProvider(key).notifier).update((selected) {
      return selected.containsAll(excludeSSIDs) ? {} : excludeSSIDs;
    });
  }

  void _handleDelete() {
    final selectedItems = ref.read(itemsProvider(key));
    globalState.container.read(excludeSSIDsProvider.notifier).update((
      excludeSSIDs,
    ) {
      return excludeSSIDs
          .where((item) => !selectedItems.contains(item))
          .toList();
    });
    ref.read(itemsProvider(key).notifier).value = {};
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isLoading = ref.watch(
      loadingProvider(LoadingTag.batteryOptimization),
    );
    final batteryOptimizationDisable = ref.watch(
      batteryOptimizationDisableProvider,
    );
    final excludeSSIDs = ref.watch(excludeSSIDsProvider);
    final locationPermissionsGranted = ref.watch(
      locationPermissionsProvider.select(
        (state) => state == WifiSsidPermission.granted,
      ),
    );
    final selectedItems = ref.watch(itemsProvider(key));
    return CommonScaffold(
      body: Builder(
        builder: (context) => CustomScrollView(
          slivers: [
            // 「前置条件」原来走 generateSectionV3——那是每条自己带 24 圆角的
            // DecorationListItem，和设置页别处的分组卡片不是一套。换成
            // generateSection：一张 14 圆角、带高光边和外阴影的卡片。
            SliverToBoxAdapter(
              child: Column(
                children: generateSection(
                  isFirst: true,
                  title: appLocalizations.prerequisites,
                  items: [
                    if (system.isAndroid)
                      ListItem(
                        minVerticalPadding: 8,
                        title: Text(appLocalizations.ignoreBatteryOptimization),
                        subtitle: Text(
                          appLocalizations.batteryOptimizationDesc,
                        ),
                        // 去授权页之前那一下等待，按钮会换成转圈。硬切会让人以为
                        // 按钮消失了，淡入淡出才看得出是「同一个位置在等结果」。
                        // 和资源页、订阅卡片的更新按钮是同一种处理。
                        trailing: FadeThroughBox(
                          alignment: Alignment.centerRight,
                          child: isLoading
                              ? const SizedBox(
                                  key: ValueKey('loading'),
                                  width: 100,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      SizedBox.square(
                                        dimension: 32,
                                        child: HeroSpinner(),
                                      ),
                                    ],
                                  ),
                                )
                              : Row(
                                  key: const ValueKey('actions'),
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 8,
                                  children: [
                                    InfoMessageButton(
                                      message: appLocalizations
                                          .batteryOptimizationStatusTip,
                                    ),
                                    CommonMinFilledButtonTheme(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              batteryOptimizationDisable
                                              ? null
                                              : context.colorScheme.error,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          minimumSize: const Size(80, 40),
                                        ),
                                        onPressed:
                                            _handleOpenBatteryOptimizationSettings,
                                        child: Text(
                                          batteryOptimizationDisable
                                              ? appLocalizations.authorized
                                              : appLocalizations.tapToAuthorize,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    if (system.isAndroid || system.isMacOS)
                      ListItem(
                        minVerticalPadding: 8,
                        title: Text(appLocalizations.locationPermission),
                        subtitle: Text(appLocalizations.locationPermissionDesc),
                        trailing: CommonMinFilledButtonTheme(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: locationPermissionsGranted
                                  ? null
                                  : context.colorScheme.error,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              minimumSize: const Size(80, 40),
                            ),
                            onPressed: _handleRequestLocationPermission,
                            child: Text(
                              locationPermissionsGranted
                                  ? appLocalizations.authorized
                                  : appLocalizations.tapToAuthorize,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // ListHeader 自带 16 的左内边距，外面再包一层 16 会让这个标题比上面
            // 那组的标题多缩进一截。
            SliverToBoxAdapter(
              child: ListHeader(
                title: appLocalizations.excludeSsids,
                // 列表为空时说明文字挪到空状态里去讲，免得同一屏出现两遍。
                subTitle: excludeSSIDs.isEmpty
                    ? null
                    : appLocalizations.excludeSsidsDesc,
                actions: [
                  const SizedBox(width: 8),
                  if (selectedItems.isNotEmpty)
                    CommonMinIconButtonTheme(
                      child: IconButton.filledTonal(
                        onPressed: _handleDelete,
                        icon: const Icon(Icons.delete),
                      ),
                    ),
                  const SizedBox(width: 2),
                  CommonMinFilledButtonTheme(
                    child: selectedItems.isNotEmpty
                        ? FilledButton(
                            onPressed: _handleSelectAll,
                            child: Text(appLocalizations.selectAll),
                          )
                        : FilledButton.tonal(
                            onPressed: _handleAddOrUpdate,
                            child: Text(appLocalizations.add),
                          ),
                  ),
                ],
              ),
            ),
            if (excludeSSIDs.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ).copyWith(top: 12),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 48,
                    ),
                    // 空状态要说清「这是干嘛的」并给出下一步，光写「为空」等于把人
                    // 晾着——上面那个「添加」按钮在标题行里，不一定被注意到。
                    child: NullStatus(
                      label: appLocalizations.ssidsEmpty,
                      description: appLocalizations.excludeSsidsDesc,
                      action: FilledButton.tonal(
                        onPressed: _handleAddOrUpdate,
                        child: Text(appLocalizations.addSsid),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 12),
                sliver: SliverReorderableList(
                  itemBuilder: (_, index) {
                    final ssid = excludeSSIDs[index];
                    return _buildItem(
                      isEditing: selectedItems.isNotEmpty,
                      ssid: ssid,
                      index: index,
                      isSelected: selectedItems.contains(ssid),
                      length: excludeSSIDs.length,
                    );
                  },
                  proxyDecorator: (child, index, animation) {
                    final ssid = excludeSSIDs[index];
                    return commonProxyDecorator(
                      _buildItem(
                        isEditing: selectedItems.isNotEmpty,
                        ssid: ssid,
                        index: index,
                        isSelected: selectedItems.contains(ssid),
                        length: excludeSSIDs.length,
                      ),
                      index,
                      animation,
                    );
                  },
                  itemCount: excludeSSIDs.length,
                  onReorderItem: _handleReorder,
                ),
              ),
          ],
        ),
      ),
      title: appLocalizations.onDemand,
    );
  }
}
