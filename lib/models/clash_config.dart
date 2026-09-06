import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/clash_config.freezed.dart';

part 'generated/clash_config.g.dart';

const defaultClashConfig = PatchClashConfig();

const defaultTun = Tun();
const defaultDns = Dns();
const defaultSniffer = Sniffer();
const defaultGeoXUrl = {
  GeoResource.MMDB:
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb',
  GeoResource.ASN:
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb',
  GeoResource.GEOIP:
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat',
  GeoResource.GEOSITE:
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat',
};

const defaultMixedPort = 7890;
const defaultKeepAliveInterval = 30;

/// 设了混合端口密码之后，**本机自己仍然免密**。
///
/// 安卓开着「系统代理」时，VPN 会把系统 HTTP 代理指到 `127.0.0.1:mixedPort`
/// （见 `VpnOptions.systemProxy`），而系统代理这条路**没有地方填用户名密码**。
/// 内核的 `skip-auth-prefixes` 默认是空的（`adapter/inbound/auth.go` 里
/// `skipAuthPrefixes` 初值为 nil），也就是"谁都要验"——真按内核默认值走，用户
/// 一设密码手机自己就上不了网，还完全看不出跟那个密码有关。
///
/// 取值和桌面端一致（`src/shared/appConfig.ts:41`）。
const defaultSkipAuthPrefixes = ['127.0.0.1/32', '::1/128'];

const defaultBypassPrivateRouteAddress = [
  '1.0.0.0/8',
  '2.0.0.0/7',
  '4.0.0.0/6',
  '8.0.0.0/7',
  '11.0.0.0/8',
  '12.0.0.0/6',
  '16.0.0.0/4',
  '32.0.0.0/3',
  '64.0.0.0/3',
  '96.0.0.0/4',
  '112.0.0.0/5',
  '120.0.0.0/6',
  '124.0.0.0/7',
  '126.0.0.0/8',
  '128.0.0.0/3',
  '160.0.0.0/5',
  '168.0.0.0/8',
  '169.0.0.0/9',
  '169.128.0.0/10',
  '169.192.0.0/11',
  '169.224.0.0/12',
  '169.240.0.0/13',
  '169.248.0.0/14',
  '169.252.0.0/15',
  '169.255.0.0/16',
  '170.0.0.0/7',
  '172.0.0.0/12',
  '172.32.0.0/11',
  '172.64.0.0/10',
  '172.128.0.0/9',
  '173.0.0.0/8',
  '174.0.0.0/7',
  '176.0.0.0/4',
  '192.0.0.0/9',
  '192.128.0.0/11',
  '192.160.0.0/13',
  '192.169.0.0/16',
  '192.170.0.0/15',
  '192.172.0.0/14',
  '192.176.0.0/12',
  '192.192.0.0/10',
  '193.0.0.0/8',
  '194.0.0.0/7',
  '196.0.0.0/6',
  '200.0.0.0/5',
  '208.0.0.0/4',
  '240.0.0.0/5',
  '248.0.0.0/6',
  '252.0.0.0/7',
  '254.0.0.0/8',
  '255.0.0.0/9',
  '255.128.0.0/10',
  '255.192.0.0/11',
  '255.224.0.0/12',
  '255.240.0.0/13',
  '255.248.0.0/14',
  '255.252.0.0/15',
  '255.254.0.0/16',
  '255.255.0.0/17',
  '255.255.128.0/18',
  '255.255.192.0/19',
  '255.255.224.0/20',
  '255.255.240.0/21',
  '255.255.248.0/22',
  '255.255.252.0/23',
  '255.255.254.0/24',
  '255.255.255.0/25',
  '255.255.255.128/26',
  '255.255.255.192/27',
  '255.255.255.224/28',
  '255.255.255.240/29',
  '255.255.255.248/30',
  '255.255.255.252/31',
  '255.255.255.254/32',
  '::/1',
  '8000::/2',
  'c000::/3',
  'e000::/4',
  'f000::/5',
  'f800::/6',
  'fe00::/9',
  'fec0::/10',
];

