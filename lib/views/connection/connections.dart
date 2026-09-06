import 'dart:async';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/core/controller.dart';
import 'package:clash_party/core/method.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'item.dart';
import 'stream_motion.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView> {
  final _connectionsStateNotifier = ValueNotifier<TrackerInfosState>(
    const TrackerInfosState(),
  );

  /// 认「这一秒里新冒出来的连接」，只有它们才淡入。
  final _fresh = StreamFreshTracker();

  Timer? timer;

  List<Widget> _buildActions() {
    return [
      IconButton(
        onPressed: () async {
          coreController.closeConnections();
          await _updateConnections();
        },
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
    ];
  }

  void _onSearch(String value) {
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      query: value,
    );
  }

  void _onKeywordsUpdate(List<String> keywords) {
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      keywords: keywords,
    );
  }

  Future<void> _updateConnectionsTask() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _updateConnections();
        timer = Timer(const Duration(seconds: 1), () async {
          _updateConnectionsTask();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _updateConnectionsTask();
  }

  Future<void> _updateConnections() async {
    try {
      final trackerInfos = await coreController.getConnections();
      // dispose() releases the notifier, so a view torn down while the core
      // call was in flight would otherwise write to a disposed one.
      if (!mounted) {
        return;
      }
      // 必须先更新再赋值：赋值会同步触发重建，那时候界面就要问「这条新不新」了。
      _fresh.update(trackerInfos.map((item) => item.id));
      _connectionsStateNotifier.value = _connectionsStateNotifier.value
          .copyWith(trackerInfos: trackerInfos);
    } catch (error) {
      commonPrint.log(
        'updateConnections error: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }

  Future<void> _handleBlockConnection(String id) async {
    await coreController.closeConnection(id);
    await _updateConnections();
  }

  @override
  void dispose() {
    timer?.cancel();
    _connectionsStateNotifier.dispose();
    timer = null;
    super.dispose();
  }

  /// 直接在 itemBuilder 里造条目，不再先 map 出整份列表：这个页面每秒刷新一次，
  /// 预先构造 N 个 Widget 等于每秒白造一遍。
  ///
  /// 原来那份列表还插了分隔线（长度 2n-1）却按 connections.length 取，
  /// **一半的连接根本显示不出来**。现在一条卡片就是一条连接。
  Widget _buildList(BuildContext context, List<TrackerInfo> connections) {
    final appLocalizations = context.appLocalizations;
    // 断开一条中间的连接会让它后面所有条目的下标整体前移。没有这张表，
    // Flutter 只能按下标去配对，配错之后整片条目会被当成「新的」重建：
    // 动画整屏重播是小事，卡片里那个异步取应用图标的 FutureBuilder 也会全部重来。
    final indexById = <String, int>{
      for (var index = 0; index < connections.length; index++)
        connections[index].id: index,
    };
    return SuperListView.builder(
      // 顶部要给悬浮胶囊让位（那段高度由 `MediaQuery.padding.top` 发下来）。
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 8,
        bottom: 8,
      ),
      itemCount: connections.length,
      findChildIndexCallback: (key) {
        final id = key is ValueKey<String> ? key.value : null;
        return id == null ? null : indexById[id];
      },
      itemBuilder: (_, index) {
        final trackerInfo = connections[index];
        return StreamItemEntrance(
          key: Key(trackerInfo.id),
          animate: _fresh.isFresh(trackerInfo.id),
          index: _fresh.isFirstBatch ? index : 0,
          child: TrackerInfoItem(
            trackerInfo: trackerInfo,
            onClickKeyword: (value) {
              context.commonScaffoldState?.addKeyword(value);
            },
            trailing: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(minimumSize: Size.zero),
              // 断开连接是破坏性操作，用 error 色标出来；桌面端那个按钮
              // 也是 danger 色。
              color: context.colorScheme.error,
              icon: const Icon(Icons.close),
              onPressed: () {
                _handleBlockConnection(trackerInfo.id);
              },
            ),
            detailTitle: appLocalizations.details(appLocalizations.connection),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      title: appLocalizations.connections,
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      actions: _buildActions(),
      body: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: _connectionsStateNotifier,
        builder: (context, state, _) {
          final connections = state.list;
          // 没启动时这一页必然是空的，而原来的副标题是「查看当前连接数据」——
          // 那是在解释这一页做什么用，没有回答用户此刻的问题「为什么什么都没有」。
          // 「停着」和「开着但确实没有连接」是两回事，分开说。
          final isStart = ref.watch(isStartProvider);
          return StreamEmptyOverlay(
            isEmpty: connections.isEmpty,
            empty: NullStatus(
              label: appLocalizations.nullTip(appLocalizations.connections),
              description: isStart
                  ? appLocalizations.connectionsDesc
                  : appLocalizations.streamNeedRunningDesc,
              illustration: const ConnectionEmptyIllustration(),
            ),
            child: _buildList(context, connections),
          );
        },
      ),
    );
  }
}
