import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'models.dart';

part 'generated/config.freezed.dart';
part 'generated/config.g.dart';

const defaultBypassDomain = [
  '*zhihu.com',
  '*zhimg.com',
  '*jd.com',
  '100ime-iat-api.xfyun.cn',
  '*360buyimg.com',
  'localhost',
  '*.local',
  '127.*',
  '10.*',
  '172.16.*',
  '172.17.*',
  '172.18.*',
  '172.19.*',
  '172.2*',
  '172.30.*',
  '172.31.*',
  '192.168.*',
];

const defaultAppSettingProps = AppSettingProps();
const defaultVpnProps = VpnProps();
const defaultNetworkProps = NetworkProps();
const defaultProxiesStyleProps = ProxiesStyleProps();
const defaultWindowProps = WindowProps();
const defaultAccessControlProps = AccessControlProps();
const defaultThemeProps = ThemeProps();

/// 主页磁贴的默认排布。
///
/// **默认把全部磁贴都摆出来**（2026-09-03 用户定的）。此前默认只放六块、其余让
/// 用户自己在编辑模式里加——那条口径已作废。平台过滤会自动生效：安卓看不到
/// TUN / 系统代理这两块桌面专用的，不用在这里操心。
///
/// **顺序就是排版**：网格按顺序往第一个放得下的空位塞，所以这个列表的先后**就是**
/// 最终版面。排的原则是「常用在上、观测在下」，同时尽量让每一行填满：
///
/// 1. 状态总览（整宽两行，含实时网速与波形）
/// 2. 出站模式（整宽一行）
/// 3. 三个「会真的改变流量怎么走」的开关：VPN / TUN / 系统代理 / Smart 选路
/// 4. 常用入口：代理组、订阅、节点、订阅卡片、设置
/// 5. 观测类：流量统计、网络检测、内网 IP、连接、请求、日志、资源、内存
///
/// 8 列的网格里整宽占 8、半宽占 4；流量统计是半宽两行，靠它右边那两块半宽单行
/// 填平。安卓上排出来是这样：
///
/// ```
/// ┌───────────────────────┐
/// │      状态总览 8×2      │   ← 含实时网速与波形
/// ├───────────────────────┤
/// │     出站模式 8×1       │
/// ├───────────┬───────────┤
/// │  VPN 4×1  │ Smart 4×1 │
/// ├───────────┼───────────┤
/// │ 代理组 4×1│  订阅 4×1  │
/// ├───────────┼───────────┤
/// │  节点 4×1 │订阅卡片 4×1│
/// ├───────────┼───────────┤
/// │  设置 4×1 │           │
/// ├───────────┤ 流量统计   │
/// │网络检测4×1│   4×2     │
/// ├───────────┼───────────┤
/// │ 内网IP 4×1│  连接 4×1  │
/// ├───────────┼───────────┤
/// │  请求 4×1 │  日志 4×1  │
/// ├───────────┼───────────┤
/// │  资源 4×1 │  内存 4×1  │
/// └───────────┴───────────┘
/// ```
///
/// **安卓上正好排满 11 行，没有豁口。** 这不是凑出来的：半宽磁贴 14 块加上流量
/// 统计那块两行的，正好是 8 行的量。
///
/// 这个数是**会随磁贴增减而变的**——2026-09-03 去掉 Sub-Store 那块之后，原本半空
/// 的最后一行才变满。所以别把「排满」当成可以永远指望的性质：`default_layout_test`
/// 的口径是「除了最后一行，每一行都必须排满；最后一行允许正好半格」，加减磁贴时
/// 照着它调，**不要为了凑满去删磁贴或改某块磁贴的尺寸**（尺寸是那块磁贴自己的排版
/// 需要，不该被凑数绑架）。
///
/// 桌面端多出 TUN 和系统代理两块、少一块 VPN，行数与此不同，同理不管——本项目
/// 目标平台是安卓。
const List<DashboardWidget> defaultDashboardWidgets = [
  DashboardWidget.statusHero,
  DashboardWidget.outboundModeV2,
  // 开关类。tunButton / systemProxyButton 只在桌面显示，vpnButton 只在安卓显示，
  // 所以两边各自看到的都是「两个开关一行」。
  DashboardWidget.tunButton,
  DashboardWidget.vpnButton,
  DashboardWidget.systemProxyButton,
  DashboardWidget.smartRoutingButton,
  // 常用入口。
  DashboardWidget.proxyGroupTile,
  DashboardWidget.profileTile,
  DashboardWidget.settingTile,
  // 观测类。流量统计占两行，紧跟它的两块半宽单行正好填满右边那一列。
  DashboardWidget.trafficUsage,
  DashboardWidget.networkDetection,
  DashboardWidget.intranetIp,
  DashboardWidget.connectionTile,
  DashboardWidget.requestTile,
  DashboardWidget.logTile,
  DashboardWidget.resourceTile,
  DashboardWidget.memoryInfo,
];

