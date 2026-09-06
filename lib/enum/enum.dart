// ignore_for_file: constant_identifier_names

import 'dart:io';

import 'package:clash_party/common/context.dart';
import 'package:clash_party/common/system.dart';
import 'package:clash_party/views/dashboard/widgets/widgets.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:clash_party/common/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

enum SupportPlatform {
  Windows,
  MacOS,
  Linux,
  Android;

  static SupportPlatform get currentPlatform {
    if (system.isWindows) {
      return SupportPlatform.Windows;
    } else if (system.isMacOS) {
      return SupportPlatform.MacOS;
    } else if (Platform.isLinux) {
      return SupportPlatform.Linux;
    } else if (system.isAndroid) {
      return SupportPlatform.Android;
    }
    throw 'invalid platform';
  }
}

const desktopPlatforms = [
  SupportPlatform.Linux,
  SupportPlatform.MacOS,
  SupportPlatform.Windows,
];

enum GroupName { GLOBAL }

enum GroupType {
  @JsonValue('select')
  Selector('select'),
  @JsonValue('url-test')
  URLTest('url-test'),
  @JsonValue('fallback')
  Fallback('fallback'),
  @JsonValue('load-balance')
  LoadBalance('load-balance'),
  @JsonValue('relay')
  Relay('relay');

  final String value;

  const GroupType(this.value);

  static GroupType parse(String type) {
    return switch (type.toLowerCase()) {
      'url-test' || 'urltest' => URLTest,
      'select' || 'selector' => Selector,
      'fallback' => Fallback,
      'load-balance' || 'loadbalance' => LoadBalance,
      'relay' => Relay,
      String() => throw UnimplementedError(),
    };
  }
}

extension GroupTypeExtension on GroupType {
  static List<String> get valueList =>
      GroupType.values.map((e) => e.toString().split('.').last).toList();

  bool get isComputedSelected {
    return [GroupType.URLTest, GroupType.Fallback].contains(this);
  }

  static GroupType? getGroupType(String value) {
    final index = GroupTypeExtension.valueList.indexOf(value);
    if (index == -1) return null;
    return GroupType.values[index];
  }
}

enum UsedProxy { GLOBAL, DIRECT, REJECT }

extension UsedProxyExtension on UsedProxy {
  static List<String> get valueList =>
      UsedProxy.values.map((e) => e.toString().split('.').last).toList();

  String get value => UsedProxyExtension.valueList[index];
}

enum Mode { rule, global, direct }

enum ViewMode { mobile, laptop, desktop }

enum LogLevel { debug, info, warning, error, silent }

extension LogLevelExt on LogLevel {
  /// 日志级别的着色。
  ///
  /// info 原来返回 null（＝不着色），但桌面端把 info 画成主色——它是最常见的
  /// 级别，不给颜色的话级别标签整片是灰的，一眼看不出层次。
  Color? color(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (this) {
      LogLevel.silent => colorScheme.outline,
      LogLevel.debug => colorScheme.onSurfaceVariant,
      LogLevel.info => context.styleTokens.accent(colorScheme),
      LogLevel.warning => colorScheme.tertiary,
      LogLevel.error => colorScheme.error,
    };
  }
}

enum TransportProtocol { udp, tcp }

enum TrafficUnit { B, KB, MB, GB, TB }

enum NavigationItemMode { mobile, desktop, more }

enum Network { tcp, udp }

enum ProxiesSortType { none, delay, name }

enum TunStack { gvisor, system, mixed }

enum AccessControlMode { acceptSelected, rejectSelected }

enum AccessSortType { none, name, time }

enum ProfileType { file, url }

enum ResultType {
  @JsonValue(0)
  success,
  @JsonValue(-1)
  error,
}

enum CoreEventType { log, delay, request, loaded, crash, geoUpdate }

enum InvokeMessageType { protect, process }

enum FindProcessMode { always, off }

enum RestoreOption { all, onlyProfiles }

enum ChipType { action, delete }

enum CommonCardType { plain, filled }
//
// extension CommonCardTypeExt on CommonCardType {
//   CommonCardType get variant => CommonCardType.plain;
// }

enum ProxiesLayout { loose, standard, tight }

