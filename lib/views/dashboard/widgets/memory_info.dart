import 'dart:async';
import 'dart:io';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/core/controller.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/dashboard_tile.dart';
import 'package:clash_party/views/dashboard/widgets/memory_info_detail.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';

final _memoryStateNotifier = ValueNotifier<num>(0);

class MemoryInfo extends StatefulWidget {
  final Future<num> Function()? memoryReader;

  const MemoryInfo({super.key, @visibleForTesting this.memoryReader});

  @override
  State<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends State<MemoryInfo> with WidgetsBindingObserver {
  Timer? _timer;
  bool _isForeground = false;
  bool _isUpdating = false;
  int _updateGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isForeground) {
        _startUpdating();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isForeground = false;
    _stopUpdating();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final isForeground = state == AppLifecycleState.resumed;
    if (_isForeground == isForeground) {
      return;
    }
    _isForeground = isForeground;
    if (isForeground) {
      _startUpdating();
    } else {
      _stopUpdating();
    }
  }

  void _startUpdating() {
    if (!mounted || !_isForeground || _isUpdating) {
      return;
    }
    _isUpdating = true;
    final generation = ++_updateGeneration;
    unawaited(_updateMemory(generation));
  }

  void _stopUpdating() {
    _isUpdating = false;
    _updateGeneration++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _updateMemory(int generation) async {
    final memoryReader = widget.memoryReader;
    final memory = memoryReader != null
        ? await memoryReader()
        : await _readMemory();
    if (!mounted ||
        !_isForeground ||
        !_isUpdating ||
        generation != _updateGeneration) {
      return;
    }
    _memoryStateNotifier.value = memory;
    _timer = Timer(const Duration(seconds: 2), () {
      _timer = null;
      if (mounted &&
          _isForeground &&
          _isUpdating &&
          generation == _updateGeneration) {
        unawaited(_updateMemory(generation));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return RepaintBoundary(
      child: DashboardTile(
        icon: Icons.memory,
        label: appLocalizations.memoryInfo,
        // 原来点一下是直接、静默地让内核跑一次 GC：没有确认、没有结果，数字要
        // 等下一次两秒采样才可能动，用户看不出自己做了什么。改成打开详情页——
        // 那里把应用 / 内核 / 合计拆开摆着，「释放内存」是页面上一个写着字的
        // 按钮，点完立刻重新采样。
        onTap: () {
          showExtend(context, builder: (_) => const MemoryInfoDetailView());
        },
        // 内存值是这块磁贴的「附加信息」，照桌面端摆在右上角。
        trailing: ValueListenableBuilder(
          valueListenable: _memoryStateNotifier,
          builder: (_, memory, _) {
            // 内存两秒采一次，两次之间常常差出几十兆，直接换数字是一下「闪」。
            // 滚动过去还额外说明了一件事：数字是在**涨**还是在**跌**——点这块卡片
            // 是触发 GC，滚动方向就是「有没有回收到」的直接反馈。
            //
            // 数值和单位同在一个 AnimatedCount 里算，跨 1024 时同帧翻。
            return AnimatedCount(
              value: memory,
              builder: (context, value) {
                final traffic = value.traffic;
                return Text(
                  '${traffic.value} ${traffic.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashboardTileValueStyle(
                    context,
                  )?.copyWith(fontFeatures: tabularFigures),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Future<num> _readMemory() async {
  final rss = ProcessInfo.currentRss;
  final coreConnected =
      globalState.container.read(coreStatusProvider) == CoreStatus.connected;
  if (system.isDesktop && coreConnected) {
    return await coreController.getMemory() + rss;
  }
  return rss;
}