@freezed
abstract class ProxyGroup with _$ProxyGroup {
  const factory ProxyGroup({
    int? profileId,
    @JsonKey(fromJson: Snowflake.buildId) required int id,
    required String name,
    required GroupType type,
    List<String>? proxies,
    List<String>? use,
    int? interval,
    bool? lazy,
    @JsonKey(name: 'disable-udp') bool? disableUDP,
    String? url,
    int? timeout,
    @JsonKey(name: 'max-failed-times') int? maxFailedTimes,
    String? filter,
    @JsonKey(name: 'exclude-filter') String? excludeFilter,
    @JsonKey(name: 'exclude-type') String? excludeType,
    @JsonKey(name: 'expected-status') String? expectedStatus,
    @JsonKey(name: 'include-all') bool? includeAll,
    @JsonKey(name: 'include-all-proxies') bool? includeAllProxies,
    @JsonKey(name: 'include-all-providers') bool? includeAllProviders,
    bool? hidden,
    String? icon,
    String? order,
  }) = _ProxyGroup;

  factory ProxyGroup.fromJson(Map<String, Object?> json) =>
      _$ProxyGroupFromJson(json);
}

@freezed
abstract class Proxy with _$Proxy {
  const factory Proxy({
    required String name,
    required String type,
    String? now,
  }) = _Proxy;

  factory Proxy.fromJson(Map<String, Object?> json) => _$ProxyFromJson(json);
}

@freezed
abstract class CustomOverwriteDate with _$CustomOverwriteDate {
  const factory CustomOverwriteDate({
    @Default([]) List<Proxy> proxies,
    @Default([]) List<ProxyGroup> proxyGroups,
    @Default({}) Set<String> proxyProviders,
    @Default({}) Set<String> ruleTargets,
    @Default({}) Set<String> subRules,
  }) = _CustomOverwriteDate;
}

@freezed
abstract class RuleProvider with _$RuleProvider {
  const factory RuleProvider({required String name}) = _RuleProvider;

  factory RuleProvider.fromJson(Map<String, Object?> json) =>
      _$RuleProviderFromJson(json);
}

@freezed
abstract class ProxyProvider with _$ProxyProvider {
  const factory ProxyProvider({required String name}) = _ProxyProvider;

  factory ProxyProvider.fromJson(Map<String, Object?> json) =>
      _$ProxyProviderFromJson(json);
}

