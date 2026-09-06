/// Smart 选路开关：决定订阅里的代理组按哪套规则挑节点。
///
/// **为什么是改配置而不是换内核**：本应用打包的内核是 vernesong 的 Smart 版，它
/// 等于官方内核**加上** Smart 功能（两边版本号同为 1.10.0，官方独有的文件只有几个
/// 测试/占位文件）。所以"换成官方内核"给用户带不来任何新东西，只会少掉 Smart，
/// 却要多背 62 MB 体积和一份需要长期手工维护的内核分支。
///
/// 用户真正想要的是"走不走 Smart 选路"，那在配置层就能做到，内核仍然只有一个：
///
/// * **关**——[disableSmartGroups]：把 `type: smart` 的组换成 `url-test`，
///   选路回到"谁快选谁"的传统行为；
/// * **开**——[enableSmartGroups]：把订阅里的 url-test / load-balance 组转成
///   Smart 组，并把用户在设置里选的 Smart 选项写进去。
///
/// 开的那一半是**照抄桌面版** `src/main/config/smartOverride.ts` 里
/// `generateSmartOverrideTemplate` 生成的那段脚本。桌面版把逻辑写成一段 JS 覆写
/// 丢进内核前的处理链；安卓端没有那条覆写链，就把同一套逻辑直接用 Dart 写在配置
/// 定稿的最后一步。**两边的分支、判定顺序、生成的键完全一致**，改一边时请对着
/// 另一边看。
///
/// 顺带解决了另一件事：如果哪天真要换官方内核，官方内核**不认** `type: smart`，
/// 配置会直接解析失败——也就是说这层改写本来就是必需的。
library;

/// Smart 组独有、url-test 不认识的键。
///
/// 改写时必须删掉：mihomo 解析组选项时字段对不上会报错，留着就等于把配置写坏。
/// 各键的含义见 vernesong 内核 `adapter/outboundgroup/smart.go`。
const _smartOnlyKeys = <String>{
  'policy-priority',
  'uselightgbm',
  'collectdata',
  'sample-rate',
  'prefer-asn',
  'strategy',
};

/// url-test 组必须要有的键，Smart 组不一定写了。
const _fallbackInterval = 300;

/// 把 [groups] 里所有 Smart 组改写成 url-test 组，其它组原样返回。
///
/// [testUrl] 是组里没写 `url` 时用的兜底测速地址，传应用设置里的那个。
///
/// **只处理 Map 形式的条目**。列表里也可能是已经建好模型的 `ProxyGroup` 对象
/// （用户在覆写里自己编的组），那些对象的类型枚举里根本没有 smart 这一项，不可能
/// 是 Smart 组，原样放过即可。
List<dynamic> disableSmartGroups(
  List<dynamic> groups, {
  required String testUrl,
}) {
  var changed = false;
  final result = <dynamic>[];
  for (final group in groups) {
    if (group is! Map) {
      result.add(group);
      continue;
    }
    final type = group['type'];
    if (type is! String || type.trim().toLowerCase() != 'smart') {
      result.add(group);
      continue;
    }
    changed = true;
    // 从 YAML 读出来的可能是只读的 YamlMap，必须复制一份再改。
    final rewritten = _mutableMap(group);
    rewritten['type'] = 'url-test';
    rewritten.removeWhere((key, _) => _smartOnlyKeys.contains(key));
    // `tolerance` 不在删除名单里——它是 url-test 本来就支持的延迟去抖选项，
    // Smart 组也支持，语义一致，留着正好保住用户原来的设置。
    if (rewritten['url'] is! String || (rewritten['url'] as String).isEmpty) {
      rewritten['url'] = testUrl;
    }
    if (rewritten['interval'] is! int) {
      rewritten['interval'] = _fallbackInterval;
    }
    result.add(rewritten);
  }
  // 一个 Smart 组都没有时返回原列表，避免白白复制一遍。
  return changed ? result : groups;
}

