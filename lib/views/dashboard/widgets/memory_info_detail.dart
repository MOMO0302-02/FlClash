import 'dart:async';
import 'dart:io';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/core/controller.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/views/dashboard/widgets/metric_row.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一次内存采样：应用自己占了多少、内核占了多少。
class MemoryUsage {
  const MemoryUsage({this.app = 0, this.core});

  final num app;

  /// 内核内存。只有桌面端且内核已连接时才拿得到，其余情况为空。
  final num? core;

  num get total => app + (core ?? 0);
}

typedef MemoryUsageReader = Future<MemoryUsage> Function();

/// 内存磁贴的详情页。
///
/// 磁贴上原来点一下是**静默**触发一次内核 GC：按下去有水波纹，然后什么都不发生，
/// 数字要等两秒后的下一次采样才可能变——用户根本看不出自己做了什么，也不知道
/// 那一大坨内存到底是谁占的。这一页把采样拆开摆明（应用 / 内核 / 合计），并把
/// 「释放内存」变成一个写着字的按钮，点完立刻重新采一次。
class MemoryInfoDetailView extends ConsumerStatefulWidget {
  const MemoryInfoDetailView({
    super.key,
    @visibleForTesting this.usageReader,
    @visibleForTesting this.gcRequester,
  });

  final MemoryUsageReader? usageReader;
  final Future<void> Function()? gcRequester;

  @override
  ConsumerState<MemoryInfoDetailView> createState() =>
      _MemoryInfoDetailViewState();
}

class _MemoryInfoDetailViewState extends ConsumerState<MemoryInfoDetailView> {
  MemoryUsage _usage = const MemoryUsage();
  Timer? _timer;
  bool _releasing = false;

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

  Future<MemoryUsage> _read() async {
    final reader = widget.usageReader;
    if (reader != null) {
      return reader();
    }
    final app = ProcessInfo.currentRss;
    final connected = ref.read(coreStatusProvider) == CoreStatus.connected;
    if (system.isDesktop && connected) {
      return MemoryUsage(app: app, core: await coreController.getMemory());
    }
    return MemoryUsage(app: app);
  }

  Future<void> _refresh() async {
    final usage = await _read();
    if (!mounted) {
      return;
    }
    setState(() {
      _usage = usage;
    });
    // 采样自己重排下一次，不用周期定时器：读内核内存是一次跨进程调用，读得慢时
    // 周期定时器会把请求叠起来。
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        unawaited(_refresh());
      }
    });
  }

  Future<void> _handleRelease() async {
    if (_releasing) {
      return;
    }
    setState(() {
      _releasing = true;
    });
    try {
      await (widget.gcRequester ?? coreController.requestGc)();
    } finally {
      if (mounted) {
        setState(() {
          _releasing = false;
        });
        // GC 是异步的，立刻再采一次才有「按下去有反应」的反馈。
        await _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final coreStatus = ref.watch(coreStatusProvider);
    return CommonScaffold(
      title: appLocalizations.details(appLocalizations.memoryInfo),
      actions: [
        IconButton(
          tooltip: appLocalizations.update,
          onPressed: () {
            unawaited(_refresh());
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ...generateSection(
            title: appLocalizations.memoryInfo,
            isFirst: true,
            items: [
              MetricRow(
                icon: Icons.phone_android,
                label: appLocalizations.app,
                value: _usage.app.traffic.show,
              ),
              if (_usage.core != null)
                MetricRow(
                  icon: Icons.memory,
                  label: appLocalizations.core,
                  value: _usage.core!.traffic.show,
                ),
              MetricRow(
                icon: Icons.functions,
                label: appLocalizations.total,
                value: _usage.total.traffic.show,
              ),
            ],
          ),
          ...generateSection(
            title: appLocalizations.core,
            items: [
              MetricRow(
                icon: Icons.bolt,
                label: appLocalizations.coreStatus,
                value: switch (coreStatus) {
                  CoreStatus.connected => appLocalizations.connected,
                  CoreStatus.connecting => appLocalizations.connecting,
                  CoreStatus.disconnected => appLocalizations.disconnected,
                },
              ),
              ListItem(
                leading: _releasing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: HeroSpinner(),
                        ),
                      )
                    : const Icon(Icons.cleaning_services),
                title: Text(appLocalizations.releaseMemory),
                subtitle: Text(appLocalizations.releaseMemoryDesc),
                onTap: _releasing ? null : _handleRelease,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
