import 'dart:async';
import 'dart:io';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/views/dashboard/widgets/metric_row.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一块网卡和它身上的地址。
class LocalInterface {
  const LocalInterface({required this.name, required this.addresses});

  final String name;
  final List<String> addresses;
}

typedef LocalInterfacesReader = Future<List<LocalInterface>> Function();

/// 内网 IP 磁贴的详情页。
///
/// 这块磁贴原来**根本点不动**（`onPressed: null`），因为当时没有任何地方可去。
/// 但它上面那一行只是「排序后第一块网卡的第一个地址」——手机同时挂着 Wi-Fi、
/// 蜂窝、还有 VPN 起的虚拟网卡时，这一行到底指的是哪块网卡完全看不出来。
/// 这一页把所有网卡和它们的地址都摊开，每行点一下即可复制。
class IntranetIpDetailView extends ConsumerStatefulWidget {
  const IntranetIpDetailView({
    super.key,
    @visibleForTesting this.interfacesReader,
  });

  final LocalInterfacesReader? interfacesReader;

  @override
  ConsumerState<IntranetIpDetailView> createState() =>
      _IntranetIpDetailViewState();
}

class _IntranetIpDetailViewState extends ConsumerState<IntranetIpDetailView> {
  List<LocalInterface>? _interfaces;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
    });
  }

  Future<List<LocalInterface>> _read() async {
    final reader = widget.interfacesReader;
    if (reader != null) {
      return reader();
    }
    final interfaces = await NetworkInterface.list(includeLoopback: false);
    return [
      for (final interface in interfaces)
        LocalInterface(
          name: interface.name,
          addresses: [
            for (final address in interface.addresses) address.address,
          ],
        ),
    ];
  }

  Future<void> _refresh() async {
    try {
      final interfaces = await _read();
      if (!mounted) {
        return;
      }
      setState(() {
        _interfaces = interfaces;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _interfaces = const [];
      });
      commonPrint.log('network interfaces error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final localIp = ref.watch(localIpProvider);
    final interfaces = _interfaces;
    return CommonScaffold(
      title: appLocalizations.intranetIP,
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
            title: appLocalizations.intranetIP,
            isFirst: true,
            items: [
              MetricRow(
                icon: Icons.lan_outlined,
                label: appLocalizations.address,
                value: localIp == null || localIp.isEmpty
                    ? appLocalizations.noNetwork
                    : localIp,
                copyable: localIp != null && localIp.isNotEmpty,
              ),
            ],
          ),
          ...generateSection(
            title: appLocalizations.networkInterfaces,
            items: [
              // 还没读完时不要显示「没有网卡」——那是个结论，而此刻只是没结果。
              if (interfaces == null)
                MetricRow(
                  icon: Icons.settings_ethernet,
                  label: appLocalizations.networkInterfaces,
                  value: '···',
                )
              else if (interfaces.isEmpty)
                MetricRow(
                  icon: Icons.settings_ethernet,
                  label: appLocalizations.networkInterfaces,
                  value: appLocalizations.none,
                )
              else
                for (final interface in interfaces)
                  for (final address in interface.addresses)
                    MetricRow(
                      icon: Icons.settings_ethernet,
                      label: interface.name,
                      value: address,
                      copyable: true,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