enum ProxyCardType { expand, shrink, min }

enum DnsMode {
  normal,
  @JsonValue('fake-ip')
  fakeIp,
  @JsonValue('redir-host')
  redirHost,
  hosts,
}

enum ExternalControllerStatus {
  @JsonValue('')
  close(''),
  @JsonValue('127.0.0.1:9090')
  open('127.0.0.1:9090');

  final String value;

  const ExternalControllerStatus(this.value);
}

enum KeyboardModifier {
  alt([PhysicalKeyboardKey.altLeft, PhysicalKeyboardKey.altRight]),
  capsLock([PhysicalKeyboardKey.capsLock]),
  control([PhysicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlRight]),
  fn([PhysicalKeyboardKey.fn]),
  meta([PhysicalKeyboardKey.metaLeft, PhysicalKeyboardKey.metaRight]),
  shift([PhysicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftRight]);

  final List<PhysicalKeyboardKey> physicalKeys;

  const KeyboardModifier(this.physicalKeys);
}

extension KeyboardModifierExt on KeyboardModifier {
  HotKeyModifier toHotKeyModifier() {
    return switch (this) {
      KeyboardModifier.alt => HotKeyModifier.alt,
      KeyboardModifier.capsLock => HotKeyModifier.capsLock,
      KeyboardModifier.control => HotKeyModifier.control,
      KeyboardModifier.fn => HotKeyModifier.fn,
      KeyboardModifier.meta => HotKeyModifier.meta,
      KeyboardModifier.shift => HotKeyModifier.shift,
    };
  }
}

enum HotAction { start, view, mode, proxy, tun }

enum ProxiesIconStyle { none, standard, icon }

enum FontFamily {
  twEmoji('Twemoji'),
  jetBrainsMono('JetBrainsMono'),
  icon('Icons');

  final String value;

  const FontFamily(this.value);
}

enum RouteMode { bypassPrivate, config }

enum AuthorizeCode { none, success, error }

enum TunAuthorizationState { none, authorized, unauthorized }

enum FunctionTag {
  updateConfig,
  setupConfig,
  updateGroups,
  addCheckIpNum,
  applyProfile,
  savePreferences,
  changeProxy,
  checkIp,
  handleWill,
  updateDelay,
  vpnTip,
  autoLaunch,
  renderPause,
  updatePageIndex,
  pageChange,
  proxiesTabChange,
  logs,
  requests,
  autoScrollToEnd,
  loadedProvider,
  saveSharedFile,
  removeProxy,
  suspend,
}

