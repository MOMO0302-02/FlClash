import 'package:clash_party/common/common.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/views/config/network.dart';
import 'package:clash_party/views/dashboard/widgets/dashboard_tile.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 开关磁贴的正文一律不再写状态文字。
///
/// 桌面端侧边栏的开关卡片（`components/sider/sysproxy-switcher.tsx`、
/// `tun-switcher.tsx`）就只有图标、右上角开关、左下角标题三样，没有任何一行说明
/// 状态的文字。安卓端原来在中间写「接管全部流量 / 仅本地端口」这类字——它和右边的
/// 开关重复，也是让磁贴显得比桌面端乱的原因之一。删掉，和桌面端对齐。
///
/// 开关本身摆在右上角（[DashboardTile.trailing]），收紧点击区（`shrinkWrap`）以便在
/// 一行高的磁贴里和图标、标题一起放下。

class TUNButton extends StatelessWidget {
  const TUNButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return DashboardTile(
      icon: Icons.stacked_line_chart,
      label: appLocalizations.tun,
      onTap: () {
        showSheet(
          context: context,
          builder: (_) {
            return Builder(
              builder: (context) {
                return AdaptiveSheetScaffold(
                  body: generateListView(
                    generateSection(
                      items: [
                        if (system.isDesktop) const TUNItem(),
                        if (system.isMacOS) const AutoSetSystemDnsItem(),
                        const TunStackItem(),
                      ],
                    ),
                  ),
                  title: appLocalizations.tun,
                );
              },
            );
          },
        );
      },
      trailing: Consumer(
        builder: (_, ref, _) {
          final enable = ref.watch(
            patchClashConfigProvider.select((state) => state.tun.enable),
          );
          return dashboardTileSwitch(
            value: enable,
            onChanged: (value) {
              ref
                  .read(patchClashConfigProvider.notifier)
                  .update((state) => state.copyWith.tun(enable: value));
            },
          );
        },
      ),
    );
  }
}

class SystemProxyButton extends StatelessWidget {
  const SystemProxyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return DashboardTile(
      icon: Icons.shuffle,
      label: appLocalizations.systemProxy,
      onTap: () {
        showSheet(
          context: context,
          builder: (_) {
            return AdaptiveSheetScaffold(
              body: generateListView(
                generateSection(
                  items: [const SystemProxyItem(), const BypassDomainItem()],
                ),
              ),
              title: appLocalizations.systemProxy,
            );
          },
        );
      },
      trailing: Consumer(
        builder: (_, ref, _) {
          final systemProxy = ref.watch(
            networkSettingProvider.select((state) => state.systemProxy),
          );
          return dashboardTileSwitch(
            value: systemProxy,
            onChanged: (value) {
              ref
                  .read(networkSettingProvider.notifier)
                  .update((state) => state.copyWith(systemProxy: value));
            },
          );
        },
      ),
    );
  }
}

class VpnButton extends StatelessWidget {
  const VpnButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return DashboardTile(
      // 叫「虚拟网卡」，和桌面端一致（桌面端 `sider.cards.tun` = 虚拟网卡）。
      // 安卓上这块开关控制的就是同一件事：开着走 VpnService 建的虚拟网卡、接管全部
      // 流量；关掉只留一个本地代理端口。
      icon: Icons.stacked_line_chart,
      label: appLocalizations.tun,
      onTap: () {
        showSheet(
          context: context,
          builder: (_) {
            return AdaptiveSheetScaffold(
              body: generateListView(
                generateSection(
                  items: [
                    const VPNItem(),
                    const VpnSystemProxyItem(),
                    const TunStackItem(),
                  ],
                ),
              ),
              title: appLocalizations.tun,
            );
          },
        );
      },
      trailing: Consumer(
        builder: (_, ref, _) {
          final enable = ref.watch(
            vpnSettingProvider.select((state) => state.enable),
          );
          return dashboardTileSwitch(
            value: enable,
            onChanged: (value) {
              ref
                  .read(vpnSettingProvider.notifier)
                  .update((state) => state.copyWith(enable: value));
            },
          );
        },
      ),
    );
  }
}