/// 域名嗅探。关掉时这一整段**不会下发**，见 [Sniffer.enable]。
@freezed
abstract class Sniffer with _$Sniffer {
  const factory Sniffer({
    /// **默认开**，跟官方推荐配置走（2026-09-03 由用户定"全部以官方推荐为主"）。
    ///
    /// 出处：官方文档仓库 MetaCubeX/Meta-Docs 的 `docs/example/conf.md:49-50`
    /// （渲染后是 <https://wiki.metacubex.one/example/conf/> 那份「完整配置示例」）
    /// 写的是 `sniffer: enable: true`，而且同一份示例里 `tun.enable: true` +
    /// `dns.enhanced-mode: fake-ip`——**正是安卓端的运行场景**。
    ///
    /// 内核自己的默认值确实是 false（`config/config.go:585` 的
    /// `RawSniffer{Enable: false}`），带注释的 `docs/config.yaml:195` 也写 false，
    /// 但那两处是"不配就这样"的兜底值，不是推荐值。
    ///
    /// 为什么在安卓上尤其要开：TUN + fake-ip 下内核拿到的是 IP 不是域名，只能靠
    /// 反查 fake-ip 表还原域名；走 QUIC（安卓 Chrome 默认）时连表都查不到，规则
    /// 匹配不上就落到兜底，表现是"某个网站莫名其妙走了直连"。
    ///
    /// **只有为真时，应用才会把这一整段写进下发给内核的配置**；为假时连键都不碰，
    /// 订阅自带的 `sniffer:` 原样保留（见 `common/task.dart`）。
    @Default(true) bool enable,

    /// 是否把嗅探到的域名当作真正的目的地址去连。
    ///
    /// 桌面端是 false（`src/shared/appConfig.ts:117`），官方示例也写 false。
    /// 内核自己默认 true，这里跟桌面端和示例走：只用嗅探结果去匹配规则，
    /// 实际连的还是原来的地址，行为更保守。
    @Default(false) @JsonKey(name: 'override-destination') bool overrideDest,

    /// 已废弃的旧写法，内核在 `sniff` 非空时完全忽略它
    /// （`config/config.go` 的 `parseSniffer`）。保留只为读得懂旧订阅，不主动写。
    @Default([]) List<String> sniffing,
    @Default([]) @JsonKey(name: 'force-domain') List<String> forceDomain,
    @Default([]) @JsonKey(name: 'skip-src-address') List<String> skipSrcAddress,
    @Default([]) @JsonKey(name: 'skip-dst-address') List<String> skipDstAddress,

    /// 桌面端 `src/shared/appConfig.ts:127` 的取值。
    @Default(['+.push.apple.com'])
    @JsonKey(name: 'skip-domain')
    List<String> skipDomain,
    @Default([]) @JsonKey(name: 'port-whitelist') List<String> port,
    @Default(true) @JsonKey(name: 'force-dns-mapping') bool forceDnsMapping,
    @Default(true) @JsonKey(name: 'parse-pure-ip') bool parsePureIp,

    /// 要嗅探哪些协议、各自哪些端口。
    ///
    /// **这个表为空 = 一个协议都不嗅探**：内核 `parseSniffer` 在 `sniff` 为空时
    /// 会退回读已废弃的 `sniffing`，两个都空就一个 sniffer 都不加载——也就是说
    /// 光把 [enable] 打开是无效配置。原来这里默认是空表，属于"开了也白开"。
    ///
    /// HTTP / TLS 的取值抄桌面端 `src/shared/appConfig.ts:118-126`。
    ///
    /// **QUIC 从 2026-09-03 起进默认表**（此前刻意不写，那笔账现在结了）。出处是
    /// 官方推荐配置 MetaCubeX/Meta-Docs 的 `docs/example/conf.md:57-58`
    /// （`QUIC: ports: [443, 8443]`），以及内核仓库带注释的 `docs/config.yaml:203`
    /// 那份示例里同样列着 `QUIC:`。
    ///
    /// 端口写 443 而不是官方那份的 `[443, 8443]`：443 就是内核对 QUIC 的默认端口
    /// （`sniffer/quic_sniffer.go`），和旁边 TLS 那条的写法保持一致；HTTP / TLS
    /// 两条的端口列表这次没动，改它们不在这次的范围里。
    @Default({
      'HTTP': SnifferConfig(ports: ['80', '443'], overrideDest: false),
      'TLS': SnifferConfig(ports: ['443']),
      'QUIC': SnifferConfig(ports: ['443']),
    })
    Map<String, SnifferConfig> sniff,
  }) = _Sniffer;

  factory Sniffer.fromJson(Map<String, Object?> json) =>
      _$SnifferFromJson(json);

  factory Sniffer.safeFromJson(Map<String, Object?>? json) {
    if (json == null) {
      return defaultSniffer;
    }
    try {
      return Sniffer.fromJson(json);
    } catch (_) {
      return defaultSniffer;
    }
  }
}

extension SnifferExt on Sniffer {
  /// 下发给内核的样子：空的列表/表一律删键。
  ///
  /// 空值不是"设成空"，是"界面没设置"。原样写进去会把订阅或内核默认值顶掉——
  /// 这正是 TUN 那个 `route-exclude-address` 空列表顶掉订阅取值的老毛病。
  /// `sniffing` 更要删：它是已废弃的键，写个空列表出去只会让配置更难读。
  Map<String, dynamic> toKernelJson() {
    final json = Map<String, dynamic>.from(toJson());
    json.remove('sniffing');
    // 生成的 `toJson` 对 `sniff` 是原样塞对象进去（`clash_config.g.dart` 里那行
    // `'sniff': instance.sniff`），不会递归。这里要的是能直接写成 YAML 的普通
    // Map，所以自己展开一层；顺手把没设置的 override-destination 去掉，
    // 免得写出一行 `override-destination: null`。
    json['sniff'] = {
      for (final entry in sniff.entries)
        entry.key: <String, dynamic>{
          'ports': entry.value.ports,
          if (entry.value.overrideDest != null)
            'override-destination': entry.value.overrideDest,
        },
    };
    json.removeWhere(
      (_, value) =>
          (value is List && value.isEmpty) || (value is Map && value.isEmpty),
    );
    return json;
  }
}