enum DashboardWidget {
  statusHero(
    GridItem(crossAxisCellCount: 8, mainAxisCellCount: 2, child: StatusHero()),
    essential: true,
  ),
  // 曾经这里还有一块 `networkSpeed`（8×2，只画一条速率折线）。它和上面那块
  // 状态总览讲的是同一件事——现在通不通、跑得快不快——却各占两行，首屏一半面积
  // 就没了。2026-09-03 并进 [StatusHero]：曲线沉成卡片背景、速率数字缩到右下角，
  // 详情页的入口挂在那两行数字上。枚举值直接删掉而不是留着：留着就是两个磁贴
  // 显示同一份数据。老存档里的 `networkSpeed` 由 `dashboardWidgetsSafeFormJson`
  // 逐个解码时跳过，不会把用户排好的布局打回默认。
  outboundModeV2(
    GridItem(
      crossAxisCellCount: 8,
      mainAxisCellCount: 1,
      child: OutboundModeV2(),
    ),
  ),
  trafficUsage(
    GridItem(
      crossAxisCellCount: 4,
      mainAxisCellCount: 2,
      child: TrafficUsage(),
    ),
  ),
  networkDetection(
    GridItem(
      crossAxisCellCount: 4,
      mainAxisCellCount: 1,
      child: NetworkDetection(),
    ),
  ),
  tunButton(
    GridItem(crossAxisCellCount: 4, mainAxisCellCount: 1, child: TUNButton()),
    platforms: desktopPlatforms,
  ),
  vpnButton(
    GridItem(crossAxisCellCount: 4, mainAxisCellCount: 1, child: VpnButton()),
    platforms: [SupportPlatform.Android],
  ),
  systemProxyButton(
    GridItem(
      crossAxisCellCount: 4,
      mainAxisCellCount: 1,
      child: SystemProxyButton(),
    ),
    platforms: desktopPlatforms,
  ),
  smartRoutingButton(
    GridItem(
      crossAxisCellCount: 4,
      mainAxisCellCount: 1,
      child: SmartRoutingButton(),
    ),
  ),
  intranetIp(
    GridItem(crossAxisCellCount: 4, mainAxisCellCount: 1, child: IntranetIP()),
  ),
  proxyGroupTile(
    GridItem(
      crossAxisCellCount: 4,
      mainAxisCellCount: 1,
      child: ProxyGroupTile(),
    ),
    essential: true,
  ),
  profileTile(
    GridItem(crossAxisCellCount: 4, mainAxisCellCount: 1, child: ProfileTile()),
    essential: true,
  ),
  // 紧挨着「订阅」放：它干的事就是从自建 Sub-Store 后端往订阅里导东西，
  // 在添加面板里让这两块相邻，用户找的时候不用两头看。
  connectionTile(
    GridItem(
      crossAxisCellCount: 4,
      mainAxisCellCount: 1,
      child: ConnectionTile(),
    ),
  ),
  requestTile(
    GridItem(crossAxisCellCount: 4, mainAxisCellCount: 1, child: RequestTile()),
  ),
  logTile(
    GridItem(crossAxisCellCount: 4, mainAxisCellCount: 1, child: LogTile()),
  ),
  resourceTile(
    GridItem(
      crossAxisCellCount: 4,
      mainAxisCellCount: 1,
      child: ResourceTile(),
    ),
  ),
  settingTile(
    GridItem(crossAxisCellCount: 4, mainAxisCellCount: 1, child: SettingTile()),
    essential: true,
  ),
  memoryInfo(
    GridItem(crossAxisCellCount: 4, mainAxisCellCount: 1, child: MemoryInfo()),
  );

  final GridItem widget;
  final List<SupportPlatform> platforms;

  /// 基础磁贴：不允许删除。
  ///
  /// 手机端没有常驻导航栏，磁贴**就是唯一入口**。把「设置」删掉之后就再也进不去
  /// 设置页，连主题和网络配置都改不了；把「配置」删掉就没法加订阅。这类磁贴一删
  /// 就把自己锁在门外，所以直接不给删。
  final bool essential;

  const DashboardWidget(
    this.widget, {
    this.platforms = SupportPlatform.values,
    this.essential = false,
  });

  /// 从网格项反查是哪个磁贴。
  ///
  /// 不能按 GridItem 本身比对——磁贴支持调尺寸，界面会用新的行列数重新构造
  /// GridItem，此时它已不是枚举里那个常量了。
  ///
  /// 优先看 child 上挂的 `ValueKey<String>`（值就是枚举名）：界面会把磁贴包一层
  /// 尺寸动画壳，包完之后 child 的类型全都一样，只剩这个 key 能认人。没有 key
  /// 时（比如从「添加」面板直接塞进来的原始项）再退回按 child 类型比对。
  static DashboardWidget getDashboardWidget(GridItem gridItem) {
    const dashboardWidgets = DashboardWidget.values;
    final key = gridItem.child.key;
    if (key is ValueKey<String>) {
      final index = dashboardWidgets.indexWhere(
        (item) => item.name == key.value,
      );
      if (index != -1) {
        return dashboardWidgets[index];
      }
    }
    final index = dashboardWidgets.indexWhere(
      (item) => item.widget.child.runtimeType == gridItem.child.runtimeType,
    );
    return dashboardWidgets[index];
  }
}

enum GeodataLoader { standard, memconservative }

enum GeoResource {
  @JsonValue('mmdb')
  MMDB,
  @JsonValue('asn')
  ASN,
  @JsonValue('geoip')
  GEOIP,
  @JsonValue('geosite')
  GEOSITE;

  static GeoResource fromJson(String value) {
    return switch (value) {
      'mmdb' => GeoResource.MMDB,
      'asn' => GeoResource.ASN,
      'geo-ip' || 'geoip' => GeoResource.GEOIP,
      'geo-site' || 'geosite' => GeoResource.GEOSITE,
      _ => throw ArgumentError.value(value, 'value', 'Invalid geo resource'),
    };
  }
}

