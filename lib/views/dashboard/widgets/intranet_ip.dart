import 'package:clash_party/common/common.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/views/dashboard/widgets/dashboard_tile.dart';
import 'package:clash_party/views/dashboard/widgets/intranet_ip_detail.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IntranetIP extends StatelessWidget {
  const IntranetIP({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return DashboardTile(
      icon: Icons.devices,
      label: appLocalizations.intranetIP,
      // 磁贴上这一行只是「排序后第一块网卡的第一个地址」，手机同时挂着 Wi-Fi、
      // 蜂窝和 VPN 虚拟网卡时，光看这一行分不出它属于哪块网卡，也复制不走。
      // 点进去是全部网卡与地址。
      onTap: () {
        showExtend(context, builder: (_) => const IntranetIpDetailView());
      },
      // IP 是这块磁贴的「附加信息」，照桌面端摆右上角；太长就截断，完整地址在详情页。
      trailing: Consumer(
        builder: (_, ref, _) {
          final localIp = ref.watch(localIpProvider);
          return FadeThroughBox(
            child: localIp != null
                ? TooltipText(
                    text: Text(
                      localIp.isNotEmpty ? localIp : appLocalizations.noNetwork,
                      style: dashboardTileValueStyle(
                        context,
                      )?.copyWith(fontFeatures: tabularFigures),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : const SizedBox(height: 16, width: 16, child: HeroSpinner()),
          );
        },
      ),
    );
  }
}
