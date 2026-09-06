import 'package:clash_party/common/smart_routing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Smart 选路开关的双向改写逻辑。
///
/// 钉住的是"拨完开关之后，配置还能被内核吃下去、而且真按用户选的方式选路"——
/// 这件事平时看不出来，坏了也不会有人发现：用户只会看到"配置检查失败"，或者更糟，
/// 什么都不报但选路根本没按设置走，根本联想不到是这里的锅。
///
/// **测的是真跑一遍的结果，不是模板文本**：桌面版那套逻辑分支多（有没有 url-test、
/// 有没有现成 smart 组、有没有节点），只有把配置真的过一遍才知道分支走对没有。
void main() {
  const testUrl = 'https://example.invalid/generate_204';

  /// 按默认设置跑一遍开启逻辑。默认值刻意和桌面版对齐，
  /// 这样"默认下生成什么"这件事本身也被测试钉住了。
  void enable(
    Map<String, dynamic> config, {
    bool useLightGBM = false,
    bool collectData = false,
    String strategy = smartStrategyStickySessions,
    int collectorSize = defaultSmartCollectorSize,
    int tolerance = 0,
    bool preferAsn = false,
    double sampleRate = 1,
  }) {
    enableSmartGroups(
      config,
      useLightGBM: useLightGBM,
      collectData: collectData,
      strategy: strategy,
      collectorSize: collectorSize,
      tolerance: tolerance,
      preferAsn: preferAsn,
      sampleRate: sampleRate,
    );
  }

  List<dynamic> groupsOf(Map<String, dynamic> config) =>
      config['proxy-groups'] as List<dynamic>;

  Map<dynamic, dynamic> groupNamed(Map<String, dynamic> config, String name) =>
      groupsOf(
        config,
      ).whereType<Map>().firstWhere((group) => group['name'] == name);

  group('关掉 Smart 选路', () {
    test('Smart 组变成 url-test，并补齐 url-test 必需的键', () {
      final result = disableSmartGroups([
        {
          'name': '国外代理',
          'type': 'smart',
          'proxies': ['A', 'B'],
        },
      ], testUrl: testUrl);

      final group = result.single as Map;
      expect(group['type'], 'url-test');
      // Smart 组不写 url / interval 也能跑，url-test 不行——不补就是把配置写坏。
      expect(group['url'], testUrl);
      expect(group['interval'], isA<int>());
      expect(group['proxies'], ['A', 'B']);
    });

    test('删掉 url-test 不认识的 Smart 专属键', () {
      final result = disableSmartGroups([
        {
          'name': 'G',
          'type': 'smart',
          'policy-priority': 'A:0.5',
          'uselightgbm': true,
          'collectdata': true,
          'sample-rate': 0.5,
          'prefer-asn': true,
          'strategy': 'sticky-sessions',
          'proxies': ['A'],
        },
      ], testUrl: testUrl);

      final group = result.single as Map;
      for (final key in [
        'policy-priority',
        'uselightgbm',
        'collectdata',
        'sample-rate',
        'prefer-asn',
        'strategy',
      ]) {
        expect(group.containsKey(key), isFalse, reason: '$key 应该被删掉');
      }
    });

    test('tolerance 要保留——它是 url-test 本来就支持的选项', () {
      final result = disableSmartGroups([
        {'name': 'G', 'type': 'smart', 'tolerance': 150},
      ], testUrl: testUrl);

      expect((result.single as Map)['tolerance'], 150);
    });

    test('组里自己写了 url / interval 就不覆盖', () {
      final result = disableSmartGroups([
        {
          'name': 'G',
          'type': 'smart',
          'url': 'https://mine.invalid/204',
          'interval': 60,
        },
      ], testUrl: testUrl);

      final group = result.single as Map;
      expect(group['url'], 'https://mine.invalid/204');
      expect(group['interval'], 60);
    });

    test('不是 Smart 的组一个字都不动', () {
      final original = {
        'name': '手动选择',
        'type': 'select',
        'proxies': ['A'],
      };
      final result = disableSmartGroups([original], testUrl: testUrl);
      expect(identical(result.single, original), isTrue);
    });

    test('从 YAML 读出来的只读 Map 也能改', () {
      // 订阅是 YAML 解析出来的，条目是只读的 YamlMap，直接改会抛异常。
      final yaml =
          loadYaml('''
proxy-groups:
  - name: G
    type: smart
    proxies:
      - A
''')
              as YamlMap;
      final groups = (yaml['proxy-groups'] as YamlList).toList();

      final result = disableSmartGroups(groups, testUrl: testUrl);
      expect((result.single as Map)['type'], 'url-test');
    });

    test('类型名两边有空格、大小写不一致也认得出来', () {
      final result = disableSmartGroups([
        {'name': 'G', 'type': ' Smart '},
      ], testUrl: testUrl);
      expect((result.single as Map)['type'], 'url-test');
    });

    test('列表里混着非 Map 的条目不会崩', () {
      final result = disableSmartGroups([
        'not-a-map',
        {'name': 'G', 'type': 'smart'},
      ], testUrl: testUrl);
      expect(result.first, 'not-a-map');
      expect((result[1] as Map)['type'], 'url-test');
    });
  });

  group('识别订阅里有没有 Smart 组', () {
    test('有就是有', () {
      expect(
        hasSmartGroups([
          {'type': 'select'},
          {'type': 'smart'},
        ]),
        isTrue,
      );
    });

    test('没有就是没有', () {
      expect(
        hasSmartGroups([
          {'type': 'select'},
          {'type': 'url-test'},
        ]),
        isFalse,
      );
    });
  });

  group('策略值收敛', () {
    test('内核认识的两个值原样放过', () {
      expect(
        normalizeSmartStrategy(smartStrategyRoundRobin),
        smartStrategyRoundRobin,
      );
      expect(
        normalizeSmartStrategy(smartStrategyStickySessions),
        smartStrategyStickySessions,
      );
    });

    test('不认识的值回落到默认的粘性会话', () {
      // 原样写进配置的话内核解析失败，整个起不来。
      for (final value in ['', 'Round-Robin', 'made-up', 'smart']) {
        expect(
          normalizeSmartStrategy(value),
          smartStrategyStickySessions,
          reason: '$value 应该回落到默认值',
        );
      }
    });
  });

  group('开启 Smart 选路 · 订阅里有 url-test / load-balance', () {
    Map<String, dynamic> configWithTestGroup() => <String, dynamic>{
      'proxy-groups': [
        {
          'name': '自动选择',
          'type': 'url-test',
          'url': 'https://cp.cloudflare.com/generate_204',
          'interval': 300,
          'lazy': true,
          'tolerance': 150,
          'expected-status': '204',
          'proxies': ['A', 'B'],
        },
        {
          'name': '节点选择',
          'type': 'select',
          'proxies': ['自动选择', 'DIRECT'],
        },
      ],
      'rules': ['DOMAIN,a.invalid,自动选择', 'MATCH,节点选择'],
    };

    test('转成 smart 并加上「(Smart Group)」后缀', () {
      final config = configWithTestGroup();
      enable(config);

      final converted = groupNamed(config, '自动选择$smartGroupNameSuffix');
      expect(converted['type'], 'smart');
      // 没被转换的组一个字都不该动。
      expect(groupNamed(config, '节点选择')['type'], 'select');
    });

    test('删掉 url-test 专有的键——Smart 组不认识它们', () {
      final config = configWithTestGroup();
      enable(config);

      final converted = groupNamed(config, '自动选择$smartGroupNameSuffix');
      for (final key in ['url', 'interval', 'lazy', 'expected-status']) {
        expect(converted.containsKey(key), isFalse, reason: '$key 应该被删掉');
      }
    });

    test('订阅里写的 tolerance 要保住——它是 Smart 组也认的选项', () {
      // 桌面版在这里把 tolerance 一起删了（上游 PR #2112 正是修这个）。
      // 删掉的后果是：用户无论写在订阅里还是在设置里都设不上延迟去抖。
      final config = configWithTestGroup();
      enable(config);

      expect(groupNamed(config, '自动选择$smartGroupNameSuffix')['tolerance'], 150);
    });

    test('设置里的 Smart 选项写进转换出来的组', () {
      final config = configWithTestGroup();
      enable(
        config,
        useLightGBM: true,
        collectData: true,
        strategy: smartStrategyRoundRobin,
      );

      final converted = groupNamed(config, '自动选择$smartGroupNameSuffix');
      expect(converted['uselightgbm'], isTrue);
      expect(converted['collectdata'], isTrue);
      expect(converted['strategy'], smartStrategyRoundRobin);
      expect(converted['policy-priority'], '');
    });

    test('改了名，别的组的 proxies 引用要跟着改', () {
      // 漏改这里内核会报 proxy group not found，整个起不来。
      final config = configWithTestGroup();
      enable(config);

      expect(groupNamed(config, '节点选择')['proxies'], [
        '自动选择$smartGroupNameSuffix',
        'DIRECT',
      ]);
    });

    test('改了名，规则里的策略组目标要跟着改；没改名的规则原样留着', () {
      final config = configWithTestGroup();
      enable(config);

      expect(config['rules'], [
        'DOMAIN,a.invalid,自动选择$smartGroupNameSuffix',
        // 节点选择没改名，这条不该动——这个分支**只改名**，不做规则重定向。
        'MATCH,节点选择',
      ]);
    });

    test('顶层 mode 指着被改名的组时也要跟着改', () {
      final config = configWithTestGroup();
      config['mode'] = '自动选择';
      enable(config);

      expect(config['mode'], '自动选择$smartGroupNameSuffix');
    });

    test('已经带后缀的组不会被重复加后缀', () {
      final config = <String, dynamic>{
        'proxy-groups': [
          {'name': '自动选择$smartGroupNameSuffix', 'type': 'url-test'},
        ],
      };
      enable(config);

      expect(groupNamed(config, '自动选择$smartGroupNameSuffix')['type'], 'smart');
    });

    test('load-balance 和 url-test 一样处理，大小写与空格都认', () {
      final config = <String, dynamic>{
        'proxy-groups': [
          {'name': '负载均衡', 'type': ' Load-Balance '},
        ],
      };
      enable(config);

      expect(groupNamed(config, '负载均衡$smartGroupNameSuffix')['type'], 'smart');
    });
  });

  group('开启 Smart 选路 · 订阅里已经有 Smart 组', () {
    test('只把选项写进去，不改名、不新建组', () {
      final config = <String, dynamic>{
        'proxy-groups': [
          {
            'name': '智能选择',
            'type': 'smart',
            'proxies': ['A'],
          },
        ],
        'proxies': [
          {'name': 'A'},
        ],
        'rules': ['MATCH,智能选择'],
      };
      enable(config, useLightGBM: true);

      expect(groupsOf(config), hasLength(1));
      final smart = groupNamed(config, '智能选择');
      expect(smart['uselightgbm'], isTrue);
      expect(smart['strategy'], smartStrategyStickySessions);
    });

    test('规则重定向指向那个组自己的名字，不是硬编码的 Smart Group', () {
      // 指错名字＝指向一个不存在的组，内核直接起不来。
      final config = <String, dynamic>{
        'proxy-groups': [
          {'name': '智能选择', 'type': 'smart'},
          {'name': '手动', 'type': 'select'},
        ],
        'rules': ['DOMAIN,a.invalid,手动', 'MATCH,手动'],
      };
      enable(config);

      expect(config['rules'], ['DOMAIN,a.invalid,智能选择', 'MATCH,智能选择']);
    });
  });

  group('开启 Smart 选路 · 订阅里什么组都没有', () {
    Map<String, dynamic> configWithProxies() => <String, dynamic>{
      // 故意先放一个手动组：新建的 Smart 组要插在**它前面**。只用空列表测
      // “放最前面”是测不出来的——空列表里 add 和 insert(0) 结果一样。
      'proxy-groups': <dynamic>[
        {
          'name': '手动',
          'type': 'select',
          'proxies': ['A', 'B'],
        },
      ],
      'proxies': [
        {'name': 'A'},
        {'name': 'B'},
      ],
      'rules': [
        'DOMAIN,a.invalid,DIRECT',
        'IP-CIDR,1.1.1.1/32,DIRECT,no-resolve',
        'MATCH,Proxy',
      ],
    };

    test('用全部节点建一个 Smart Group，放在最前面', () {
      final config = configWithProxies();
      enable(config);

      final created = groupsOf(config).first as Map;
      expect(created['name'], defaultSmartGroupName);
      expect(created['type'], 'smart');
      expect(created['proxies'], ['A', 'B']);
    });

    test('规则目标改指向新建的组；DIRECT 这类内置目标不动', () {
      final config = configWithProxies();
      enable(config);

      expect(config['rules'], [
        'DOMAIN,a.invalid,DIRECT',
        // 策略组的位置在第 3 个，no-resolve 是参数不是组名，不能被当成目标。
        'IP-CIDR,1.1.1.1/32,DIRECT,no-resolve',
        'MATCH,$defaultSmartGroupName',
      ]);
    });

    test('嵌套逻辑规则整条跳过——按逗号拆会把它拆坏', () {
      final config = configWithProxies();
      config['rules'] = ['AND,((DOMAIN,a.invalid),(NETWORK,tcp)),Proxy'];
      enable(config);

      expect(config['rules'], ['AND,((DOMAIN,a.invalid),(NETWORK,tcp)),Proxy']);
    });

    test('只有 proxy-providers、没有节点时：不建组，**也绝不改规则**', () {
      // 改了就等于把规则目标指向一个不存在的组，内核直接启动失败。
      final config = <String, dynamic>{
        'proxy-groups': <dynamic>[],
        'proxy-providers': {'机场': <String, dynamic>{}},
        'rules': ['MATCH,Proxy'],
      };
      enable(config);

      expect(groupsOf(config), isEmpty);
      expect(config['rules'], ['MATCH,Proxy']);
    });
  });

  group('开启 Smart 选路 · 选项写到哪一层', () {
    test('数据收集文件大小写在顶层 profile 里，不在代理组里', () {
      final config = <String, dynamic>{
        'proxy-groups': [
          {'name': 'G', 'type': 'smart'},
        ],
      };
      enable(config, collectorSize: 250);

      expect((config['profile'] as Map)['smart-collector-size'], 250);
      expect(
        groupNamed(config, 'G').containsKey('smart-collector-size'),
        isFalse,
      );
    });

    test('已有的 profile 内容不会被顶掉', () {
      final config = <String, dynamic>{
        'profile': {'store-selected': true},
        'proxy-groups': <dynamic>[],
      };
      enable(config);

      expect((config['profile'] as Map)['store-selected'], isTrue);
      expect(
        (config['profile'] as Map)['smart-collector-size'],
        defaultSmartCollectorSize,
      );
    });

    test('保持默认时，三个桌面版没有的组级选项一个都不写', () {
      // 这是"和桌面版生成的配置逐字节一致"的保证：默认值下多写一个键，
      // 存量用户的订阅行为就可能变。
      final config = <String, dynamic>{
        'proxy-groups': [
          {'name': 'G', 'type': 'smart'},
        ],
      };
      enable(config);

      final smart = groupNamed(config, 'G');
      for (final key in ['tolerance', 'prefer-asn', 'sample-rate']) {
        expect(smart.containsKey(key), isFalse, reason: '默认值下不该写 $key');
      }
    });

    test('偏离默认值时才写进组里', () {
      final config = <String, dynamic>{
        'proxy-groups': [
          {'name': 'G', 'type': 'smart'},
        ],
      };
      enable(config, tolerance: 120, preferAsn: true, sampleRate: 0.25);

      final smart = groupNamed(config, 'G');
      expect(smart['tolerance'], 120);
      expect(smart['prefer-asn'], isTrue);
      expect(smart['sample-rate'], 0.25);
    });
  });

  group('开启 Smart 选路 · 输入形状千奇百怪也不能崩', () {
    test('从 YAML 读出来的只读 Map 也能改', () {
      final yaml =
          loadYaml('''
proxy-groups:
  - name: 自动选择
    type: url-test
    url: https://example.invalid/204
    proxies:
      - A
rules:
  - MATCH,自动选择
''')
              as YamlMap;
      final config = <String, dynamic>{
        'proxy-groups': (yaml['proxy-groups'] as YamlList).toList(),
        'rules': (yaml['rules'] as YamlList).toList(),
      };
      enable(config);

      final converted = groupNamed(config, '自动选择$smartGroupNameSuffix');
      expect(converted['type'], 'smart');
      expect(converted.containsKey('url'), isFalse);
      expect(config['rules'], ['MATCH,自动选择$smartGroupNameSuffix']);
    });

    test('代理组列表里混着非 Map 的条目（自定义覆写建的组对象）不会崩', () {
      final config = <String, dynamic>{
        'proxy-groups': <dynamic>[
          'not-a-map',
          {'name': 'G', 'type': 'url-test'},
        ],
      };
      enable(config);

      expect(groupsOf(config).first, 'not-a-map');
      expect(groupNamed(config, 'G$smartGroupNameSuffix')['type'], 'smart');
    });

    test('压根没有 proxy-groups 这个键时安静退出', () {
      final config = <String, dynamic>{
        'rules': ['MATCH,Proxy'],
      };
      enable(config);

      expect(config['rules'], ['MATCH,Proxy']);
    });
  });
}