extension GeoResourceExt on GeoResource {
  String get configKey {
    return switch (this) {
      GeoResource.MMDB => 'mmdb',
      GeoResource.ASN => 'asn',
      GeoResource.GEOIP => 'geoip',
      GeoResource.GEOSITE => 'geosite',
    };
  }

  String get updatingKey => 'geo_resource_$name';
}

enum PageLabel {
  dashboard,
  proxies,
  profiles,
  tools,
  logs,
  requests,
  resources,
  connections,
}

enum RuleAction {
  DOMAIN('DOMAIN'),
  DOMAIN_SUFFIX('DOMAIN-SUFFIX'),
  DOMAIN_KEYWORD('DOMAIN-KEYWORD'),
  DOMAIN_REGEX('DOMAIN-REGEX'),
  GEOSITE('GEOSITE'),
  IP_CIDR('IP-CIDR'),
  IP_CIDR6('IP-CIDR6'),
  IP_SUFFIX('IP-SUFFIX'),
  IP_ASN('IP-ASN'),
  GEOIP('GEOIP'),
  SRC_GEOIP('SRC-GEOIP'),
  SRC_IP_ASN('SRC-IP-ASN'),
  SRC_IP_CIDR('SRC-IP-CIDR'),
  SRC_IP_SUFFIX('SRC-IP-SUFFIX'),
  DST_PORT('DST-PORT'),
  SRC_PORT('SRC-PORT'),
  IN_PORT('IN-PORT'),
  IN_TYPE('IN-TYPE'),
  IN_USER('IN-USER'),
  IN_NAME('IN-NAME'),
  PROCESS_PATH('PROCESS-PATH'),
  PROCESS_PATH_REGEX('PROCESS-PATH-REGEX'),
  PROCESS_NAME('PROCESS-NAME'),
  PROCESS_NAME_REGEX('PROCESS-NAME-REGEX'),
  UID('UID'),
  NETWORK('NETWORK'),
  DSCP('DSCP'),
  RULE_SET('RULE-SET'),
  AND('AND'),
  OR('OR'),
  NOT('NOT'),
  SUB_RULE('SUB-RULE'),
  MATCH('MATCH');

  final String value;

  const RuleAction(this.value);

  static List<RuleAction> get addedRuleActions {
    return RuleAction.values
        .where(
          (item) => ![
            RuleAction.MATCH,
            RuleAction.RULE_SET,
            RuleAction.SUB_RULE,
          ].contains(item),
        )
        .toList();
  }
}

extension RuleActionExt on RuleAction {
  bool get hasParams => [
    RuleAction.GEOIP,
    RuleAction.IP_ASN,
    RuleAction.SRC_IP_ASN,
    RuleAction.IP_CIDR,
    RuleAction.IP_CIDR6,
    RuleAction.IP_SUFFIX,
    RuleAction.RULE_SET,
  ].contains(this);