List<DashboardWidget> dashboardWidgetsSafeFormJson(
  List<dynamic>? dashboardWidgets,
) {
  try {
    // **逐个解码、跳过不认识的**，不要整份 map。
    //
    // 磁贴枚举是会变的（这次就删掉了重复的那个出站模式）。原来用 `$enumDecode`
    // 整份 map，只要存档里有一个已经不存在的名字就抛异常 → 落进下面的 catch →
    // **用户精心排的整个首页被打回默认**。跳过单个更符合预期：那一块没了，其余
    // 的原样保留。
    final saved = dashboardWidgets == null
        ? defaultDashboardWidgets
        : <DashboardWidget>[
            for (final raw in dashboardWidgets)
              ?_$DashboardWidgetEnumMap.entries
                  .where((entry) => entry.value == raw)
                  .firstOrNull
                  ?.key,
          ];
    return _withEssentials(saved);
  } catch (_) {
    return defaultDashboardWidgets;
  }
}

/// 把缺掉的基础磁贴补回去。
///
/// 界面上已经不给删基础磁贴了，但**老版本存下来的布局里可能已经缺了**——那种情况
/// 用户会进不去设置页，只能重装。读档时补一次，代价很小。补在末尾，不打乱原有顺序。
List<DashboardWidget> _withEssentials(List<DashboardWidget> widgets) {
  final missing = DashboardWidget.values
      .where((item) => item.essential && !widgets.contains(item))
      .toList();
  if (missing.isEmpty) {
    return widgets;
  }
  return [...widgets, ...missing];
}

