import 'dart:async';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/plugins/app.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccessView extends ConsumerStatefulWidget {
  const AccessView({super.key});

  @override
  ConsumerState<AccessView> createState() => _AccessViewState();
}

class _AccessViewState extends ConsumerState<AccessView> {
  final GlobalKey<CommonScaffoldState> _scaffoldKey = GlobalKey();
  List<String>? _pinedList;
  bool _isInit = false;
  AccessControlMode? _lastMode;

  final _completer = Completer();

  @override
  void initState() {
    super.initState();
    _completer.complete(ref.read(systemActionProvider.notifier).getPackages());
    final accessControl = ref
        .read(vpnSettingProvider.select((state) => state.accessControlProps))
        .copyWith();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accessControlStateProvider.notifier).value = accessControl;
      _isInit = true;
    });
  }

  Widget _buildSelectedAllButton({
    required bool isSelectedAll,
    required List<String> allValueList,
  }) {
    void onPressed() {
      ref.read(accessControlStateProvider.notifier).update((state) {
        final newSet = Set<String>.from(state.currentList);
        final isSelectedAll = newSet.containsAll(allValueList);
        if (isSelectedAll) {
          newSet.removeAll(allValueList);
        } else {
          newSet.addAll(allValueList);
        }
        return state.copyWithNewList(newSet.toList());
      });
    }

    final appLocalizations = context.appLocalizations;
    return FadeRotationScaleBox(
      alignment: Alignment.centerRight,
      child: isSelectedAll
          ? FloatingActionButton.extended(
              key: const ValueKey(true),
              onPressed: onPressed,
              label: Text(appLocalizations.cancelSelectAll),
              icon: const Icon(Icons.deselect),
            )
          : FloatingActionButton.extended(
              key: const ValueKey(false),
              tooltip: appLocalizations.selectAll,
              onPressed: onPressed,
              label: Text(appLocalizations.selectAll),
              icon: const Icon(Icons.select_all),
            ),
    );
  }

  Future<void> _intelligentSelected() async {
    final packageNames = ref.read(
      packagesProvider.select((state) => state.map((item) => item.packageName)),
    );
    if (packageNames.isEmpty) {
      return;
    }
    final selectedPackageNames =
        (await globalState.loadingRun<List<String>>(() async {
          return await app?.getChinaPackageNames() ?? [];
        }, tag: LoadingTag.access))?.toSet() ??
        {};
    final acceptList = packageNames
        .where((item) => !selectedPackageNames.contains(item))
        .toList();
    final rejectList = packageNames
        .where((item) => selectedPackageNames.contains(item))
        .toList();
    ref
        .read(accessControlStateProvider.notifier)
        .update(
          (state) =>
              state.copyWith(acceptList: acceptList, rejectList: rejectList),
        );
  }

  Future<void> _handleToSetting() async {
    await showSheet<int>(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (context) {
        final appLocalizations = context.appLocalizations;
        return AdaptiveSheetScaffold(
          body: const AccessControlPanel(),
          title: appLocalizations.accessControlSettings,
        );
      },
    );
  }

  void _handleSelected(String packageName) {
    ref.read(accessControlStateProvider.notifier).update((state) {
      final newSet = Set<String>.from(state.currentList)
        ..addOrRemove(packageName);
      return state.copyWithNewList(newSet.toList());
    });
  }

  void _handleToggle() {
    ref.read(accessControlStateProvider.notifier).update((state) {
      return state.copyWith(enable: !state.enable);
    });
  }

  void _handleSearch() {
    _scaffoldKey.currentState?.handleToSearch();
  }

  Future<void> _handleBack() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.saveChanges),
    );
    if (res == true) {
      _handleSave();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  AccessControlProps _getRealAccessControlProps(
    AccessControlProps accessControl,
  ) {
    final packages = ref.read(packagesProvider);
    if (packages.isEmpty) {
      return accessControl;
    }
    final viewPackageNames = packages
        .getViewList(
          pinedList: [],
          sortType: accessControl.sort,
          isFilterSystemApp: accessControl.isFilterSystemApp,
          isFilterNonInternetApp: accessControl.isFilterNonInternetApp,
        )
        .map((item) => item.packageName)
        .toSet();
    return accessControl.copyWithNewList(
      accessControl.currentList
          .where((item) => viewPackageNames.contains(item))
          .toList()
        ..sort(),
    );
  }

  void _handleSave() {
    final accessControl = ref.read(accessControlStateProvider);
    ref
        .read(vpnSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            accessControlProps: _getRealAccessControlProps(accessControl),
          ),
        );
  }

  Widget _buildConfirm() {
    return Consumer(
      builder: (_, ref, child) {
        final accessControl = ref.watch(accessControlStateProvider);
        final noSave = ref.watch(
          vpnSettingProvider.select((state) {
            final current = _getRealAccessControlProps(
              state.accessControlProps,
            );
            final origin = _getRealAccessControlProps(accessControl);
            return current == origin;
          }),
        );
        if (noSave) {
          return const SizedBox();
        }
        return child!;
      },
      child: CommonPopScope(
        onPop: (_) {
          _handleBack();
          return false;
        },
        child: CommonMinFilledButtonTheme(
          child: FilledButton.tonal(
            onPressed: _handleSave,
            child: Text(context.appLocalizations.save),
          ),
        ),
      ),
    );
  }

  Future<void> _exportToClipboard() async {
    await globalState.safeRun(() {
      final currentList = ref.read(
        accessControlStateProvider.select((state) => state.currentList),
      );
      Clipboard.setData(ClipboardData(text: currentList.join('\n')));
    });
  }

  Future<void> _importFormClipboard() async {
    await globalState.safeRun(() async {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text;
      if (text == null) return;
      final list = text
          .split(RegExp(r'\r?\n'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty);
      ref
          .read(accessControlStateProvider.notifier)
          .update((state) => state.copyWithNewList(list.toSet().toList()));
    });
  }

  List<Widget> _buildActions(BuildContext context, {required bool enable}) {
    final appLocalizations = context.appLocalizations;
    return [
      _buildConfirm(),
      CommonPopupBox(
        targetBuilder: (open) {
          return IconButton(
            onPressed: () {
              open(offset: const Offset(0, 0));
            },
            icon: const Icon(Icons.more_vert),
          );
        },
        popup: CommonPopupMenu(
          items: [
            PopupMenuItemData(
              icon: Icons.swap_horiz,
              label: enable
                  ? appLocalizations.turnOff
                  : appLocalizations.turnOn,
              onPressed: _handleToggle,
            ),
            PopupMenuItemData(
              icon: Icons.search,
              label: appLocalizations.search,
              onPressed: _handleSearch,
            ),
            PopupMenuItemData(
              icon: Icons.tune,
              label: appLocalizations.settings,
              onPressed: _handleToSetting,
            ),
            PopupMenuItemData(
              icon: Icons.emergency_outlined,
              label: appLocalizations.action,
              subItems: [
                PopupMenuItemData(
                  icon: Icons.auto_awesome,
                  label: appLocalizations.intelligentSelected,
                  onPressed: _intelligentSelected,
                ),
                PopupMenuItemData(
                  icon: Icons.content_copy,
                  label: appLocalizations.clipboardExport,
                  onPressed: _exportToClipboard,
                ),
                PopupMenuItemData(
                  icon: Icons.paste,
                  label: appLocalizations.clipboardImport,
                  onPressed: _importFormClipboard,
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildContent({
    required List<Package> packages,
    required List<String> valueList,
  }) {
    return FutureBuilder(
      future: _completer.future,
      builder: (context, snapshot) {
        final appLocalizations = context.appLocalizations;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: HeroSpinner());
        }
        return packages.isEmpty
            ? NullStatus(label: appLocalizations.noData)
            : CommonScrollBar(
                child: ListView.builder(
                  itemCount: packages.length,
                  itemExtent: 72,
                  itemBuilder: (_, index) {
                    final package = packages[index];
                    return PackageListItem(
                      key: Key(package.packageName),
                      package: package,
                      value: valueList.contains(package.packageName),
                      onChanged: (value) {
                        _handleSelected(package.packageName);
                      },
                    );
                  },
                ),
              );
      },
    );
  }

  /// 顶部的说明 + 已选计数。
  ///
  /// 原来是 Material 的 `MaterialBanner` 加一块实心蓝的 `Card.filled`——桌面端
  /// 没有 banner 这种控件，计数也是**空心蓝边框的胶囊**而不是实心块。
  Widget _buildBannerBar(
    AccessControlMode mode,
    int count, {
    required bool enable,
  }) {
    final appLocalizations = context.appLocalizations;
    final accent = context.styleTokens.accent(context.colorScheme);
    // 没开启时把说明换成「现在还不生效」，而不是把整页涂灰。
    final describe = !enable
        ? appLocalizations.accessControlNotEnabledDesc
        : mode == AccessControlMode.acceptSelected
        ? appLocalizations.accessControlAllowDesc
        : appLocalizations.accessControlNotAllowDesc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              describe,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: accent, width: 1),
              borderRadius: BorderRadius.circular(999),
            ),
            // 「全选 / 取消全选」会把这个数从 0 跳到几百，直接换数字只是闪一下，
            // 滚过去才看得出「刚才那一下把整份名单都选上了」。逐个勾选时变化只有
            // 1，滚动几乎察觉不到，不会变成干扰。
            child: AnimatedCount(
              value: count,
              builder: (_, value) => Text(
                '${appLocalizations.selected} ${value.round()}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSearch(String value) {
    ref.read(queryProvider(QueryTag.access).notifier).value = value;
    _pinedList = null;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(loadingProvider(LoadingTag.access));
    final lowQuery = ref.watch(queryProvider(QueryTag.access)).toLowerCase();
    final packages = ref.watch(packagesProvider);
    final accessControl = ref.watch(accessControlStateProvider);
    if (_isInit) {
      if (_lastMode != accessControl.mode) {
        _lastMode = accessControl.mode;
        _pinedList = accessControl.currentList;
      } else {
        _pinedList ??= accessControl.currentList;
      }
    }
    final viewPackages = packages
        .getViewList(
          pinedList: _pinedList ?? [],
          sortType: accessControl.sort,
          isFilterNonInternetApp: accessControl.isFilterNonInternetApp,
          isFilterSystemApp: accessControl.isFilterSystemApp,
        )
        .where(
          (package) =>
              package.label.toLowerCase().contains(lowQuery) ||
              package.packageName.toLowerCase().contains(lowQuery),
        )
        .toList();
    final mode = accessControl.mode;
    final currentList = accessControl.currentList;
    final viewPackageNameList = viewPackages.map((e) => e.packageName).toList();
    final valueList = currentList.intersection(viewPackageNameList);
    return CommonScaffold(
      key: _scaffoldKey,
      isLoading: isLoading,
      searchState: AppBarSearchState(onSearch: _onSearch, autoAddSearch: false),
      title: context.appLocalizations.appAccessControl,
      actions: _buildActions(context, enable: accessControl.enable),
      // 不再整片变灰。原来套的 DisabledMask 只加一层灰色滤镜、**不拦触摸**——
      // 看着是禁用的，实际照样勾得动，读屏软件也读不出禁用。而「访问控制还没开、
      // 先把名单配好」本来就是常见用法，真禁掉反而挡路。改成用一行字说明
      // 「现在还不生效」，比装作禁用诚实。
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBannerBar(mode, valueList.length, enable: accessControl.enable),
          const SizedBox(height: 8),
          Expanded(
            child: _buildContent(packages: viewPackages, valueList: valueList),
          ),
        ],
      ),
      floatingActionButton: _buildSelectedAllButton(
        isSelectedAll: valueList.length == viewPackageNameList.length,
        allValueList: viewPackageNameList,
      ),
    );
  }
}

class PackageListItem extends StatelessWidget {
  final Package package;
  final bool value;
  final void Function(bool?) onChanged;

  const PackageListItem({
    super.key,
    required this.package,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListItem.checkbox(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: FutureBuilder<ImageProvider?>(
          future: app?.getPackageIcon(package.packageName),
          builder: (_, snapshot) {
            if (!snapshot.hasData && snapshot.data == null) {
              return Container();
            } else {
              return Image(
                image: snapshot.data!,
                gaplessPlayback: true,
                width: 48,
                height: 48,
              );
            }
          },
        ),
      ),
      title: Text(
        package.label,
        style: const TextStyle(overflow: TextOverflow.ellipsis),
        maxLines: 1,
      ),
      subtitle: Text(
        package.packageName,
        style: const TextStyle(overflow: TextOverflow.ellipsis),
        maxLines: 1,
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class AccessControlPanel extends ConsumerStatefulWidget {
  const AccessControlPanel({super.key});

  @override
  ConsumerState createState() => _AccessControlPanelState();
}

/// 单选组里那个「选中的一条右边一个主色对勾」。
///
/// 选中是用户点出来的，所以对勾淡入并从 0.7 放大到 1，而不是凭空出现。时长取
/// [Motion.quick]：再长一点，连点两下换选项时会看到两个勾同时挂在屏幕上。
///
/// 同样的写法在 `views/profiles/overwrite/overwrite.dart` 里也有一份。真正该放
/// 的地方是 `widgets/list.dart` 的 `ListItem.radio`（它同样是硬切），但那是共享
/// 文件，本轮不动。
class _OptionCheckIcon extends StatelessWidget {
  const _OptionCheckIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1.0 : 0.0),
      duration: Motion.quick,
      curve: Motion.enter,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
      ),
      child: Icon(
        Icons.check,
        size: 20,
        color: context.styleTokens.accent(context.colorScheme),
      ),
    );
  }
}

/// 单选行左边的图标：选中时转主色。
///
/// 和对勾共用同一个时长，两处才像「同一件事的两个表现」；分开写会一个先到一个
/// 后到，看着像没对齐。
class _OptionLeadingIcon extends StatelessWidget {
  const _OptionLeadingIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final accent = context.styleTokens.accent(colorScheme);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1.0 : 0.0),
      duration: Motion.quick,
      curve: Motion.move,
      builder: (_, t, _) => Icon(
        icon,
        size: 20,
        color: Color.lerp(colorScheme.onSurface, accent, t),
      ),
    );
  }
}

class _AccessControlPanelState extends ConsumerState<AccessControlPanel> {
  IconData _getIconWithAccessControlMode(AccessControlMode mode) {
    return switch (mode) {
      AccessControlMode.acceptSelected => Icons.adjust_outlined,
      AccessControlMode.rejectSelected => Icons.block_outlined,
    };
  }

  String _getTextWithAccessControlMode(AccessControlMode mode) {
    final appLocalizations = context.appLocalizations;
    return switch (mode) {
      AccessControlMode.acceptSelected => appLocalizations.whitelistMode,
      AccessControlMode.rejectSelected => appLocalizations.blacklistMode,
    };
  }

  String _getTextWithAccessSortType(AccessSortType type) {
    final appLocalizations = context.appLocalizations;
    return switch (type) {
      AccessSortType.none => appLocalizations.defaultText,
      AccessSortType.name => appLocalizations.name,
      AccessSortType.time => appLocalizations.time,
    };
  }

  IconData _getIconWithProxiesSortType(AccessSortType type) {
    return switch (type) {
      AccessSortType.none => Icons.sort,
      AccessSortType.name => Icons.sort_by_alpha,
      AccessSortType.time => Icons.timeline,
    };
  }

  /// 一组单选：每行左边图标、中间名称，选中的那条右边一个主色对勾。
  ///
  /// 原来三组都是「一排横向滚动的胶囊按钮」，那是 Material 的做法，桌面端根本
  /// 没有这种控件；而且选项一多就得横滑，看不出哪些是一组的。写法照抄
  /// `views/proxies/setting.dart` 的 `_optionSection`，两处保持一致。
  List<Widget> _optionSection<T>({
    required String title,
    required List<T> values,
    required T current,
    required IconData Function(T value) iconOf,
    required String Function(T value) labelOf,
    required void Function(T value) onSelected,
    bool isFirst = false,
  }) {
    return generateSection(
      title: title,
      isFirst: isFirst,
      items: [
        for (final value in values)
          ListItem(
            leading: _OptionLeadingIcon(
              icon: iconOf(value),
              selected: value == current,
            ),
            title: Text(labelOf(value)),
            // 对勾**始终占位**，只是没选中时透明。做成 null / Icon 的二选一会让
            // 选中的瞬间标题被挤窄一下，在一组里换选项时整列文字跟着抖。
            trailing: _OptionCheckIcon(selected: value == current),
            onTap: () => onSelected(value),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final props = ref.watch(accessControlStateProvider);
    final notifier = ref.read(accessControlStateProvider.notifier);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._optionSection<AccessControlMode>(
              isFirst: true,
              title: appLocalizations.mode,
              values: AccessControlMode.values,
              current: props.mode,
              iconOf: _getIconWithAccessControlMode,
              labelOf: _getTextWithAccessControlMode,
              onSelected: (value) =>
                  notifier.update((state) => state.copyWith(mode: value)),
            ),
            ..._optionSection<AccessSortType>(
              title: appLocalizations.sort,
              values: AccessSortType.values,
              current: props.sort,
              iconOf: _getIconWithProxiesSortType,
              labelOf: _getTextWithAccessSortType,
              onSelected: (value) =>
                  notifier.update((state) => state.copyWith(sort: value)),
            ),
            // 「来源」这两项互不相关（要不要显示系统应用 / 无网络应用），本来就
            // 不是单选，做成开关行比「选中/未选中的胶囊」更说得清是什么意思。
            ...generateSection(
              title: appLocalizations.source,
              items: [
                ListItem.toggle(
                  leading: const Icon(Icons.android, size: 20),
                  title: Text(appLocalizations.systemApp),
                  value: !props.isFilterSystemApp,
                  onChanged: (value) => notifier.update(
                    (state) => state.copyWith(isFilterSystemApp: !value),
                  ),
                ),
                ListItem.toggle(
                  leading: const Icon(Icons.wifi_off, size: 20),
                  title: Text(appLocalizations.noNetworkApp),
                  value: !props.isFilterNonInternetApp,
                  onChanged: (value) => notifier.update(
                    (state) => state.copyWith(isFilterNonInternetApp: !value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
