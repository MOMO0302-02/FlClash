import 'package:clash_party/common/system.dart';
import 'package:clash_party/common/task.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// 内核相关的出厂默认值。
///
/// 钉住的是"新装一台机器、什么都不改，下发给内核的到底是什么"。这件事平时看不出来
/// 也没人会去翻：默认值被改坏了，用户只会遇到"某个网站莫名其妙走了直连""对时不准
/// 导致握手失败""重启后应用连不上"这类症状，根本联想不到是出厂值的锅。
///
/// 每一条断言旁边写清出处，改动时要先回去核对出处再改数字，不要就地改绿。
/// 出处口径（优先级从高到低）：
/// 1. mihomo 官方文档 <https://wiki.metacubex.one>，以及内核仓库自带的示例配置
///    `docs/config.yaml`；
/// 2. 内核源码 `config/config.go` 的 `DefaultRawConfig()`——"配置不写时用什么"；
/// 3. 桌面端 clash-party `src/shared/appConfig.ts` / `src/main/utils/template.ts`。
void main() {
  group('DNS 出厂值', () {
    const dns = Dns();

    test('走 fake-ip，池子是官方那一段', () {
      // wiki config/dns/ 示例：enhanced-mode: fake-ip、fake-ip-range: 198.18.0.1/16。
      // 桌面端同值（appConfig.ts:74-75）。内核自己默认的是 redir-host。
      expect(dns.enable, isTrue);
      expect(dns.enhancedMode, DnsMode.fakeIp);
      expect(dns.fakeIpRange, '198.18.0.1/16');
    });

    test('引导 DNS 是明文 IP，不是 DoT', () {
      // wiki config/dns/ 示例就是单条明文 223.5.5.5。
      // **刻意不抄桌面端的 tls://223.5.5.5**（appConfig.ts:80）：DoT 走 853 端口，
      // 校园网/企业网常封，引导一断就是"连上了但什么都打不开"。
      expect(dns.defaultNameserver, ['223.5.5.5']);
      for (final server in dns.defaultNameserver) {
        expect(
          server,
          isNot(anyOf(startsWith('tls://'), startsWith('quic://'))),
          reason: '引导 DNS 只能用纯 IP 明文，不能依赖 853 之类的加密端口',
        );
      }
    });

    test('国内 DoH 打头，境外走 fallback', () {
      // 三条都逐字来自 wiki config/dns/ 的示例块。
      expect(dns.nameserver, [
        'https://doh.pub/dns-query',
        'https://dns.alidns.com/dns-query',
      ]);
      expect(dns.fallback, ['tls://8.8.4.4', 'tls://1.1.1.1']);
      expect(dns.proxyServerNameserver, ['https://doh.pub/dns-query']);
    });

    test('fallback-filter 按 geoip CN 分流', () {
      // wiki config/dns/ 示例：geoip: true、geoip-code: CN。
      expect(dns.fallbackFilter.geoip, isTrue);
      expect(dns.fallbackFilter.geoipCode, 'CN');
    });

    test('nameserver-policy 是空的，没有文档示例里那几条占位', () {
      // 内核默认不设此键；桌面端也是空且默认整段剥掉
      // （appConfig.ts:7 + factory.ts:164-166）。
      // 曾经的默认值是 wiki 里用来讲语法的示例，其中 `+.internal.crop.com`
      // 是文档编出来的域名，把它指向 10.0.0.1 毫无意义。
      expect(dns.nameserverPolicy, isEmpty);
    });

    test('fake-ip-filter 覆盖局域网、对时和小米商店', () {
      // 官方示例（docs/config.yaml:271）∪ 桌面端（appConfig.ts:76）。
      expect(dns.fakeIpFilter, [
        '*',
        '+.lan',
        '+.local',
        'time.*.com',
        'ntp.*.com',
        '+.market.xiaomi.com',
        'localhost.ptlogin2.qq.com',
      ]);
      // 对时被 fake-ip 顶掉 -> 手机时间不准 -> TLS 握手直接失败，
      // 是个很难往 DNS 上联想的故障，单独钉一遍。
      expect(dns.fakeIpFilter, containsAll(['time.*.com', 'ntp.*.com']));
      // 只写 `*.lan` 的话匹配不到 `lan` 本身和多级子域，`+.lan` 才够。
      expect(dns.fakeIpFilter, contains('+.lan'));
    });

    test('hosts 两个开关都开，和内核默认一致', () {
      // 内核 DefaultRawConfig：UseHosts / UseSystemHosts 均为 true，
      // wiki 示例同样是 true。桌面端两个都关，是桌面端自己的取舍，不跟。
      expect(dns.useHosts, isTrue);
      expect(dns.useSystemHosts, isTrue);
    });

    test('不开 IPv6、不开 prefer-h3、不开 respect-rules', () {
      // 三者官方默认与桌面端一致。respect-rules 与 prefer-h3 同开会被官方
      // 明确劝阻（wiki 原文「强烈不建议和 prefer-h3 一起使用」）。
      expect(dns.ipv6, isFalse);
      expect(dns.preferH3, isFalse);
      expect(dns.respectRules, isFalse);
    });

    test('监听 1053，不是 53', () {
      // 安卓上非 root 绑不了 53；wiki config/dns/ 示例给的就是 0.0.0.0:1053。
      expect(dns.listen, '0.0.0.0:1053');
    });
  });

  group('Sniffer 出厂值', () {
    const sniffer = Sniffer();

    test('两个"补域名"的开关默认开着', () {
      // 内核 DefaultRawConfig 的 RawSniffer：ForceDnsMapping / ParsePureIp 均 true。
      // 桌面端同值（appConfig.ts:115-116）。
      expect(sniffer.forceDnsMapping, isTrue);
      expect(sniffer.parsePureIp, isTrue);
    });

    test('嗅探本身默认是开的——跟官方推荐配置走', () {
      // 2026-09-03 由 false 改成 true，用户定的口径是"全部以官方推荐为主"。
      //
      // 内核默认值确实是 false（config/config.go:585 的 RawSniffer{Enable: false}），
      // 带注释示例 docs/config.yaml:195 也写 false——但那是"不配就这样"的兜底值。
      // 官方推荐配置写的是开：MetaCubeX/Meta-Docs 的 docs/example/conf.md:49-50
      // （wiki.metacubex.one/example/conf/ 那份「完整配置示例」），而且同一份示例
      // 里 tun.enable: true + dns.enhanced-mode: fake-ip，正是安卓端的场景。
      expect(sniffer.enable, isTrue);
    });

    test('sniff 表非空——空表等于一个协议都不嗅探', () {
      // 内核 parseSniffer（config/config.go:1766-1817）：sniff 为空时退回读
      // 已废弃的 sniffing 列表，两个都空就一个 sniffer 都不加载。
      // 也就是说"只把 enable 打开"配上空表是无效配置，必须给出协议表。
      expect(sniffer.sniff, isNotEmpty);
      expect(sniffer.sniff.keys, containsAll(['HTTP', 'TLS', 'QUIC']));
      expect(sniffer.sniff['HTTP']!.ports, ['80', '443']);
      expect(sniffer.sniff['TLS']!.ports, ['443']);
      // 已废弃的旧写法不主动写。
      expect(sniffer.sniffing, isEmpty);
    });

    test('默认含 QUIC——这笔账 2026-09-03 结了', () {
      // 原来这条断言写的是"不含 QUIC"，理由是要不要默认开属于改变现状、待定夺。
      // 用户已定夺：全部以官方推荐为主。官方两份示例都列着 QUIC——
      // Meta-Docs 的 docs/example/conf.md:57-58 是 `QUIC: ports: [443, 8443]`，
      // 内核仓库 docs/config.yaml:203 那份也列了 `QUIC:`。
      //
      // 端口取 443：那是内核对 QUIC 的默认端口，和旁边 TLS 那条写法一致。
      // **只有 sniff 表里出现 QUIC 这个键**内核才会加载它（config/config.go
      // 的 parseSniffer 按 sniff 的键去匹配 snifferTypes.List），所以这个键必须
      // 真的在表里，光把 enable 打开没用。
      expect(sniffer.sniff.containsKey('QUIC'), isTrue);
      expect(sniffer.sniff['QUIC']!.ports, ['443']);
    });

    test('嗅探结果只用来匹配规则，不改实际连接目标', () {
      // 桌面端 appConfig.ts:117 与官方示例都是 false；内核自己默认 true。
      expect(sniffer.overrideDest, isFalse);
      expect(sniffer.sniff['HTTP']!.overrideDest, isFalse);
    });

    test('下发时空列表一律删键，不写 sniffing', () {
      // 空值是"没设置"不是"设成空"。原样写出去会顶掉订阅或内核默认值——
      // 和 TUN 那个空 route-exclude-address 顶掉订阅取值是同一类事故。
      final json = sniffer.toKernelJson();
      expect(json.containsKey('sniffing'), isFalse);
      expect(json.containsKey('force-domain'), isFalse);
      expect(json.containsKey('skip-src-address'), isFalse);
      expect(json.containsKey('port-whitelist'), isFalse);
      // 有值的键要留下。
      expect(json['force-dns-mapping'], isTrue);
      expect(json['parse-pure-ip'], isTrue);
      expect(json['skip-domain'], ['+.push.apple.com']);
      expect((json['sniff'] as Map).keys, containsAll(['HTTP', 'TLS', 'QUIC']));
    });
  });

  group('TUN 出厂值', () {
    const tun = Tun();

    test('用 mixed 栈', () {
      // 桌面端 appConfig.ts:62 就是 'mixed'。内核自己默认 gvisor、
      // 官方示例写 system，三者不同时按"能抄桌面端就抄桌面端"取 mixed。
      expect(tun.stack, TunStack.mixed);
    });

    test('劫持全部 53 端口 DNS 查询', () {
      // 桌面端 appConfig.ts:66 是 ['any:53']；内核默认 ['0.0.0.0:53']，
      // any 比 0.0.0.0 多覆盖 IPv6。
      expect(tun.dnsHijack, ['any:53']);
    });

    test('默认不开，开关由用户和 VPN 服务决定', () {
      expect(tun.enable, isFalse);
    });

    test('不排除任何网段时全量接管', () {
      // 两个平台分支在这一档上结论一致：没有 route-address 就交给 auto-route。
      final all = const Tun().getRealTun(RouteMode.config);
      expect(all.autoRoute, isTrue);
      expect(all.routeAddress, isEmpty);
    });

    test('绕过局域网时改用 route-address 精确指路', () {
      // 这里两个平台分支不同，各钉各的：
      // - 桌面端永远 auto-route + 空 route-address（局域网另有别的处理）；
      // - 移动端把整张排除表写进 route-address 并关掉 auto-route，
      //   因为 VpnService 只认路由表，没有"排除某段"的说法。
      // 测试跑在 Windows 主机上，走的是桌面分支，所以移动分支这里只能靠
      // 断言"另一条分支的取值"来间接守住——真机行为见 core/tun/tun.go。
      final bypass = const Tun().getRealTun(RouteMode.bypassPrivate);
      if (system.isDesktop) {
        expect(bypass.autoRoute, isTrue);
        expect(bypass.routeAddress, isEmpty);
      } else {
        expect(bypass.autoRoute, isFalse);
        expect(bypass.routeAddress, defaultBypassPrivateRouteAddress);
      }
      // 排除表本身是常量，不随平台变，可以无条件钉住。
      expect(defaultBypassPrivateRouteAddress, contains('::/1'));
      expect(defaultBypassPrivateRouteAddress, isNot(contains('0.0.0.0/0')));
    });
  });

  group('通用出厂值', () {
    const patch = PatchClashConfig();

    test('统一延迟开着', () {
      // 桌面端 template.ts:99 为 true；内核自己默认 false。
      expect(patch.unifiedDelay, isTrue);
    });

    test('geo 数据库自动更新，间隔 24 小时', () {
      // 间隔跟官方默认（DefaultRawConfig 的 GeoUpdateInterval: 24）。
      // 自动更新刻意开着——库过期会让新域名匹配不上、莫名走直连，
      // 这是用户绝对联想不到的故障，不能指望他自己去点更新。
      expect(patch.geoAutoUpdate, isTrue);
      expect(patch.geoUpdateInterval, 24);
    });

    test('geox-url 是官方的四个地址', () {
      // 与内核 DefaultRawConfig 的 GeoXUrl 逐字节一致。
      expect(patch.geoXUrl[GeoResource.MMDB], endsWith('/geoip.metadb'));
      expect(patch.geoXUrl[GeoResource.ASN], endsWith('/GeoLite2-ASN.mmdb'));
      expect(patch.geoXUrl[GeoResource.GEOIP], endsWith('/geoip.dat'));
      expect(patch.geoXUrl[GeoResource.GEOSITE], endsWith('/geosite.dat'));
      for (final url in patch.geoXUrl.values) {
        expect(
          url,
          startsWith(
            'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/',
          ),
        );
      }
    });

    test('geodata 用省内存的加载器', () {
      // 内核默认就是 memconservative（geodata/utils.go:16），官方说明是
      // 给内存有限的设备用的——手机正是这种设备。
      expect(patch.geodataLoader, GeodataLoader.memconservative);
    });

    test('规则模式、混合端口 7890、不开 allow-lan', () {
      expect(patch.mode, Mode.rule);
      expect(patch.mixedPort, 7890);
      expect(patch.allowLan, isFalse);
    });

    test('IPv6 总开关默认开着', () {
      // 官方三处口径一致：内核 DefaultRawConfig 的 IPv6: true
      // （config/config.go:484）、带注释示例 docs/config.yaml:46 的
      // `ipv6: true # 开启 IPv6 总开关`、官方推荐配置 Meta-Docs 的
      // docs/example/conf.md:28。2026-09-03 由 false 改过来。
      expect(patch.ipv6, isTrue);
    });

    test('TCP 并发开着——按官方推荐，不是按内核默认', () {
      // 内核默认是 false（config/config.go:497），但官方推荐配置里明写着开：
      // Meta-Docs 的 docs/example/conf.md:31 `tcp-concurrent: true`。
      // 这条断言存在的意义是拦住"按内核默认改成 false"这个看着很合理的改动。
      expect(patch.tcpConcurrent, isTrue);
    });

    test('默认没有混合端口密码，但免验证网段已经备好', () {
      // authentication 空 = 没设置，不下发（见 common/task.dart）。
      expect(patch.authentication, isEmpty);
      expect(patch.secret, '');
      // 一旦用户设了密码，本机必须免验证，否则安卓的「系统代理」会当场断网——
      // 系统 HTTP 代理没有地方填用户名密码。
      expect(patch.skipAuthPrefixes, ['127.0.0.1/32', '::1/128']);
    });
  });

  group('真正下发给内核的配置', () {
    Future<YamlMap> generate({
      PatchClashConfig patch = const PatchClashConfig(),
      Map<String, dynamic> rawConfig = const {},
    }) async {
      // 真实路径上 rawConfig 是从 YAML/JSON 解出来的，容器类型一律是 dynamic。
      // 直接塞 Dart 字面量会得到 List<int> 这种强类型容器，端口归一化往里写
      // List<String> 就会崩——那是测试搭台的问题，不是被测代码的问题。
      final decoded = await decodeJSONTask<Map<String, dynamic>>(
        await encodeJSONTask(rawConfig),
      );
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 1,
          rawConfig: decoded,
          realPatchConfig: patch,
          overrideDns: true,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'test-ua',
        ),
      );
      return loadYaml(result.a) as YamlMap;
    }

    test('持久化 fake-ip 映射', () async {
      // 官方示例 docs/config.yaml:130-131 原文就是 store-fake-ip: true；
      // 桌面端 template.ts:116 同值。不写的话内核默认 false，
      // 而手机上改任何设置都会重启内核 —— 映射一丢，还握着旧 fake IP 的应用
      // 就会连到内核已经不认识的地址上。
      final config = await generate();
      expect(config['profile']['store-fake-ip'], isTrue);
    });

    test('代理组选择由应用自己记，不交给内核', () async {
      final config = await generate();
      expect(config['profile']['store-selected'], isFalse);
    });

    test('默认不写 nameserver-policy 的占位条目', () async {
      final config = await generate();
      expect(config['dns']['nameserver-policy'], isEmpty);
    });

    test('下发的 fake-ip-filter 一条不少', () async {
      // 刻意重复写一遍字面量而不是拿 `const Dns().fakeIpFilter` 去比：
      // 拿模型自己比模型，改坏模型时两边一起变，这条断言就永远绿。
      final config = await generate();
      expect((config['dns']['fake-ip-filter'] as YamlList).toList(), [
        '*',
        '+.lan',
        '+.local',
        'time.*.com',
        'ntp.*.com',
        '+.market.xiaomi.com',
        'localhost.ptlogin2.qq.com',
      ]);
    });

    test('嗅探关着、订阅也没写时，配置里根本不出现 sniffer', () async {
      // 关掉时一个键都不碰。注意这里必须**显式**写 enable: false——出厂值
      // 2026-09-03 已经改成开了，用 const PatchClashConfig() 就测不到这条路径。
      final config = await generate(
        patch: const PatchClashConfig(sniffer: Sniffer(enable: false)),
      );
      expect(config.containsKey('sniffer'), isFalse);
    });

    test('出厂状态就会下发 sniffer，且含 QUIC', () async {
      // 出厂值改成"开"之后的现状，钉住它。这是 2026-09-03 起对存量用户可见的
      // 行为变化：升级后配置里会多出一整段 sniffer。
      final config = await generate();
      expect(config['sniffer']['enable'], isTrue);
      expect((config['sniffer']['sniff'] as YamlMap).keys.toList(), [
        'HTTP',
        'TLS',
        'QUIC',
      ]);
      expect(
        (config['sniffer']['sniff']['QUIC']['ports'] as YamlList).toList(),
        ['443'],
      );
    });

    test('嗅探关着时，订阅自带的 sniffer 原样保留', () async {
      // 用户把嗅探关掉时，不代表要把订阅里的嗅探配置也删掉——关掉只是"应用这边
      // 不管这一段"。
      final config = await generate(
        patch: const PatchClashConfig(sniffer: Sniffer(enable: false)),
        rawConfig: {
          'sniffer': {
            'enable': true,
            'sniff': {
              'QUIC': {
                'ports': [443],
              },
            },
          },
        },
      );
      expect(config['sniffer']['enable'], isTrue);
      // 端口归一化照旧：内核只吃字符串。
      expect(
        (config['sniffer']['sniff']['QUIC']['ports'] as YamlList).toList(),
        ['443'],
      );
    });

    test('嗅探开着时，把应用这边的整段写进去', () async {
      final config = await generate(
        patch: const PatchClashConfig(sniffer: Sniffer(enable: true)),
        rawConfig: {
          'sniffer': {
            'enable': false,
            'sniff': {
              'QUIC': {
                'ports': [443],
              },
            },
          },
        },
      );
      expect(config['sniffer']['enable'], isTrue);
      expect(config['sniffer']['force-dns-mapping'], isTrue);
      expect(config['sniffer']['parse-pure-ip'], isTrue);
      expect(config['sniffer']['override-destination'], isFalse);
      expect((config['sniffer']['sniff'] as YamlMap).keys.toList(), [
        'HTTP',
        'TLS',
        'QUIC',
      ]);
      expect(
        (config['sniffer']['sniff']['HTTP']['ports'] as YamlList).toList(),
        ['80', '443'],
      );
      // 空列表不能出现在下发的配置里。
      expect(config['sniffer'].containsKey('sniffing'), isFalse);
      expect(config['sniffer'].containsKey('force-domain'), isFalse);
    });

    test('没设混合端口密码时，authentication 一族一个键都不写', () async {
      // 空列表是"界面没设置"不是"设成空"。无条件写下去会把订阅里本来有的验证
      // 顶掉——等于帮用户把门打开。
      final config = await generate(
        rawConfig: {
          'authentication': ['sub:pass'],
        },
      );
      expect((config['authentication'] as YamlList).toList(), ['sub:pass']);
      expect(config.containsKey('skip-auth-prefixes'), isFalse);
    });

    test('设了混合端口密码时，免验证网段跟着一起下发', () async {
      final config = await generate(
        patch: const PatchClashConfig(authentication: ['me:secret']),
        rawConfig: {
          'authentication': ['sub:pass'],
        },
      );
      expect((config['authentication'] as YamlList).toList(), ['me:secret']);
      // 少了这一段，安卓的「系统代理」会当场断网。
      expect((config['skip-auth-prefixes'] as YamlList).toList(), [
        '127.0.0.1/32',
        '::1/128',
      ]);
    });

    test('控制器密钥由界面全权接管，清空要真的能清掉', () async {
      // external-controller 本来就是无条件覆盖的，secret 跟着一起接管；
      // 只在非空时才写的话，用户删掉密钥后订阅里的旧密钥又会冒出来，
      // 界面显示没密码、实际还锁着。
      final cleared = await generate(rawConfig: {'secret': 'from-sub'});
      expect(cleared['secret'], '');

      final set = await generate(
        patch: const PatchClashConfig(secret: 'mine'),
        rawConfig: {'secret': 'from-sub'},
      );
      expect(set['secret'], 'mine');
    });
  });
}
