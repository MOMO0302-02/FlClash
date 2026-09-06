import 'package:clash_party/common/common.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/dashboard_tile.dart';
import 'package:clash_party/views/dashboard/widgets/network_speed_detail.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrafficUsage extends StatelessWidget {
  const TrafficUsage({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final primaryColor = globalState.theme.darken3PrimaryContainer;
    final secondaryColor = globalState.theme.darken2SecondaryContainer;
    return RepaintBoundary(
      child: DashboardTile(
        rows: 2,
        icon: Icons.data_saver_off,
        label: appLocalizations.trafficUsage,
        // 点进去是**速率详情**（上下行曲线、当前/平均/峰值、按速率排的连接
        // 排行）。这个入口原来挂在状态总览那块卡片上，按用户要求移到这里——
        // 流量这件事集中在一处，状态总览回归「点一下启停」的单一职责。
        onTap: () {
          showExtend(context, builder: (_) => const NetworkSpeedDetailView());
        },
        // 图例（「上传 / 下载」两行色块加文字）和累计流量无关，却原本长在
        // Consumer 里，于是跟着每秒重建一次。它内部那个 LayoutBuilder 每次
        // 都要新造两个 Text 再调两次 measure.computeTextSize —— 那是**没有
        // 缓存**的 TextPainter.layout()。用 Consumer 的 child 参数把它抬出去：
        // 只建一次，之后每秒重建的只剩真正跟着数据变的环形图和两行数字。
        body: Consumer(
          builder: (_, ref, _) {
            // 实时速率：每秒都在变，是这块磁贴的主角。
            final traffic = ref.watch(
              trafficsProvider.select(
                (state) => state.length == 0
                    ? const Traffic()
                    : state[state.length - 1],
              ),
            );
            // 累计用量：回头才查，做配角。
            final total = ref.watch(totalTrafficProvider);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 上层：实时速率，大字。
                //
                // 之前这块磁贴是「环形图 + 上行 + 下行」三样平铺，谁也不比谁
                // 重要——用户两次说它「太满」。现在分主次：每秒在看的实时速率
                // 放大，回头才查的累计缩小，同样的空间反而显得空。
                _SpeedRow(
                  key: const ValueKey('rate-up'),
                  icon: Icons.arrow_upward,
                  color: primaryColor,
                  value: traffic.up,
                  isRate: true,
                ),
                const SizedBox(height: 2),
                _SpeedRow(
                  key: const ValueKey('rate-down'),
                  icon: Icons.arrow_downward,
                  color: secondaryColor,
                  value: traffic.down,
                  isRate: true,
                ),
                const SizedBox(height: 10),
                // 下层：累计用量，小字。
                _SpeedRow(
                  key: const ValueKey('total-up'),
                  icon: Icons.arrow_upward,
                  color: primaryColor,
                  value: total.up,
                  isRate: false,
                ),
                _SpeedRow(
                  key: const ValueKey('total-down'),
                  icon: Icons.arrow_downward,
                  color: secondaryColor,
                  value: total.down,
                  isRate: false,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 流量磁贴里的一行：箭头 + 数值。
///
/// 速率和累计共用同一个组件，只有字号和后缀不同——两者摆在一起时，用同一套
/// 排版才看得出「上面是速度、下面是总量」，而不是两组无关的数字。
class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.isRate,
  });

  final IconData icon;
  final Color color;
  final num value;

  /// 速率（带 /s、大字）还是累计（不带、小字）。
  final bool isRate;

  @override
  Widget build(BuildContext context) {
    final traffic = value.traffic;
    final style = isRate
        ? context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: tabularFigures,
          )
        : context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontFeatures: tabularFigures,
          );
    return Row(
      children: [
        Icon(icon, color: color, size: isRate ? 16 : 12),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            isRate ? '${traffic.show}/s' : traffic.show,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
