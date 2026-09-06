import 'dart:async';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/core/controller.dart';
import 'package:clash_party/core/method.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/metric_row.dart';
import 'package:clash_party/views/dashboard/widgets/network_speed_detail.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 按 [keyOf] 把连接归并起来，按累计字节数从大到小排，最多留 [limit] 条。
///
/// 归并是重点：同一个主机、同一条代理链上往往同时挂着十几条连接，一条一行的话
/// 排行会被同一个名字刷屏，看不出谁真的占得多。
List<MapEntry<String, num>> rankConnections(
  List<TrackerInfo> connections,
  String Function(TrackerInfo) keyOf, {
  int limit = 8,
}) {
  final totals = <String, num>{};
  for (final connection in connections) {
    final key = keyOf(connection);
    if (key.isEmpty) {
      continue;
    }
    totals[key] = (totals[key] ?? 0) + connection.upload + connection.download;
  }
  final entries = totals.entries.where((entry) => entry.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(limit).toList();
}

/// 流量统计磁贴的详情页。
///
/// 磁贴原来点进去是**连接列表**，和「连接」磁贴、「网速」磁贴撞在同一个页面上。
/// 可磁贴上画的是累计上下行的环形图，点进来该回答的是「这些流量是谁用掉的」：
/// 总量、已连接时长、平均速率，以及按目标主机和按出口节点两个维度的排行。
///
/// 排行只能覆盖**当前还活着的连接**——内核不保留已关闭连接的账本，桌面端那份
/// 按天统计是渲染层自己写数据库攒出来的，手机端没有这个库。所以分组标题旁挂了
/// 一个说明按钮，别让人以为这就是全量账单。
class TrafficUsageDetailView extends ConsumerStatefulWidget {
  const TrafficUsageDetailView({
    super.key,
    @visibleForTesting this.connectionsReader,
  });

  final ConnectionsReader? connectionsReader;

  @override
  ConsumerState<TrafficUsageDetailView> createState() =>
      _TrafficUsageDetailViewState();
}

class _TrafficUsageDetailViewState
    extends ConsumerState<TrafficUsageDetailView> {
  static const _rankLimit = 8;

  List<TrackerInfo> _connections = const [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Future<void> _refresh() async {
    final reader = widget.connectionsReader;
    // 内核没连上时不要去问它要连接：这时本来就一条都没有，而在桌面端这一问会
    // 白白发起一次 IPC 连接尝试（连不上得等十秒超时）。
    final connected = ref.read(coreStatusProvider) == CoreStatus.connected;
    if (reader != null || connected) {
      try {
        final connections = await (reader ?? coreController.getConnections)();
        if (!mounted) {
          return;
        }
        setState(() {
          _connections = connections;
        });
      } catch (error) {
        commonPrint.log(
          'traffic detail connections error: $error',
          logLevel: coreFailureLogLevel(error),
        );
      }
    }
    if (!mounted) {
      return;
    }
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        unawaited(_refresh());
      }
    });
  }

  List<Widget> _rankItems(
    IconData icon,
    List<MapEntry<String, num>> entries,
    String emptyLabel,
  ) {
    if (entries.isEmpty) {
      return [
        MetricRow(
          icon: icon,
          label: emptyLabel,
          value: context.appLocalizations.none,
        ),
      ];
    }
    return [
      for (final entry in entries)
        MetricRow(
          icon: icon,
          label: entry.key,
          value: entry.value.traffic.show,
        ),
    ];
  }

  void _showRankTip() {
    final appLocalizations = context.appLocalizations;
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.trafficRankTip),
      cancelable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final total = ref.watch(totalTrafficProvider);
    final runTime = ref.watch(runTimeProvider);
    final sum = total.up + total.down;
    // 平均速率按已连接时长摊：没连着的时候摊出来是无穷大，所以直接显示 0。
    final seconds = (runTime ?? 0) / 1000;
    final average = seconds > 0 ? sum / seconds : 0;

    final tipAction = IconButton(
      padding: EdgeInsets.zero,
      onPressed: _showRankTip,
      icon: Icon(
        size: 16.ap,
        Icons.info_outline,
        color: context.colorScheme.onSurfaceVariant,
      ),
    );

    return CommonScaffold(
      title: appLocalizations.trafficUsage,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ...generateSection(
            title: appLocalizations.trafficUsage,
            isFirst: true,
            items: [
              MetricRow(
                icon: Icons.arrow_upward,
                label: appLocalizations.upload,
                value: total.up.traffic.show,
              ),
              MetricRow(
                icon: Icons.arrow_downward,
                label: appLocalizations.download,
                value: total.down.traffic.show,
              ),
              MetricRow(
                icon: Icons.functions,
                label: appLocalizations.total,
                value: sum.traffic.show,
              ),
              MetricRow(
                icon: Icons.schedule,
                label: appLocalizations.duration,
                value: utils.getTimeText(runTime),
              ),
              MetricRow(
                icon: Icons.speed_sharp,
                label: appLocalizations.averageSpeed,
                value: '${average.traffic.show}/s',
              ),
            ],
          ),
          ...generateSection(
            title: appLocalizations.host,
            actions: [tipAction],
            items: _rankItems(
              Icons.language,
              rankConnections(
                _connections,
                (connection) => connection.metadata.host.isNotEmpty
                    ? connection.metadata.host
                    : connection.metadata.destinationIP,
                limit: _rankLimit,
              ),
              appLocalizations.host,
            ),
          ),
          ...generateSection(
            title: appLocalizations.proxies,
            actions: [tipAction],
            items: _rankItems(
              Icons.workspaces,
              rankConnections(
                _connections,
                (connection) =>
                    connection.chains.isEmpty ? '' : connection.chains.first,
                limit: _rankLimit,
              ),
              appLocalizations.proxies,
            ),
          ),
        ],
      ),
    );
  }
}