/// [groups] 里有没有 Smart 组。
///
/// 用来决定要不要在界面上提示"这份订阅用到了 Smart 选路"。
bool hasSmartGroups(List<dynamic> groups) {
  for (final group in groups) {
    if (group is Map &&
        group['type'] is String &&
        (group['type'] as String).trim().toLowerCase() == 'smart') {
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// 开启 Smart 选路：照抄桌面版 smartOverride.ts
// ---------------------------------------------------------------------------

/// 内核认识的两种 Smart 策略，见 `adapter/outboundgroup/smart.go`。
const smartStrategyStickySessions = 'sticky-sessions';
const smartStrategyRoundRobin = 'round-robin';

/// 设置界面里能选的策略，顺序就是界面上的顺序（和桌面版一致）。
const smartStrategies = <String>[
  smartStrategyStickySessions,
  smartStrategyRoundRobin,
];

/// 把存档里的策略值收敛成内核认识的那两个之一。
///
/// 存档里可能是个内核不认识的值——从桌面版同步过来的旧配置、手工改过的配置文件、
/// 或者以后内核改了名字。原样写进配置的话内核会解析失败、整个起不来；界面上也会
/// 出现"一个选项都没选中"的空白下拉。**读到这个值的地方都要先过一遍这里。**
String normalizeSmartStrategy(String value) {
  return smartStrategies.contains(value) ? value : smartStrategyStickySessions;
}

/// 数据收集文件大小上限，单位 MB。桌面版默认值就是 100。
const defaultSmartCollectorSize = 100;

/// 自动新建的 Smart 组叫这个名字。桌面版硬编码为 `Smart Group`，它的提示文案里
/// 也直接写了这个名字（"如果使用全局模式，请选择名称为 Smart Group 的节点"），
/// **不能改**。
const defaultSmartGroupName = 'Smart Group';

/// 由 url-test / load-balance 转过来的组会加这个后缀，桌面版同款。
const smartGroupNameSuffix = '(Smart Group)';

/// 规则里跟在策略组后面的参数，它们不是策略组名。
const _ruleParams = <String>{'no-resolve', 'force-remote-dns', 'prefer-ipv6'};

/// 内核内置的规则目标，不该被替换成策略组。
const _builtinRuleTargets = <String>{
  'DIRECT',
  'REJECT',
  'REJECT-DROP',
  'PASS',
  'COMPATIBLE',
};

/// 把 YAML 读出来的只读 Map 复制成可改的普通 Map。
Map<String, dynamic> _mutableMap(Map source) {
  return Map<String, dynamic>.from(
    source.map((key, value) => MapEntry(key.toString(), value)),
  );
}

/// 规则字符串里策略组名所在的位置，找不到返回 -1。
///
/// 规则有两种形状：`MATCH,策略组` 和 `类型,匹配内容,策略组[,参数...]`。
/// 后者的策略组不一定就在第 3 个位置——前面可能夹着 `no-resolve` 这类参数，
/// 所以要从第 3 个开始往后找第一个"不是参数"的。
int _ruleTargetIndex(List<String> parts) {
  if (parts.length < 2) return -1;
  if (parts[0] == 'MATCH' && parts.length == 2) return 1;
  if (parts.length >= 3) {
    for (var i = 2; i < parts.length; i++) {
      if (!_ruleParams.contains(parts[i])) return i;
    }
  }
  return -1;
}

/// 用 [rewrite] 改写一条规则的策略组目标；[rewrite] 返回 null 表示这条不用改。
dynamic _rewriteRuleTarget(dynamic rule, String? Function(String) rewrite) {
  if (rule is String) {
    final parts = rule.split(',').map((part) => part.trim()).toList();
    final index = _ruleTargetIndex(parts);
    if (index == -1) return rule;
    final next = rewrite(parts[index]);
    if (next == null) return rule;
    parts[index] = next;
    return parts.join(',');
  }
  if (rule is Map) {
    final field = rule['target'] != null
        ? 'target'
        : (rule['proxy'] != null ? 'proxy' : null);
    if (field == null) return rule;
    final value = rule[field];
    if (value is! String) return rule;
    final next = rewrite(value);
    if (next == null) return rule;
    final rewritten = _mutableMap(rule);
    rewritten[field] = next;
    return rewritten;
  }
  return rule;
}

/// 按用户在设置里选的 Smart 选项改写整份 [config]。
///
/// 调用点必须放在 `proxy-groups` 和 `rules` **都已经定稿之后**——这个函数两处都
/// 会改，早一步执行就会被后面的赋值整个盖掉。
///
/// 三个分支和桌面版一一对应：
/// 1. 订阅里有 url-test / load-balance 组 → 只做类型转换（并改掉所有引用），
///    **到此为止**，不碰规则目标；
/// 2. 没有，但已经有 Smart 组 → 只把选项写进那个组；
/// 3. 两样都没有但有节点 → 新建一个包含全部节点的 `Smart Group` 放到最前面。
///    分支 2、3 结束后会把规则的策略组目标统统改指向那个 Smart 组。
///
/// [tolerance]、[preferAsn]、[sampleRate] 是桌面版当前没有的三个组级选项
/// （见 `adapter/outboundgroup/smart.go`）。**只在偏离内核默认值时才写入**，
/// 所以保持默认时生成的配置与桌面版逐字节一致，订阅里已有的同名设置也不会被顶掉。
/// 参数是 `Map<dynamic, dynamic>` 而不是 `Map<String, dynamic>`：`task.dart` 里
/// 的配置是 `Map.from(...)` 复制出来的，静态类型就是前者，收窄反而要在调用点多拷
/// 一份、还会丢掉"就地改"的语义。
void enableSmartGroups(
  Map<dynamic, dynamic> config, {
  required bool useLightGBM,
  required bool collectData,
  required String strategy,
  required int collectorSize,
  int tolerance = 0,
  bool preferAsn = false,
  double sampleRate = 1,
}) {
  // profile.smart-collector-size 是**顶层**选项，不在代理组里。
  final profile = config['profile'];
  final nextProfile = profile is Map
      ? _mutableMap(profile)
      : <String, dynamic>{};
  nextProfile['smart-collector-size'] = collectorSize;
  config['profile'] = nextProfile;

  final rawGroups = config['proxy-groups'];
  if (rawGroups is! List) return;
  // 先把每个 Map 组复制成可改的——YAML 解析出来的是只读的 YamlMap，而下面几乎
  // 每条分支都要往组里写东西。非 Map 的条目（自定义覆写建的 `ProxyGroup` 对象）
  // 原样留着：它的类型枚举里没有 smart，不可能是目标。
  final groups = rawGroups
      .map((group) => group is Map ? _mutableMap(group) : group)
      .toList();
  config['proxy-groups'] = groups;

  void applySmartOptions(Map<String, dynamic> group) {
    // policy-priority: <1 降权、>1 提权，默认 1，支持正则与字符串。
    // 桌面版只在为空时补一个空串，等于"把这个键摆出来给用户看"，不改语义。
    final priority = group['policy-priority'];
    if (priority == null || priority == '' || priority == false) {
      group['policy-priority'] = '';
    }
    group['uselightgbm'] = useLightGBM;
    group['collectdata'] = collectData;
    group['strategy'] = strategy;
    // 下面三个只在偏离内核默认值时才写，理由见函数文档。
    if (tolerance > 0) group['tolerance'] = tolerance;
    if (preferAsn) group['prefer-asn'] = true;
    if (sampleRate > 0 && sampleRate < 1) group['sample-rate'] = sampleRate;
  }

  final hasUrlTestOrLoadBalance = groups.any((group) {
    if (group is! Map) return false;
    final type = group['type'];
    if (type is! String) return false;
    final normalized = type.trim().toLowerCase();
    return normalized == 'url-test' || normalized == 'load-balance';
  });

  if (hasUrlTestOrLoadBalance) {
    _convertTestGroups(config, groups, applySmartOptions);
    return;
  }

  // 没有 url-test / load-balance：找现成的 Smart 组，找不到就建一个。
  //
  // smartGroupName 记录「实际存在且可被规则引用」的组名：命中已有组时是它自己的
  // 名字，新建时才是 'Smart Group'。规则替换必须用这个名字，否则会指向不存在的组。
  String? smartGroupName;
  for (final group in groups) {
    if (group is! Map<String, dynamic>) continue;
    final type = group['type'];
    if (type is! String || type.trim().toLowerCase() != 'smart') continue;
    applySmartOptions(group);
    final name = group['name'];
    if (name is String) smartGroupName = name;
    break;
  }

  if (smartGroupName == null) {
    final proxies = config['proxies'];
    final proxyNames = proxies is List
        ? proxies
              .whereType<Map>()
              .map((proxy) => proxy['name'])
              .whereType<String>()
              .toList()
        : const <String>[];
    if (proxyNames.isNotEmpty) {
      final smartGroup = <String, dynamic>{
        'name': defaultSmartGroupName,
        'type': 'smart',
        'proxies': proxyNames,
      };
      applySmartOptions(smartGroup);
      groups.insert(0, smartGroup);
      smartGroupName = defaultSmartGroupName;
    }
  }

  // 只有确实存在可引用的 Smart 组时才改规则。否则（订阅只有 proxy-providers、
  // 没有顶层 proxies，因而没能建组）会把规则目标指向一个不存在的组，
  // **内核直接启动失败**。
  if (smartGroupName == null) return;
  final rules = config['rules'];
  if (rules is! List) return;

  final groupNames = groups
      .whereType<Map>()
      .map((group) => group['name'])
      .whereType<String>()
      .toSet();
  final target = smartGroupName;

  config['rules'] = rules.map((rule) {
    // 带括号的是嵌套逻辑规则（AND/OR/NOT），拆逗号会把它拆坏，整条跳过。
    if (rule is String && (rule.contains('((') || rule.contains('))'))) {
      return rule;
    }
    return _rewriteRuleTarget(rule, (value) {
      if (value.isEmpty) return null;
      if (_builtinRuleTargets.contains(value)) return null;
      if (!groupNames.contains(value) && _ruleParams.contains(value)) {
        return null;
      }
      return target;
    });
  }).toList();
}

/// 分支 1：把 url-test / load-balance 组就地转成 Smart 组，并改掉所有引用。
///
/// 转换会给组名加 `(Smart Group)` 后缀，所以**引用也得跟着改**——别的组的
/// `proxies` 列表、规则的策略组目标、顶层的 `mode`。漏改一处内核就会报
/// "proxy group not found" 起不来。
void _convertTestGroups(
  Map<dynamic, dynamic> config,
  List<dynamic> groups,
  void Function(Map<String, dynamic> group) applySmartOptions,
) {
  final nameMapping = <String, String>{};
  for (final group in groups) {
    if (group is! Map<String, dynamic>) continue;
    final type = group['type'];
    if (type is! String) continue;
    final normalized = type.trim().toLowerCase();
    if (normalized != 'url-test' && normalized != 'load-balance') continue;

    group['type'] = 'smart';
    final originalName = group['name'];
    if (originalName is String &&
        !originalName.contains(smartGroupNameSuffix)) {
      final newName = '$originalName$smartGroupNameSuffix';
      group['name'] = newName;
      nameMapping[originalName] = newName;
    }
    // **先删 url-test 专有键、再写 Smart 选项**，顺序不能反：`tolerance` 两边
    // 都认（Smart 组用它做延迟去抖），先写后删会把用户设的值又抹掉。桌面版正是
    // 反着来的，那是个已知缺陷（上游 PR #2112）。
    group.remove('url');
    group.remove('interval');
    group.remove('lazy');
    // 桌面版这里写的是 `if (group.expected_status) delete group['expected-status']`
    // ——判定用下划线、删除用中划线，实际订阅里的键是中划线，那条基本不生效。
    // 这里两种写法都删掉。
    group.remove('expected-status');
    group.remove('expected_status');
    applySmartOptions(group);
  }

  if (nameMapping.isEmpty) return;

  // 别的组的 proxies 列表里可能引用了被改名的组。
  for (final group in groups) {
    if (group is! Map<String, dynamic>) continue;
    final proxies = group['proxies'];
    if (proxies is! List) continue;
    if (!proxies.any(
      (name) => name is String && nameMapping.containsKey(name),
    )) {
      continue;
    }
    group['proxies'] = proxies
        .map((name) => name is String ? (nameMapping[name] ?? name) : name)
        .toList();
  }

  final rules = config['rules'];
  if (rules is List) {
    config['rules'] = rules
        .map((rule) => _rewriteRuleTarget(rule, (value) => nameMapping[value]))
        .toList();
  }

  for (final field in const ['mode', 'proxy-mode']) {
    final value = config[field];
    if (value is String && nameMapping.containsKey(value)) {
      config[field] = nameMapping[value];
    }
  }
}