List<String> _formJsonPorts(List? ports) {
  return ports?.map((item) => item.toString()).toList() ?? [];
}

@freezed
abstract class SnifferConfig with _$SnifferConfig {
  const factory SnifferConfig({
    @Default([]) @JsonKey(fromJson: _formJsonPorts) List<String> ports,
    @JsonKey(name: 'override-destination') bool? overrideDest,
  }) = _SnifferConfig;

  factory SnifferConfig.fromJson(Map<String, Object?> json) =>
      _$SnifferConfigFromJson(json);
}

@freezed
abstract class Tun with _$Tun {
  const factory Tun({
    @Default(false) bool enable,
    @Default(appName) String device,
    @JsonKey(name: 'auto-route') @Default(false) bool autoRoute,
    @Default(TunStack.mixed) TunStack stack,
    @JsonKey(name: 'dns-hijack') @Default(['any:53']) List<String> dnsHijack,
    @JsonKey(name: 'route-address') @Default([]) List<String> routeAddress,
  }) = _Tun;

  factory Tun.fromJson(Map<String, Object?> json) => _$TunFromJson(json);

  factory Tun.safeFormJson(Map<String, Object?>? json) {
    if (json == null) {
      return defaultTun;
    }
    try {
      return Tun.fromJson(json);
    } catch (_) {
      return defaultTun;
    }
  }
}

extension TunExt on Tun {
  Tun getRealTun(RouteMode routeMode) {
    final mRouteAddress = routeMode == RouteMode.bypassPrivate
        ? defaultBypassPrivateRouteAddress
        : routeAddress;
    return switch (system.isDesktop) {
      true => copyWith(autoRoute: true, routeAddress: []),
      false => copyWith(
        autoRoute: mRouteAddress.isEmpty ? true : false,
        routeAddress: mRouteAddress,
      ),
    };
  }
}

@freezed
abstract class FallbackFilter with _$FallbackFilter {
  const factory FallbackFilter({
    @Default(true) bool geoip,
    @Default('CN') @JsonKey(name: 'geoip-code') String geoipCode,
    @Default([]) List<String> geosite,
    @Default(['240.0.0.0/4']) List<String> ipcidr,
    @Default(['+.google.com', '+.facebook.com', '+.youtube.com'])
    List<String> domain,
  }) = _FallbackFilter;

  factory FallbackFilter.fromJson(Map<String, Object?> json) =>
      _$FallbackFilterFromJson(json);
}