  String getDesc(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return switch (this) {
      RuleAction.DOMAIN => appLocalizations.ruleActionDomainDesc,
      RuleAction.DOMAIN_SUFFIX => appLocalizations.ruleActionDomainSuffixDesc,
      RuleAction.DOMAIN_KEYWORD => appLocalizations.ruleActionDomainKeywordDesc,
      RuleAction.DOMAIN_REGEX => appLocalizations.ruleActionDomainRegexDesc,
      RuleAction.GEOSITE => appLocalizations.ruleActionGeositeDesc,
      RuleAction.IP_CIDR => appLocalizations.ruleActionIpCidrDesc,
      RuleAction.IP_CIDR6 => appLocalizations.ruleActionIpCidr6Desc,
      RuleAction.IP_SUFFIX => appLocalizations.ruleActionIpSuffixDesc,
      RuleAction.IP_ASN => appLocalizations.ruleActionIpAsnDesc,
      RuleAction.GEOIP => appLocalizations.ruleActionGeoipDesc,
      RuleAction.SRC_GEOIP => appLocalizations.ruleActionSrcGeoipDesc,
      RuleAction.SRC_IP_ASN => appLocalizations.ruleActionSrcIpAsnDesc,
      RuleAction.SRC_IP_CIDR => appLocalizations.ruleActionSrcIpCidrDesc,
      RuleAction.SRC_IP_SUFFIX => appLocalizations.ruleActionSrcIpSuffixDesc,
      RuleAction.DST_PORT => appLocalizations.ruleActionDstPortDesc,
      RuleAction.SRC_PORT => appLocalizations.ruleActionSrcPortDesc,
      RuleAction.IN_PORT => appLocalizations.ruleActionInPortDesc,
      RuleAction.IN_TYPE => appLocalizations.ruleActionInTypeDesc,
      RuleAction.IN_USER => appLocalizations.ruleActionInUserDesc,
      RuleAction.IN_NAME => appLocalizations.ruleActionInNameDesc,
      RuleAction.PROCESS_PATH => appLocalizations.ruleActionProcessPathDesc,
      RuleAction.PROCESS_PATH_REGEX =>
        appLocalizations.ruleActionProcessPathRegexDesc,
      RuleAction.PROCESS_NAME => appLocalizations.ruleActionProcessNameDesc,
      RuleAction.PROCESS_NAME_REGEX =>
        appLocalizations.ruleActionProcessNameRegexDesc,
      RuleAction.UID => appLocalizations.ruleActionUidDesc,
      RuleAction.NETWORK => appLocalizations.ruleActionNetworkDesc,
      RuleAction.DSCP => appLocalizations.ruleActionDscpDesc,
      RuleAction.RULE_SET => appLocalizations.ruleActionRuleSetDesc,
      RuleAction.AND => appLocalizations.ruleActionAndDesc,
      RuleAction.OR => appLocalizations.ruleActionOrDesc,
      RuleAction.NOT => appLocalizations.ruleActionNotDesc,
      RuleAction.SUB_RULE => appLocalizations.ruleActionSubRuleDesc,
      RuleAction.MATCH => appLocalizations.ruleActionMatchDesc,
    };
  }
}

enum OverrideRuleType { override, added }

enum OverwriteType {
  // none,
  standard,
  script,
  custom,
}

enum RuleTarget {
  DIRECT,
  REJECT;

  static Set<String> get baseTargets =>
      RuleTarget.values.map((item) => item.name).toSet();

  // static bool isBaseRuleTarget(String? target) {
  //   return RuleTarget.values.indexWhere(
  //         (item) => item.name == target?.toUpperCase(),
  //       ) !=
  //       -1;
  // }
}

enum RestoreStrategy { compatible, override }

enum CacheTag { logs, rules, requests, proxiesList }

enum Language { yaml, javaScript, json }

enum ImportOption { file, url }

enum ScrollPositionCacheKey { tools, profiles, proxiesList, proxiesTabList }

enum QueryTag { proxies, access }

enum LoadingTag {
  profiles,
  backup_restore,
  access,
  proxies,
  batteryOptimization,
}

enum CoreStatus { connecting, connected, disconnected }

enum RuleScene { added, disabled, custom }

enum ItemPosition {
  start,
  middle,
  end,
  startAndEnd;

  static ItemPosition get(int index, int length) {
    ItemPosition position = ItemPosition.middle;
    if (length == 1) {
      position = ItemPosition.startAndEnd;
    } else if (index == length - 1) {
      position = ItemPosition.end;
    } else if (index == 0) {
      position = ItemPosition.start;
    }
    return position;
  }

  static ItemPosition calculateVisualPosition<T>(
    int currentIndex,
    List<T> items,
    Set<T> deletedItems,
  ) {
    final currentItem = items[currentIndex];
    if (deletedItems.contains(currentItem)) {
      return ItemPosition.middle;
    }
    final int visualLength = items.length - deletedItems.length;
    if (visualLength <= 0) return ItemPosition.middle;
    int deletedCountBeforeMe = 0;
    for (int i = 0; i < currentIndex; i++) {
      if (deletedItems.contains(items[i])) {
        deletedCountBeforeMe++;
      }
    }
    final int visualIndex = currentIndex - deletedCountBeforeMe;
    return ItemPosition.get(visualIndex, visualLength);
  }
}
