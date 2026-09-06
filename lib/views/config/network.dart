import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/views/always_on_vpn.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class VPNItem extends ConsumerWidget {
  const VPNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      vpnSettingProvider.select((state) => state.enable),
    );
    return ListItem.toggle(
      title: const Text('VPN'),
      subtitle: Text(appLocalizations.vpnEnableDesc),
      value: enable,
      onChanged: (value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(enable: value));
      },
    );
  }
}

class TUNItem extends ConsumerWidget {
  const TUNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );

    return ListItem.toggle(
      title: Text(appLocalizations.tun),
      subtitle: Text(appLocalizations.tunDesc),
      value: enable,
      onChanged: (value) async {
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(enable: value));
      },
    );
  }
}

class AllowBypassItem extends ConsumerWidget {
  const AllowBypassItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final allowBypass = ref.watch(
      vpnSettingProvider.select((state) => state.allowBypass),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.allowBypass),
      subtitle: Text(appLocalizations.allowBypassDesc),
      value: allowBypass,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(allowBypass: value));
      },
    );
  }
}

class VpnSystemProxyItem extends ConsumerWidget {
  const VpnSystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final systemProxy = ref.watch(
      vpnSettingProvider.select((state) => state.systemProxy),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.systemProxyDesc),
      value: systemProxy,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(systemProxy: value));
      },
    );
  }
}

class SystemProxyItem extends ConsumerWidget {
  const SystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final systemProxy = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );

    return ListItem.toggle(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.systemProxyDesc),
      value: systemProxy,
      onChanged: (bool value) async {
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(systemProxy: value));
      },
    );
  }
}

class Ipv6Item extends ConsumerWidget {
  const Ipv6Item({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final ipv6 = ref.watch(vpnSettingProvider.select((state) => state.ipv6));
    return ListItem.toggle(
      title: const Text('IPv6'),
      subtitle: Text(appLocalizations.ipv6InboundDesc),
      value: ipv6,
      onChanged: (bool value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(ipv6: value));
      },
    );
  }
}

class AutoSetSystemDnsItem extends ConsumerWidget {
  const AutoSetSystemDnsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final autoSetSystemDns = ref.watch(
      networkSettingProvider.select((state) => state.autoSetSystemDns),
    );
    return ListItem.toggle(
      title: Text(appLocalizations.autoSetSystemDns),
      value: autoSetSystemDns,
      onChanged: (bool value) async {
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(autoSetSystemDns: value));
      },
    );
  }
}

class TunStackItem extends ConsumerWidget {
  const TunStackItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final stack = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.stack),
    );

    return ListItem.options(
      title: Text(appLocalizations.stackMode),
      subtitle: Text(stack.name),
      value: stack,
      options: TunStack.values,
      textBuilder: (value) => value.name,
      onChanged: (value) {
        if (value == null) {
          return;
        }
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(stack: value));
      },
      dialogTitle: appLocalizations.stackMode,
    );
  }
}

class BypassDomainItem extends ConsumerWidget {
  const BypassDomainItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final bypassDomain = ref.watch(
      networkSettingProvider.select((state) => state.bypassDomain),
    );
    return ListItem.open(
      title: Text(appLocalizations.bypassDomain),
      subtitle: Text(appLocalizations.bypassDomainDesc),
      blur: false,
      widget: ListInputPage(
        title: appLocalizations.bypassDomain,
        items: bypassDomain,
        itemMaxLength: TextInputLimits.domain,
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (items) {
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(bypassDomain: List.from(items)));
      },
    );
  }
}

class DNSHijackingItem extends ConsumerWidget {
  const DNSHijackingItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final dnsHijacking = ref.watch(
      vpnSettingProvider.select((state) => state.dnsHijacking),
    );
    return ListItem<RouteMode>.toggle(
      title: Text(appLocalizations.dnsHijacking),
      value: dnsHijacking,
      onChanged: (value) async {
        ref
            .read(vpnSettingProvider.notifier)
            .update((state) => state.copyWith(dnsHijacking: value));
      },
    );
  }
}

