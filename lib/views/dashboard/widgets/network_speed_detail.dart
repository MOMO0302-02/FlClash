import 'dart:async';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/core/controller.dart';
import 'package:clash_party/core/method.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/metric_row.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ConnectionsReader = Future<List<TrackerInfo>> Function();

/// 网速磁贴的详情页。
///
/// 磁贴原来点进去是**连接列表**——可首页上「连接」磁贴点进去也是同一个列表，
/// 两块完全不同的磁贴通向同一个地方。网速磁贴上是一条总速率曲线，点进来该看到的
/// 是「这个速率是怎么来的」：上下行分开的曲线、当前/平均/峰值三个数，以及此刻
/// 到底是谁在跑流量（按实时速率排的连接）。
class NetworkSpeedDetailView extends ConsumerStatefulWidget {
  const NetworkSpeedDetailView({
    super.key,
    @visibleForTesting this.connectionsReader,
  });

  final ConnectionsReader? connectionsReader;

  @override
  ConsumerState<NetworkSpeedDetailView> createState() =>
      _NetworkSpeedDetailViewState();
}

class _NetworkSpeedDetailViewState
    extends ConsumerState<NetworkSpeedDetailView> {
  /// 排行里最多列几条。列表本身在「连接」页，这里只回答「谁最占带宽」。
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
          'speed detail connections error: $error',
          logLevel: coreFailureLogLevel(error),
        );
      }
    }
    if (!mounted) {
      return;
    }
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        unawaited(_refresh());
      }
    });
  }

  /// 把一串流量样本转成折线的点。取 [value] 决定画的是上行还是下行。
  List<Point> _points(List<Traffic> traffics, num Function(Traffic) value) {
    return [
      const Point(0, 0),
      const Point(1, 0),
      for (final (index, traffic) in traffics.indexed)
        Point((index + 2).toDouble(), value(traffic).toDouble()),
    ];
  }

  List<TrackerInfo> get _ranked {
    final active = _connections
        .where(
          (item) => (item.uploadSpeed ?? 0) + (item.downloadSpeed ?? 0) > 0,
        )
        .toList();
    active.sort((a, b) {
      final speedA = (a.uploadSpeed ?? 0) + (a.downloadSpeed ?? 0);
      final speedB = (b.uploadSpeed ?? 0) + (b.downloadSpeed ?? 0);
      return speedB.compareTo(speedA);
    });
    return active.take(_rankLimit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final traffics = ref.watch(trafficsProvider).list;
    final last = traffics.isEmpty ? const Traffic() : traffics.last;
    final speeds = traffics.map((item) => item.speed);
    final peak = speeds.isEmpty ? 0 : speeds.reduce((a, b) => a > b ? a : b);
    final average = speeds.isEmpty
        ? 0
        : speeds.reduce((a, b) => a + b) / speeds.length;
    final ranked = _ranked;

    return CommonScaffold(
      title: appLocalizations.speedStatistics,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: CommonCard(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChartRow(
                      label: appLocalizations.upload,
                      value: '${last.up.traffic.show}/s',
                      color: globalState.theme.darken3PrimaryContainer,
                      points: _points(traffics, (item) => item.up),
                    ),
                    const SizedBox(height: 12),
                    _ChartRow(
                      label: appLocalizations.download,
                      value: '${last.down.traffic.show}/s',
                      color: globalState.theme.darken2SecondaryContainer,
                      points: _points(traffics, (item) => item.down),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ...generateSection(
            title: appLocalizations.networkSpeed,
            items: [
              MetricRow(
                icon: Icons.speed_sharp,
                label: appLocalizations.averageSpeed,
                value: '${average.traffic.show}/s',
              ),
              MetricRow(
                icon: Icons.trending_up,
                label: appLocalizations.peakSpeed,
                value: '${peak.traffic.show}/s',
              ),
            ],
          ),
          ...generateSection(
            title: appLocalizations.connections,
            items: ranked.isEmpty
                ? [
                    MetricRow(
                      icon: Icons.swap_horiz,
                      label: appLocalizations.connections,
                      value: appLocalizations.none,
                    ),
                  ]
                : [
                    for (final item in ranked)
                      MetricRow(
                        icon: Icons.swap_horiz,
                        label: item.metadata.host.isNotEmpty
                            ? item.metadata.host
                            : item.metadata.destinationIP,
                        subtitle: item.chains.isEmpty
                            ? null
                            : item.chains.first,
                        value:
                            '↑ ${(item.uploadSpeed ?? 0).traffic.show}/s  '
                            '↓ ${(item.downloadSpeed ?? 0).traffic.show}/s',
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

/// 一条带标题和当前值的折线。
class _ChartRow extends StatelessWidget {
  const _ChartRow({
    required this.label,
    required this.value,
    required this.color,
    required this.points,
  });

  final String label;
  final String value;
  final Color color;
  final List<Point> points;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: context.textTheme.labelLarge),
            Text(
              value,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 72,
          child: LineChart(
            gradient: true,
            // **时长取采样间隔，不用 Motion.normal（260 毫秒）。** 260 毫秒跑完
            // 之后要干等 740 毫秒才跳下一段，看上去是"抖一下停一下"；等于间隔
            // 才是一段接一段的连续流动，和首页那条一致。
            duration: kTrafficSampleInterval,
            color: color,
            points: points,
          ),
        ),
      ],
    );
  }
}