@freezed
abstract class AppSettingProps with _$AppSettingProps {
  const factory AppSettingProps({
    String? locale,
    @Default(defaultDashboardWidgets)
    @JsonKey(fromJson: dashboardWidgetsSafeFormJson)
    List<DashboardWidget> dashboardWidgets,

    /// 每个磁贴的宽度（跨几列）。键是 DashboardWidget 的名字，缺省时用枚举里的默认值。
    @Default(<String, int>{}) Map<String, int> dashboardWidgetSpans,
    @Default(<String, int>{}) Map<String, int> dashboardWidgetRows,
    @Default(false) bool onlyStatisticsProxy,

    /// 通知栏那一行要不要显示实时速率。
    ///
    /// **默认真**——以前是恒显示的，默认关掉等于给存量用户改现状。关掉之后通知
    /// 栏只剩订阅名和「停止」按钮，通知本身不会消失（前台服务的通知不能撤）。
    @Default(true) bool showNotificationSpeed,
    @Default(false) bool autoLaunch,
    @Default(false) bool silentLaunch,
    @Default(false) bool autoRun,
    @Default(false) bool openLogs,
    @Default(true) bool closeConnections,
    @Default(defaultTestUrl) String testUrl,
    @Default(true) bool isAnimateToPage,
    @Default(true) bool autoCheckUpdate,
    @Default(false) bool showLabel,
    @Default(false) bool disclaimerAccepted,
    @Default(true) bool minimizeOnExit,
    @Default(false) bool hidden,
    @Default(false) bool developerMode,
    @Default(RestoreStrategy.compatible) RestoreStrategy restoreStrategy,
    @Default(true) bool showTrayTitle,
    @Default('') String customUserAgent,
    @Default(false) bool allowInsecureCertificate,

    /// 是否使用 Smart 选路。对应桌面版的 `enableSmartOverride`。
    ///
    /// 打包的内核是 Smart 版（= 官方内核 + Smart 功能），这个开关不换内核，只改
    /// 配置：开着就照桌面版 `smartOverride.ts` 的规则把订阅里的 url-test /
    /// load-balance 组转成 Smart 组并写入下面几个选项；关掉则反过来，把
    /// `type: smart` 的组改写成 `url-test`——选路回到"谁快选谁"的传统行为。
    /// 这样既省下第二个内核的 62 MB，也不用维护第二份内核分支。
    ///
    /// **默认关闭**，对齐的是桌面版的实际效果，不是它的字段值。
    ///
    /// 桌面版 `enableSmartOverride` 字段确实默认 true，但它外面还套着一层默认
    /// false 的 `enableSmartCore`，两个都开才会真的改写配置——桌面端用户必须先
    /// 主动开一次总闸。安卓端没有这层闸，字段照抄成 true 就等于"升级即改写存量
    /// 订阅"。
    ///
    /// 而这个改写是有破坏性的：开着时会把订阅里的 url-test / load-balance 组
    /// 改名加 `(Smart Group)` 后缀；订阅里没有这类组时，还会新建一个
    /// `Smart Group` 并把规则里的目标统统改指向它（见 `common/smart_routing.dart`）。
    /// 用户一个按钮都没点，就发现代理组名字变了、规则指向变了，是不能接受的。
    @Default(false) bool smartRouting,

    /// 是否让 Smart 组用预训练的 LightGBM 模型选路。
    ///
    /// **默认开**：Smart 的全部意义就是用训练好的模型选路，关掉它就退回启发式
    /// 打分——开了 Smart 又不用模型，等于白开。模型文件不在时内核会自己下载。
    ///
    /// 桌面版这个字段默认关，这里不照抄：桌面端的 Smart 总闸和这一项是分开两次
    /// 决策，而这里总闸（[smartRouting]）本来就默认关，用户主动打开时理应拿到
    /// 完整形态的 Smart，而不是一个被阉了一半的。
    @Default(true) bool smartUseLightGBM,

    /// 是否收集本机的网络使用数据（用来训练自己的模型）。
    /// 桌面版对应字段 `smartCoreCollectData`，默认关。
    @Default(false) bool smartCollectData,

    /// 数据收集文件的大小上限，单位 MB。
    /// 桌面版对应字段 `smartCollectorSize`，默认 100。
    @Default(defaultSmartCollectorSize) int smartCollectorSize,

    /// Smart 组的策略模式：`sticky-sessions`（粘性会话）或 `round-robin`（轮询）。
    /// 桌面版对应字段 `smartCoreStrategy`，默认粘性会话。
    ///
    /// 存字符串而不是枚举，是为了和桌面版写进配置里的值逐字节一致。
    @Default(smartStrategyStickySessions) String smartStrategy,

    /// 延迟去抖：两个节点延迟差不超过这个毫秒数时视为一样快，保持原顺序不换。
    ///
    /// **桌面版没有这一项**，是内核本来就支持的组级选项
    /// （`adapter/outboundgroup/smart.go` 的 `SmartOption.Tolerance`）。
    /// **默认 150 毫秒**，取自内核自带示例配置里同语义选项给的值
    /// （`docs/config.yaml:1723`）。留 0 的话两个节点差 1 毫秒也要换，手机网络
    /// 抖动大会导致反复横跳。推导与依据见 [defaultSmartTolerance]。
    @Default(defaultSmartTolerance) int smartTolerance,

    /// 目标 ASN 未知时，是否额外做一次解析把它补出来，让 Smart 按"目标属于哪个
    /// 运营商"归纳经验。代价是未知目标要多一次查询。
    ///
    /// **桌面版没有这一项**，默认关＝不写这个键。
    @Default(false) bool smartPreferAsn,

    /// 训练数据采样率，取值 (0, 1]。只影响"收集数据"写盘的量，**与选路无关**。
    ///
    /// **桌面版没有这一项**，默认 1＝全采样，等于不写这个键。
    @Default(1.0) double smartSampleRate,

    /// 让内核自己定期下载 / 更新 Smart 的模型文件（内核 `lgbm-auto-update`）。
    ///
    /// **这三个 lgbm 选项是全局顶层键，不是代理组级的**（内核
    /// `config/config.go` 的 `RawConfig` 直接挂着它们），写进代理组里不生效。
    /// 组级的是 tolerance / prefer-asn / sample-rate。
    ///
    /// **默认开**：模型会过期，而流量这一头已经有闸——[smartLgbmWifiOnly]
    /// 默认开着，只有当前确实在 Wi-Fi 上才会真的下发 `lgbm-auto-update: true`，
    /// 不会偷跑蜂窝流量。
    ///
    /// 下错地址也不会损坏现有模型：内核先下到临时文件、真正加载一遍验过才落盘
    /// （`component/updater/update_lgbm.go`）。
    @Default(true) bool smartLgbmAutoUpdate,

    /// 自动更新的间隔，单位小时。内核默认 72。
    @Default(defaultSmartLgbmInterval) int smartLgbmUpdateInterval,

    /// 模型下载地址（内核 `lgbm-url`）。留空＝用内核内置的那个地址。
    ///
    /// 填不同的地址可以选模型大小：标准版约 9 MB、中等约 18 MB、大号约 26 MB。
    /// 填错了不会损坏现有模型——内核先下到临时文件并真正加载一遍，验不过就不落盘。
    @Default('') String smartLgbmUrl,

    /// 只在 Wi-Fi 下更新模型。**默认开**。
    ///
    /// **内核自己做不到这件事**：下载是内核发起的，它不知道当前走的是 Wi-Fi 还是
    /// 蜂窝。所以这道闸在应用侧——只有当前确实在 Wi-Fi 上时，才把
    /// `lgbm-auto-update` 按 true 下发；切到流量就按 false 下发。
    /// 判断逻辑见 [SmartOptions.lgbmAutoUpdateNow]。
    @Default(true) bool smartLgbmWifiOnly,
  }) = _AppSettingProps;