class RouteModeItem extends ConsumerWidget {
  const RouteModeItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final routeMode = ref.watch(
      networkSettingProvider.select((state) => state.routeMode),
    );
    return ListItem<RouteMode>.options(
      title: Text(appLocalizations.routeMode),
      subtitle: Text(Intl.message('routeMode_${routeMode.name}')),
      dialogTitle: appLocalizations.routeMode,
      options: RouteMode.values,
      onChanged: (RouteMode? value) {
        if (value == null) {
          return;
        }
        ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(routeMode: value));
      },
      textBuilder: (routeMode) => Intl.message('routeMode_${routeMode.name}'),
      value: routeMode,
    );
  }
}

class RouteAddressItem extends ConsumerWidget {
  const RouteAddressItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final routeAddress = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.routeAddress),
    );
    return ListItem.open(
      title: Text(appLocalizations.routeAddress),
      subtitle: Text(appLocalizations.routeAddressDesc),
      blur: false,
      maxWidth: 360,
      widget: ListInputPage(
        title: appLocalizations.routeAddress,
        items: routeAddress,
        itemMaxLength: TextInputLimits.cidr,
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (items) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith.tun(routeAddress: List.from(items)),
            );
      },
    );
  }
}

class NetworkListView extends StatelessWidget {
  const NetworkListView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return generateListView([
      // VPN 总开关原来是裸的一行，通栏平铺在下面几张分组卡片上面；
      // 套进无标题的分组卡片，整页才是同一种圆角卡片。
      if (system.isAndroid) ...generateSection(items: [const VPNItem()]),
      if (system.isAndroid)
        ...generateSection(
          title: 'VPN',
          items: [
            const VpnSystemProxyItem(),
            const BypassDomainItem(),
            const AllowBypassItem(),
            const Ipv6Item(),
            const DNSHijackingItem(),
            // 放在最后：这一条是唯一一条把用户送出应用、去系统设置里操作的。
            const AlwaysOnVpnItem(),
          ],
        ),
      if (system.isDesktop)
        ...generateSection(
          title: appLocalizations.system,
          items: [const SystemProxyItem(), const BypassDomainItem()],
        ),
      // 「路由地址」在 bypassPrivate 模式下不该出现。原来由 RouteAddressItem
      // 自己返回空 Container——它仍然算分组里的一条，上下的分隔线照画，于是留下
      // 两条紧挨着的横线。条件要在组装列表时判断，让这一条根本不进去。
      Consumer(
        builder: (_, ref, _) {
          final bypassPrivate = ref.watch(
            networkSettingProvider.select(
              (state) => state.routeMode == RouteMode.bypassPrivate,
            ),
          );
          // 换路由模式时「路由地址」这一条会整条出现或消失。原来是卡片高度瞬间
          // 变化，视线一下子失去落点。AnimatedSize 让卡片自己长高/收矮，新的一
          // 条是被「拉」出来的，看得出它是从哪儿冒出来的。
          //
          // 为什么不是把这一条留在原地做高度收缩：分组卡片的分隔线是
          // generateSection 在条目之间自动插的，条目留着（高度 0）就会在卡片底部
          // 留一条孤零零的横线。让整张卡片动，才不用去动共享的分组组件。
          return AnimatedSize(
            duration: Motion.normal,
            curve: Motion.move,
            alignment: Alignment.topCenter,
            child: Column(
              children: generateSection(
                title: appLocalizations.options,
                items: [
                  if (system.isDesktop) const TUNItem(),
                  if (system.isMacOS) const AutoSetSystemDnsItem(),
                  const TunStackItem(),
                  if (!system.isDesktop) ...[
                    const RouteModeItem(),
                    if (!bypassPrivate) const RouteAddressItem(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ]);
  }
}
