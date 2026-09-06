import 'package:clash_party/common/common.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 网络检测的详情页。
///
/// 首页那块磁贴只有一行 IP，看不出「我现在到底是怎么出去的」。这一页把散落在
/// 各处的判断依据摆在一起：出口 IP 的完整画像（地区、经纬度、ASN、企业、风险
/// 评分、注册信息）、本机内网地址、当前走的节点和出站模式、系统代理与虚拟网卡
/// 的开关状态、混合端口，以及几个常用站点的连通性。排查「为什么没走代理」
/// 「这个 IP 是不是机房 IP」时，需要的就是这几行。
class NetworkDetectionDetailView extends ConsumerWidget {
  const NetworkDetectionDetailView({super.key});

  static String countryFlag(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code.length != 2) {
      return countryCode;
    }
    return String.fromCharCode(code.codeUnitAt(0) - 0x41 + 0x1F1E6) +
        String.fromCharCode(code.codeUnitAt(1) - 0x41 + 0x1F1E6);
  }

  /// 把城市 / 省 / 国家拼成一行，缺哪段跳过哪段。
  ///
  /// 竞速拿到的是哪个数据源事先不确定，有的只给国家，有的连城市都给。硬按固定
  /// 格式拼会拼出「, , 美国」这种东西。
  static String locationText(IpInfo info) {
    final parts = <String>[
      if (info.city != null) info.city!,
      if (info.region != null && info.region != info.city) info.region!,
      info.country ?? info.countryCode.toUpperCase(),
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final detection = ref.watch(networkDetectionProvider);
    final ipInfo = detection.ipInfo;
    final localIp = ref.watch(localIpProvider);
    final isStart = ref.watch(runTimeProvider.select((state) => state != null));
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final mixedPort = ref.watch(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    // 「虚拟网卡」到底开没开，安卓和桌面读的是**两个不同的开关**。
    //
    // 安卓上首页那个「虚拟网卡」磁贴拨的是 `vpnSettingProvider.enable`
    // （VpnService 走不走），而 `patchClashConfig.tun.enable` 是桌面端的 TUN
    // 开关、安卓上恒为 false。之前这里只读后者，于是用户明明开着虚拟网卡，
    // 网络检测里却显示「已断开」。按平台读对应的那个。
    final tunEnable = system.isAndroid
        ? ref.watch(vpnSettingProvider.select((state) => state.enable))
        : ref.watch(
            patchClashConfigProvider.select((state) => state.tun.enable),
          );
    final systemProxy = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );
    final groupName = ref.watch(
      currentProfileProvider.select((state) => state?.currentGroupName),
    );
    final selectedMap = ref.watch(selectedMapProvider);
    final node = groupName == null ? null : selectedMap[groupName];

    return CommonScaffold(
      title: appLocalizations.networkDetection,
      actions: [
        IconButton(
          tooltip: appLocalizations.update,
          onPressed: () {
            ref.read(networkDetectionProvider.notifier).startCheck();
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ...generateSection(
            title: appLocalizations.networkDetection,
            isFirst: true,
            items: [
              _Row(
                icon: Icons.public,
                label: 'IP',
                // 检测不出来时明确说「超时」，不要留一片空白让人以为还在转。
                value:
                    ipInfo?.ip ??
                    (detection.isLoading ? '···' : appLocalizations.timeout),
                copyable: ipInfo != null,
              ),
              _Row(
                icon: Icons.flag_outlined,
                label: appLocalizations.country,
                value: ipInfo == null
                    ? '-'
                    : '${countryFlag(ipInfo.countryCode)} '
                          '${ipInfo.countryCode.toUpperCase()}',
              ),
              // 下面这些都是「有才显示」。不同数据源给的字段差别很大，把拿不到
              // 的一律画成一行「-」，只会让页面变成一片空表格。
              if (ipInfo != null)
                _Row(
                  icon: Icons.place_outlined,
                  label: appLocalizations.location,
                  value: locationText(ipInfo),
                ),
              if (ipInfo?.longitude != null)
                _Row(
                  icon: Icons.swap_horiz,
                  label: appLocalizations.longitude,
                  value: ipInfo!.longitude!.toStringAsFixed(4),
                ),
              if (ipInfo?.latitude != null)
                _Row(
                  icon: Icons.swap_vert,
                  label: appLocalizations.latitude,
                  value: ipInfo!.latitude!.toStringAsFixed(4),
                ),
              if (ipInfo?.timezone != null)
                _Row(
                  icon: Icons.schedule,
                  label: appLocalizations.timeZone,
                  value: ipInfo!.timezone!,
                ),
              if (ipInfo?.asn != null)
                _Row(
                  icon: Icons.hub_outlined,
                  label: 'ASN',
                  value: 'AS${ipInfo!.asn}',
                  copyable: true,
                ),
              if (ipInfo?.asnOrganization != null)
                _Row(
                  icon: Icons.account_tree_outlined,
                  label: appLocalizations.asnOwner,
                  value: ipInfo!.asnOrganization!,
                ),
              if (ipInfo?.company != null)
                _Row(
                  icon: Icons.business_outlined,
                  label: appLocalizations.company,
                  value: ipInfo!.company!,
                ),
              if (ipInfo?.isp != null)
                _Row(
                  icon: Icons.router_outlined,
                  label: 'ISP',
                  value: ipInfo!.isp!,
                ),
              if (ipInfo?.ipType != null)
                _Row(
                  icon: Icons.category_outlined,
                  label: appLocalizations.ipType,
                  value: ipInfo!.ipType!,
                ),
              if (ipInfo?.risk != null)
                _Row(
                  icon: Icons.gpp_maybe_outlined,
                  label: appLocalizations.risk,
                  value: ipInfo!.risk!,
                  // 风险分很容易被当成「这个代理安不安全」的结论，必须当场说清
                  // 它其实只是第三方对这段地址的举报历史。
                  info: appLocalizations.riskTip,
                ),
              if (ipInfo?.registryCountry != null)
                _Row(
                  icon: Icons.how_to_reg_outlined,
                  label: appLocalizations.registryCountry,
                  value: ipInfo!.registryCountry!.toUpperCase(),
                ),
              if (ipInfo?.registry != null)
                _Row(
                  icon: Icons.corporate_fare,
                  label: appLocalizations.registry,
                  value: ipInfo!.registry!,
                ),
              if (ipInfo?.cidr != null)
                _Row(
                  icon: Icons.numbers,
                  label: 'CIDR',
                  value: ipInfo!.cidr!,
                  copyable: true,
                ),
              _Row(
                icon: Icons.lan_outlined,
                label: appLocalizations.intranetIP,
                value: localIp ?? '-',
                copyable: localIp != null,
              ),
            ],
          ),
          ...generateSection(
            title: appLocalizations.proxies,
            items: [
              _Row(
                icon: Icons.power_settings_new,
                label: appLocalizations.status,
                value: isStart
                    ? appLocalizations.connected
                    : appLocalizations.disconnected,
              ),
              _Row(
                icon: Icons.call_split,
                label: appLocalizations.outboundMode,
                value: Intl.message(mode.name),
              ),
              _Row(
                icon: Icons.bolt,
                label: appLocalizations.proxyGroup,
                value: node ?? groupName ?? '-',
              ),
            ],
          ),
          ...generateSection(
            title: appLocalizations.network,
            items: [
              _Row(
                icon: Icons.language,
                label: appLocalizations.systemProxy,
                value: _onOff(context, systemProxy),
              ),
              _Row(
                icon: Icons.stacked_line_chart,
                label: appLocalizations.tun,
                value: _onOff(context, tunEnable),
              ),
              _Row(
                icon: Icons.settings_ethernet,
                label: appLocalizations.mixedPort,
                value: '$mixedPort',
              ),
            ],
          ),
          const ConnectivitySection(),
        ],
      ),
    );
  }

  String _onOff(BuildContext context, bool value) {
    final l = context.appLocalizations;
    return value ? l.connected : l.disconnected;
  }
}

/// 连通性检测：常用站点通不通、多久通，外加这条链路有没有 IPv6。
///
/// 「IP 查出来了」和「网真的能用」是两回事——IP 查询接口本身可能被缓存、也可能
/// 走了另一条路。这几行是直接的证据。IPv6 单列一项是因为双栈环境下部分网站会
/// 优先走 IPv6，而多数机场只给 IPv4，那部分流量就绕过了代理。
///
/// 状态放在这个局部 widget 里而不是全局 provider：它只在这一页有意义，页面关掉
/// 就该忘掉，没必要让别处看见，也不用担心后台空跑。
class ConnectivitySection extends StatefulWidget {
  const ConnectivitySection({super.key});

  /// 三个目标都选无内容或内容极小的端点，测的是链路通不通，不是带宽。
  static const targets = <String, String>{
    'Google': 'https://www.google.com/generate_204',
    'Cloudflare': 'https://www.cloudflare.com/cdn-cgi/trace',
    'GitHub': 'https://github.com/',
  };

  @override
  State<ConnectivitySection> createState() => _ConnectivitySectionState();
}

class _ConnectivitySectionState extends State<ConnectivitySection> {
  final Map<String, Duration?> _latencies = {};
  final Set<String> _pending = {};
  String? _ipv6;
  bool _ipv6Checked = false;
  bool _ipv6Pending = false;

  /// 页面关掉之后迟到的响应不能再 setState，用它挡住。
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _runAll();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _runAll() async {
    if (_pending.isNotEmpty || _ipv6Pending) {
      return;
    }
    setState(() {
      _pending.addAll(ConnectivitySection.targets.keys);
      _ipv6Pending = true;
      _ipv6Checked = false;
    });
    await Future.wait([
      for (final entry in ConnectivitySection.targets.entries)
        _measure(entry.key, entry.value),
      _checkIpv6(),
    ]);
  }

  Future<void> _measure(String name, String url) async {
    final latency = await request.measureLatency(url);
    if (_disposed) return;
    setState(() {
      _latencies[name] = latency;
      _pending.remove(name);
    });
  }

  Future<void> _checkIpv6() async {
    final address = await request.checkIpv6();
    if (_disposed) return;
    setState(() {
      _ipv6 = address;
      _ipv6Checked = true;
      _ipv6Pending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isBusy = _pending.isNotEmpty || _ipv6Pending;
    return Column(
      children: generateSection(
        title: appLocalizations.connectivityTest,
        actions: [
          IconButton(
            tooltip: appLocalizations.update,
            onPressed: isBusy ? null : _runAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
        items: [
          for (final name in ConnectivitySection.targets.keys)
            _Row(
              icon: Icons.travel_explore,
              label: name,
              value: _pending.contains(name)
                  ? '···'
                  : _latencyText(context, _latencies[name]),
              valueColor: _pending.contains(name) || _latencies[name] != null
                  ? null
                  : context.colorScheme.error,
            ),
          _Row(
            icon: Icons.alt_route,
            label: appLocalizations.ipv6Support,
            value: _ipv6Pending
                ? '···'
                : !_ipv6Checked
                ? '-'
                : _ipv6 ?? appLocalizations.notSupported,
            copyable: _ipv6 != null,
          ),
        ],
      ),
    );
  }

  String _latencyText(BuildContext context, Duration? latency) {
    if (latency == null) {
      return context.appLocalizations.unreachable;
    }
    return '${latency.inMilliseconds} ms';
  }
}

/// 详情页里的一行：图标 + 名称 + 取值，取值可长按复制。
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
    this.info,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  /// 给了就在名称后面挂一个 ⓘ，点开弹说明。用于「光看名字会误解」的项。
  final String? info;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ListTile(
      leading: Icon(icon, size: 20, color: context.colorScheme.onSurface),
      title: info == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(),
                  tooltip: appLocalizations.tip,
                  onPressed: () {
                    globalState.showMessage(
                      title: appLocalizations.tip,
                      message: TextSpan(text: info),
                      cancelable: false,
                    );
                  },
                  icon: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.45,
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: context.textTheme.bodyMedium?.copyWith(
            color: valueColor ?? context.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      onTap: !copyable
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                context.showNotifier(context.appLocalizations.copySuccess);
              }
            },
    );
  }
}