  factory AppSettingProps.fromJson(Map<String, Object?> json) =>
      _$AppSettingPropsFromJson(json);

  factory AppSettingProps.safeFromJson(Map<String, Object?>? json) {
    try {
      return json == null
          ? defaultAppSettingProps
          : AppSettingProps.fromJson(json);
    } catch (_) {
      return defaultAppSettingProps;
    }
  }
}

/// 生成配置时用到的全部 Smart 选路设置，打成一个包传给 `makeRealProfileTask`。
///
/// 单独立一个类而不是往 `MakeRealProfileState` 里塞八个字段：这些值总是一起用、
/// 一起变，以后加内核新选项时也只动这一处。
@freezed
abstract class SmartOptions with _$SmartOptions {
  const factory SmartOptions({
    /// 见 [AppSettingProps.smartRouting]。为假时把 Smart 组改写回 url-test。
    ///
    /// 默认跟着 [AppSettingProps.smartRouting] 一起是 false：这个类只在
    /// `MakeRealProfileState` 没显式带 smart 时兜底，兜底值必须是"不改写用户配置"
    /// 的那一侧。
    @Default(false) bool enable,
    @Default(false) bool useLightGBM,
    @Default(false) bool collectData,
    @Default(defaultSmartCollectorSize) int collectorSize,
    @Default(smartStrategyStickySessions) String strategy,
    @Default(0) int tolerance,
    @Default(false) bool preferAsn,
    @Default(1.0) double sampleRate,

    /// 关掉 Smart 时改写出来的 url-test 组，组里没写 `url` 就用它兜底。
    @Default(defaultTestUrl) String testUrl,

    /// 见 [AppSettingProps.smartLgbmAutoUpdate] 等三项。这三个是**全局顶层键**。
    @Default(false) bool lgbmAutoUpdate,
    @Default(defaultSmartLgbmInterval) int lgbmUpdateInterval,
    @Default('') String lgbmUrl,
    @Default(true) bool lgbmWifiOnly,

    /// 当前是不是连着 Wi-Fi。**运行时状态，不是用户设置**，由
    /// `providers/state.dart` 的 smartOptionsState 从连接类型填进来。
    @Default(false) bool onWifi,
  }) = _SmartOptions;
}

extension SmartOptionsExt on SmartOptions {
  /// **现在**要不要让内核自动更新模型。
  ///
  /// 「仅 Wi-Fi」是应用侧的闸：内核不知道自己走的是 Wi-Fi 还是流量，所以只能由
  /// 这边决定要不要把 `lgbm-auto-update` 下发成 true。切到蜂窝网络时下发 false，
  /// 内核那个后台更新器就不会启动。
  bool get lgbmAutoUpdateNow => lgbmAutoUpdate && (!lgbmWifiOnly || onWifi);
}