@freezed
abstract class Dns with _$Dns {
  const factory Dns({
    @Default(true) bool enable,
    @Default('0.0.0.0:1053') String listen,
    @Default(false) @JsonKey(name: 'prefer-h3') bool preferH3,
    @Default(true) @JsonKey(name: 'use-hosts') bool useHosts,
    @Default(true) @JsonKey(name: 'use-system-hosts') bool useSystemHosts,
    @Default(false) @JsonKey(name: 'respect-rules') bool respectRules,
    @Default(false) bool ipv6,

    /// 引导用的 DNS：只用来解析 `nameserver` / `fallback` 里那些**写成域名**的
    /// DoH / DoT 地址，必须是纯 IP。
    ///
    /// 保持官方 wiki `config/dns/` 示例里的明文 `223.5.5.5`，**不要改成桌面端的
    /// `tls://223.5.5.5`**（`src/shared/appConfig.ts:80`）。DoT 走 853 端口，
    /// 大量校园网和企业网封这个端口；引导一断，所有节点域名解析全部超时，表现
    /// 就是"连上了但什么都打不开"。明文 53 没有这个问题。
    @Default(['223.5.5.5'])
    @JsonKey(name: 'default-nameserver')
    List<String> defaultNameserver,
    @Default(DnsMode.fakeIp)
    @JsonKey(name: 'enhanced-mode')
    DnsMode enhancedMode,
    @Default('198.18.0.1/16')
    @JsonKey(name: 'fake-ip-range')
    String fakeIpRange,

    /// 不走 fake-ip、必须拿到真实 IP 的域名。
    ///
    /// 取的是「官方示例 ∪ 桌面端」：
    /// - `localhost.ptlogin2.qq.com` 来自官方示例
    ///   （wiki `config/dns/` 的 fake-ip-filter 段、内核仓库 `docs/config.yaml:271`）。
    /// - 其余六条抄桌面端 `src/shared/appConfig.ts:76`。桌面端这一串是有针对性的：
    ///   `*` 匹配不带点的裸主机名（局域网设备），`+.lan` / `+.local` 覆盖局域网与
    ///   mDNS 后缀（比只写 `*.lan` 多覆盖 `lan` 本身和多级子域），
    ///   `time.*.com` / `ntp.*.com` 保证对时不被 fake-ip 顶掉——手机时间不准会
    ///   直接导致 TLS 握手失败，`+.market.xiaomi.com` 是桌面端已验证的小米商店特例。
    ///
    /// 内核自己的默认值（`config/config.go:526-530` 的三条 msftnsci）只针对
    /// Windows 联网检测，对安卓没用，不采纳。
    @Default([
      '*',
      '+.lan',
      '+.local',
      'time.*.com',
      'ntp.*.com',
      '+.market.xiaomi.com',
      'localhost.ptlogin2.qq.com',
    ])
    @JsonKey(name: 'fake-ip-filter')
    List<String> fakeIpFilter,

    /// 指定某些域名走特定的 DNS 服务器。**默认为空**。
    ///
    /// 原来的默认值是官方 wiki 里那段用来讲语法的示例（`www.baidu.com`、
    /// `+.internal.crop.com`、`geosite:cn`），被当成真实默认值发了出去——
    /// `+.internal.crop.com` 是文档里编出来的域名，指向 `10.0.0.1` 毫无意义。
    ///
    /// 内核默认是空（`config/config.go` 的 `DefaultRawConfig` 不设此键），桌面端
    /// 也是空且默认整段剥掉（`src/shared/appConfig.ts:7`、
    /// `src/main/core/factory.ts:164-166`）。两边一致，这里跟着为空。
    ///
    /// 去掉 `geosite:cn` 不改变解析结果：`nameserver` 本来就是两个国内 DoH，
    /// 国内域名照样由它们解析。
    @Default(<String, String>{})
    @JsonKey(name: 'nameserver-policy')
    Map<String, String> nameserverPolicy,
    @Default(['https://doh.pub/dns-query', 'https://dns.alidns.com/dns-query'])
    List<String> nameserver,
    @Default(['tls://8.8.4.4', 'tls://1.1.1.1']) List<String> fallback,
    @Default(['https://doh.pub/dns-query'])
    @JsonKey(name: 'proxy-server-nameserver')
    List<String> proxyServerNameserver,
    @Default(FallbackFilter())
    @JsonKey(name: 'fallback-filter')
    FallbackFilter fallbackFilter,
  }) = _Dns;

  factory Dns.fromJson(Map<String, Object?> json) => _$DnsFromJson(json);

  factory Dns.safeDnsFromJson(Map<String, Object?> json) {
    try {
      return Dns.fromJson(json);
    } catch (_) {
      return const Dns();
    }
  }
}