extension AppSettingPropsSmartExt on AppSettingProps {
  /// [onWifi] 是运行时的网络类型，不在设置里，所以得从外面传进来——
  /// 「仅 Wi-Fi 更新」那道闸要用它。
  SmartOptions smartOptionsOn({required bool onWifi}) =>
      smartOptions.copyWith(onWifi: onWifi);

  SmartOptions get smartOptions => SmartOptions(
    enable: smartRouting,
    useLightGBM: smartUseLightGBM,
    collectData: smartCollectData,
    collectorSize: smartCollectorSize,
    // 存档里可能是内核不认识的值，原样写进配置内核会起不来。
    strategy: normalizeSmartStrategy(smartStrategy),
    tolerance: smartTolerance,
    preferAsn: smartPreferAsn,
    // 采样率只管"收集数据"写盘的量，没开收集时它没有任何意义——
    // 这里直接归位成 1，免得关着收集还往配置里写一个 sample-rate。
    sampleRate: smartCollectData ? smartSampleRate : 1,
    testUrl: testUrl,
    lgbmAutoUpdate: smartLgbmAutoUpdate,
    lgbmUpdateInterval: smartLgbmUpdateInterval,
    lgbmUrl: smartLgbmUrl,
    lgbmWifiOnly: smartLgbmWifiOnly,
  );
}

@freezed
abstract class AccessControlProps with _$AccessControlProps {
  const factory AccessControlProps({
    @Default(false) bool enable,
    @Default(AccessControlMode.rejectSelected) AccessControlMode mode,
    @Default([]) List<String> acceptList,
    @Default([]) List<String> rejectList,
    @Default(AccessSortType.none) AccessSortType sort,
    @Default(true) bool isFilterSystemApp,
    @Default(true) bool isFilterNonInternetApp,
  }) = _AccessControlProps;

  factory AccessControlProps.fromJson(Map<String, Object?> json) =>
      _$AccessControlPropsFromJson(json);
}

extension AccessControlPropsExt on AccessControlProps {
  List<String> get currentList => switch (mode) {
    AccessControlMode.acceptSelected => acceptList,
    AccessControlMode.rejectSelected => rejectList,
  };

  AccessControlProps copyWithNewList(List<String> value) => switch (mode) {
    AccessControlMode.acceptSelected => copyWith(acceptList: value),
    AccessControlMode.rejectSelected => copyWith(rejectList: value),
  };
}

@freezed
abstract class WindowProps with _$WindowProps {
  const factory WindowProps({
    @Default(0) double width,
    @Default(0) double height,
    double? top,
    double? left,
  }) = _WindowProps;

  factory WindowProps.fromJson(Map<String, Object?>? json) =>
      json == null ? const WindowProps() : _$WindowPropsFromJson(json);
}

extension WindowPropsExt on WindowProps {
  Size get _size => Size(width, height);

  Size get size => _size.isEmpty ? const Size(680, 580) : _size;
}

@freezed
abstract class VpnProps with _$VpnProps {
  const factory VpnProps({
    @Default(true) bool enable,
    @Default(true) bool systemProxy,

    /// VPN 隧道口本身要不要 IPv6。
    ///
    /// **2026-09-03 由 false 改成 true，和内核总开关 [PatchClashConfig.ipv6]
    /// 一起翻**——这两个必须同进同退。安卓侧 `VpnService.kt:172-183` 把 IPv6
    /// 地址（`fdfe:dcba:9876::1/126`）、`::/0` 路由、IPv6 DNS 三样一起锁在
    /// `if (options.ipv6)` 里；内核开着而这里关着，应用会一直试 IPv6 一直
    /// ENETUNREACH，只能靠 Happy Eyeballs 超时回落到 IPv4，纯粹变慢。
    ///
    /// 设备本身不支持 IPv6 时不会出事：`VpnService.kt:175-178` 那次
    /// `addAddress` 外面有 try/catch，失败只记一行
    /// "IPv6 VPN address is not supported"。
    @Default(true) bool ipv6,
    @Default(true) bool allowBypass,
    @Default(false) bool dnsHijacking,
    @Default(defaultAccessControlProps) AccessControlProps accessControlProps,
  }) = _VpnProps;

  factory VpnProps.fromJson(Map<String, Object?>? json) =>
      json == null ? defaultVpnProps : _$VpnPropsFromJson(json);
}

@freezed
abstract class NetworkProps with _$NetworkProps {
  const factory NetworkProps({
    @Default(true) bool systemProxy,
    @Default(defaultBypassDomain) List<String> bypassDomain,
    @Default(RouteMode.config) RouteMode routeMode,
    @Default(true) bool autoSetSystemDns,
    @Default(false) bool appendSystemDns,
  }) = _NetworkProps;

  factory NetworkProps.fromJson(Map<String, Object?>? json) =>
      json == null ? const NetworkProps() : _$NetworkPropsFromJson(json);
}

@freezed
abstract class ProxiesStyleProps with _$ProxiesStyleProps {
  const factory ProxiesStyleProps({
    // Clash Party 桌面版的「代理组与节点」是一行一个组的列表，不是标签页。
    // 列表模式每行会显示「类型 · 当前节点」，与桌面端一致。
    @Default(ProxiesSortType.none) ProxiesSortType sortType,
    @Default(ProxiesLayout.standard) ProxiesLayout layout,
    @Default(ProxiesIconStyle.standard) ProxiesIconStyle iconStyle,
    @Default(ProxyCardType.expand) ProxyCardType cardType,
  }) = _ProxiesStyleProps;

  factory ProxiesStyleProps.fromJson(Map<String, Object?>? json) => json == null
      ? defaultProxiesStyleProps
      : _$ProxiesStylePropsFromJson(json);
}

@freezed
abstract class TextScale with _$TextScale {
  const factory TextScale({
    @Default(false) bool enable,
    @Default(1.0) double scale,
  }) = _TextScale;

  factory TextScale.fromJson(Map<String, Object?> json) =>
      _$TextScaleFromJson(json);
}

@freezed
abstract class ThemeProps with _$ThemeProps {
  const factory ThemeProps({
    @Default(ThemeMode.dark) ThemeMode themeMode,

    /// **必须走 `safeFromJson`。** 生成的解码对认不出的枚举值会直接抛；
    /// 「Material You」那一档删掉之后，用过它的机器存档里还留着那个名字，不兜底
    /// 的话整份配置读不出来——用户看到的是应用起不来，而不是"风格变回默认"。
    @JsonKey(fromJson: AppStyle.safeFromJson)
    @Default(AppStyle.clashParty)
    AppStyle appStyle,
    @Default(TextScale()) TextScale textScale,
  }) = _ThemeProps;

  factory ThemeProps.fromJson(Map<String, Object?> json) =>
      _$ThemePropsFromJson(json);

  factory ThemeProps.safeFromJson(Map<String, Object?>? json) {
    if (json == null) {
      return defaultThemeProps;
    }
    try {
      return ThemeProps.fromJson(json);
    } catch (_) {
      return defaultThemeProps;
    }
  }
}

@freezed
abstract class Config with _$Config {
  const factory Config({
    int? currentProfileId,
    @Default(false) bool overrideDns,
    @Default([]) List<HotKeyAction> hotKeyActions,
    @JsonKey(fromJson: AppSettingProps.safeFromJson)
    @Default(defaultAppSettingProps)
    AppSettingProps appSettingProps,
    DAVProps? davProps,
    @Default(defaultNetworkProps) NetworkProps networkProps,
    @Default(defaultVpnProps) VpnProps vpnProps,
    @JsonKey(fromJson: ThemeProps.safeFromJson) required ThemeProps themeProps,
    @Default(defaultProxiesStyleProps) ProxiesStyleProps proxiesStyleProps,
    @Default(defaultWindowProps) WindowProps windowProps,
    @Default(defaultClashConfig) PatchClashConfig patchClashConfig,
    @Default([]) List<String> excludeSSIDs,
  }) = _Config;

  factory Config.fromJson(Map<String, Object?> json) => _$ConfigFromJson(json);

  factory Config.realFromJson(Map<String, Object?>? json) {
    if (json == null) {
      return const Config(themeProps: defaultThemeProps);
    }
    return _$ConfigFromJson(json);
  }
}