/// Splits a rule line on commas that are not inside parentheses, so logic
/// rules such as `AND,((NETWORK,udp),(DST-PORT,443)),REJECT` keep their
/// payload intact.
List<String> _splitRuleValue(String value) {
  final result = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (final code in value.codeUnits) {
    final char = String.fromCharCode(code);
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth = depth > 0 ? depth - 1 : 0;
    } else if (char == ',' && depth == 0) {
      result.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  result.add(buffer.toString());
  return result;
}

@freezed
abstract class Rule with _$Rule {
  const factory Rule({
    @Default(-1) int id,
    @Default(RuleAction.DOMAIN) RuleAction ruleAction,
    String? content,
    String? ruleTarget,
    String? ruleProvider,
    String? subRule,
    @Default(false) bool noResolve,
    @Default(false) bool src,
    String? order,
  }) = _Rule;

  // factory Rule.parseString(String? value) {
  //   return Rule.parse(Rule.value(value ?? ''));
  // }

  factory Rule.init() {
    return Rule(
      ruleAction: RuleAction.DOMAIN,
      ruleTarget: RuleTarget.DIRECT.name,
    );
  }

  factory Rule.parse(String value, {int? id}) {
    id ??= snowflake.id;
    final segments = _splitRuleValue(
      value,
    ).map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    if (segments.isEmpty) {
      return Rule(
        id: id,
        ruleAction: RuleAction.DOMAIN,
        ruleTarget: RuleTarget.DIRECT.name,
      );
    }
    var src = false;
    var noResolve = false;
    // Params are trailing tokens; matching them as substrings would eat
    // payloads such as 'imgsrc.ru'.
    while (segments.length > 1) {
      final last = segments.last;
      if (last == 'src') {
        src = true;
      } else if (last == 'no-resolve') {
        noResolve = true;
      } else {
        break;
      }
      segments.removeLast();
    }
    final ruleAction = RuleAction.values.firstWhere(
      (item) => item.value == segments.first,
      orElse: () => RuleAction.DOMAIN,
    );
    final target = segments.length > 1 ? segments.last : null;
    final payload = segments.length > 2
        ? segments.sublist(1, segments.length - 1).join(',')
        : null;
    final isSubRule = ruleAction == RuleAction.SUB_RULE;
    final isRuleSet = ruleAction == RuleAction.RULE_SET;

    return Rule(
      id: id,
      ruleAction: ruleAction,
      content: isRuleSet ? null : payload,
      src: src,
      ruleProvider: isRuleSet ? payload : null,
      noResolve: noResolve,
      subRule: isSubRule ? target : null,
      ruleTarget: isSubRule ? null : target,
    );
  }

  factory Rule.fromJson(Map<String, Object?> json) => _$RuleFromJson(json);
}

extension RuleExt on Rule {
  Rule autoOrder(Rule rule, String? a, String? b) {
    final newRule = rule.order?.isNotEmpty != true
        ? rule.copyWith(order: indexing.generateKeyBetween(a, b))
        : rule;
    return newRule;
  }

  String? get realContent {
    return switch (ruleAction == RuleAction.RULE_SET) {
      true => ruleProvider,
      false => content,
    };
  }

  String? get realTarget {
    return switch (ruleAction == RuleAction.SUB_RULE) {
      true => subRule,
      false => ruleTarget,
    };
  }

  String? targetErrorTip(String invalidSubRuleTip, String invalidPolicyTip) {
    return switch (ruleAction == RuleAction.SUB_RULE) {
      true => invalidSubRuleTip,
      false => invalidPolicyTip,
    };
  }

  String get rawValue {
    final content = realContent;
    final target = realTarget;
    return [
      ruleAction.value,
      ?content,
      ?target,
      if (ruleAction.hasParams) ...[
        if (src) 'src',
        if (noResolve) 'no-resolve',
      ],
    ].join(',');
  }
}

// @freezed
// abstract class Rule with _$Rule {
//   const factory Rule({required int id, required String value, String? order}) =
//       _Rule;
//
//   factory Rule.value(String value) {
//     return Rule(value: value, id: snowflake.id);
//   }
//
//   factory Rule.fromJson(Map<String, Object?> json) => _$RuleFromJson(json);
// }
//
// extension RulesExt on List<Rule> {
//   List<Rule> copyAndPut(Rule rule) {
//     var newList = List<Rule>.from(this);
//     final index = newList.indexWhere((item) => item.id == rule.id);
//     if (index != -1) {
//       rule = newList[index] = rule;
//     } else {
//       newList.insert(0, rule);
//     }
//     return newList;
//   }
// }

// @freezed
// abstract class SubRule with _$SubRule {
//   const factory SubRule({required String name}) = _SubRule;
//
//   factory SubRule.fromJson(Map<String, Object?> json) =>
//       _$SubRuleFromJson(json);
// }
//
List<Rule> _genRules(List<dynamic>? rules) {
  if (rules == null) {
    return [];
  }
  return rules.map((item) => Rule.parse(item)).toList();
}

// List<RuleProvider> _genRuleProviders(Map<String, dynamic> json) {
//   return json.entries.map((entry) => RuleProvider(name: entry.key)).toList();
// }
//
// List<SubRule> _genSubRules(Map<String, dynamic> json) {
//   return json.entries.map((entry) => SubRule(name: entry.key)).toList();
// }

List<String> _genList(Map<String, dynamic> json) {
  return json.entries.map((entry) => entry.key).toList();
}

@freezed
abstract class ClashConfig with _$ClashConfig {
  const factory ClashConfig({
    @Default([]) @JsonKey(name: 'proxy-groups') List<ProxyGroup> proxyGroups,
    @JsonKey(fromJson: _genRules) @Default([]) List<Rule> rules,
    @Default([]) List<Proxy> proxies,
    @JsonKey(name: 'proxy-providers', fromJson: _genList)
    @Default([])
    List<String> proxyProviders,
    @JsonKey(name: 'rule-providers', fromJson: _genList)
    @Default([])
    List<String> ruleProviders,
    @JsonKey(name: 'sub-rules', fromJson: _genList)
    @Default([])
    List<String> subRules,
    @Default({}) Map<String, String> proxyTypeMap,
  }) = _ClashConfig;

  factory ClashConfig.fromJson(Map<String, Object?> json) =>
      _$ClashConfigFromJson(json);
}

extension GeoResourceUrlMapExt on Map<GeoResource, String> {
  Map<String, String> get raw =>
      map((key, value) => MapEntry(key.configKey, value));
}

Map<GeoResource, String> _geoXUrlFromJson(Map<String, Object?>? json) {
  if (json == null) {
    return defaultGeoXUrl;
  }
  return json.map(
    (key, value) => MapEntry(GeoResource.fromJson(key), value as String),
  );
}

Map<String, String> _geoXUrlToJson(Map<GeoResource, String> value) {
  return value.raw;
}

@freezed
abstract class PatchClashConfig with _$PatchClashConfig {
  const factory PatchClashConfig({
    @Default(defaultMixedPort) @JsonKey(name: 'mixed-port') int mixedPort,
    @Default(0) @JsonKey(name: 'socks-port') int socksPort,
    @Default(0) @JsonKey(name: 'port') int port,
    @Default(0) @JsonKey(name: 'redir-port') int redirPort,
    @Default(0) @JsonKey(name: 'tproxy-port') int tproxyPort,
    @Default(Mode.rule) Mode mode,
    @Default(false) @JsonKey(name: 'allow-lan') bool allowLan,
    @Default(LogLevel.error) @JsonKey(name: 'log-level') LogLevel logLevel,

    /// 内核总开关：允不允许内核处理 IPv6 流量。
    ///
    /// **2026-09-03 由 false 改成 true**，官方三处口径一致：内核默认值
    /// `config/config.go:484` 的 `IPv6: true`、带注释示例 `docs/config.yaml:46`
    /// 的 `ipv6: true # 开启 IPv6 总开关`、官方推荐配置
    /// `Meta-Docs/docs/example/conf.md:28`。文档「通用配置」页也写明"默认为 true"。
    ///
    /// **必须和 [VpnProps.ipv6] 一起开，不能只开这一个**：安卓的隧道口在
    /// `VpnService.kt:172-183`，IPv6 地址、`::/0` 路由、IPv6 DNS 三样都锁在
    /// `if (options.ipv6)` 里面。只开内核这一个的话，内核开始放 AAAA 出去、应用
    /// 开始试 IPv6，而隧道里没有 IPv6 路由，每次都得等 Happy Eyeballs 超时回落，
    /// 白白变慢。
    ///
    /// 附带澄清一件事：这种不自洽状态**不是 IPv6 泄露**。安卓的
    /// `Vpn.makeLinkProperties()` 在 VPN 没声明 IPv6 时会给 `::/0` 装一条
    /// unreachable 路由，隧道里的应用拿到的是 ENETUNREACH，不会掉回物理网卡。
    @Default(true) bool ipv6,
    @Default(FindProcessMode.always)
    @JsonKey(
      name: 'find-process-mode',
      unknownEnumValue: FindProcessMode.always,
    )
    FindProcessMode findProcessMode,
    @Default(defaultKeepAliveInterval)
    @JsonKey(name: 'keep-alive-interval')
    int keepAliveInterval,
    @Default(true) @JsonKey(name: 'unified-delay') bool unifiedDelay,

    /// **保持 true，2026-09-03 核实后决定不动。**
    ///
    /// 差点被改成 false，依据是"官方和内核默认都是 false"——前半句是错的。内核
    /// 默认值确实是 false（`config/config.go:497` 的 `TCPConcurrent: false`），
    /// 带注释示例 `docs/config.yaml:89` 也是注释掉的状态；但**官方推荐配置里明写
    /// 着开**：MetaCubeX/Meta-Docs 的 `docs/example/conf.md:31`，
    /// `tcp-concurrent: true`。用户定的口径是"以官方推荐为主"，所以维持现状。
    @Default(true) @JsonKey(name: 'tcp-concurrent') bool tcpConcurrent,
    @Default(defaultTun) @JsonKey(fromJson: Tun.safeFormJson) Tun tun,
    @Default(defaultDns) @JsonKey(fromJson: Dns.safeDnsFromJson) Dns dns,
    @Default(defaultSniffer)
    @JsonKey(fromJson: Sniffer.safeFromJson)
    Sniffer sniffer,
    @Default(defaultGeoXUrl)
    @JsonKey(
      name: 'geox-url',
      fromJson: _geoXUrlFromJson,
      toJson: _geoXUrlToJson,
    )
    Map<GeoResource, String> geoXUrl,
    @Default(GeodataLoader.memconservative)
    @JsonKey(name: 'geodata-loader')
    GeodataLoader geodataLoader,
    @JsonKey(name: 'global-ua') String? globalUa,
    @Default(ExternalControllerStatus.close)
    @JsonKey(name: 'external-controller')
    ExternalControllerStatus externalController,

    /// 外部控制器的访问密钥（内核 `config/config.go:436` 的 `secret`）。
    ///
    /// 控制器只监听 `127.0.0.1:9090`，外网连不上；但手机上**同一台设备里的其它
    /// 应用**照样能连本机回环地址，而这个接口能读配置、改代理、看全部连接。
    /// 空串＝不设密钥，和以前一样。
    @Default('') String secret,

    /// 混合端口的用户名密码，每条写成 `用户名:密码`
    /// （内核 `config/config.go:416` 的 `authentication`，由
    /// `parseAuthentication` 解析）。
    ///
    /// 空列表＝**没设置**，不是"设成空"：为空时下发的配置里连键都不出现，订阅
    /// 自带的 `authentication` 原样保留。这一点和 [Sniffer] 是同一个口径——
    /// 写个空列表出去只会把订阅里本来有的验证顶掉，等于帮用户把门打开。
    @Default([]) List<String> authentication,

    /// 免验证的来源网段，见 [defaultSkipAuthPrefixes]。
    /// 只有 [authentication] 非空时才会跟着一起下发。
    @Default(defaultSkipAuthPrefixes)
    @JsonKey(name: 'skip-auth-prefixes')
    List<String> skipAuthPrefixes,
    @Default({}) Map<String, String> hosts,
    // 默认开启自动更新。
    //
    // geoip / geosite 是规则匹配的底账：库过期意味着新增的域名和 IP 段匹配不上，
    // 表现是"某个网站莫名其妙走了直连"——用户根本不会想到是数据库旧了。默认关着
    // 等于要求用户自己知道有这么个东西并定期去点一下。
    @Default(true) @JsonKey(name: 'geo-auto-update') bool geoAutoUpdate,
    @Default(24) @JsonKey(name: 'geo-update-interval') int geoUpdateInterval,
  }) = _PatchClashConfig;

  factory PatchClashConfig.fromJson(Map<String, Object?> json) =>
      _$PatchClashConfigFromJson(json);

  factory PatchClashConfig.safeFormJson(Map<String, Object?>? json) {
    if (json == null) {
      return defaultClashConfig;
    }
    try {
      return PatchClashConfig.fromJson(json);
    } catch (_) {
      return defaultClashConfig;
    }
  }
}
