// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppSettingProps {

 String? get locale;@JsonKey(fromJson: dashboardWidgetsSafeFormJson) List<DashboardWidget> get dashboardWidgets;/// 每个磁贴的宽度（跨几列）。键是 DashboardWidget 的名字，缺省时用枚举里的默认值。
 Map<String, int> get dashboardWidgetSpans; Map<String, int> get dashboardWidgetRows; bool get onlyStatisticsProxy;/// 通知栏那一行要不要显示实时速率。
///
/// **默认真**——以前是恒显示的，默认关掉等于给存量用户改现状。关掉之后通知
/// 栏只剩订阅名和「停止」按钮，通知本身不会消失（前台服务的通知不能撤）。
 bool get showNotificationSpeed; bool get autoLaunch; bool get silentLaunch; bool get autoRun; bool get openLogs; bool get closeConnections; String get testUrl; bool get isAnimateToPage; bool get autoCheckUpdate; bool get showLabel; bool get disclaimerAccepted; bool get minimizeOnExit; bool get hidden; bool get developerMode; RestoreStrategy get restoreStrategy; bool get showTrayTitle; String get customUserAgent; bool get allowInsecureCertificate;/// 是否使用 Smart 选路。对应桌面版的 `enableSmartOverride`。
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
 bool get smartRouting;/// 是否让 Smart 组用预训练的 LightGBM 模型选路。
///
/// **默认开**：Smart 的全部意义就是用训练好的模型选路，关掉它就退回启发式
/// 打分——开了 Smart 又不用模型，等于白开。模型文件不在时内核会自己下载。
///
/// 桌面版这个字段默认关，这里不照抄：桌面端的 Smart 总闸和这一项是分开两次
/// 决策，而这里总闸（[smartRouting]）本来就默认关，用户主动打开时理应拿到
/// 完整形态的 Smart，而不是一个被阉了一半的。
 bool get smartUseLightGBM;/// 是否收集本机的网络使用数据（用来训练自己的模型）。
/// 桌面版对应字段 `smartCoreCollectData`，默认关。
 bool get smartCollectData;/// 数据收集文件的大小上限，单位 MB。
/// 桌面版对应字段 `smartCollectorSize`，默认 100。
 int get smartCollectorSize;/// Smart 组的策略模式：`sticky-sessions`（粘性会话）或 `round-robin`（轮询）。
/// 桌面版对应字段 `smartCoreStrategy`，默认粘性会话。
///
/// 存字符串而不是枚举，是为了和桌面版写进配置里的值逐字节一致。
 String get smartStrategy;/// 延迟去抖：两个节点延迟差不超过这个毫秒数时视为一样快，保持原顺序不换。
///
/// **桌面版没有这一项**，是内核本来就支持的组级选项
/// （`adapter/outboundgroup/smart.go` 的 `SmartOption.Tolerance`）。
/// **默认 150 毫秒**，取自内核自带示例配置里同语义选项给的值
/// （`docs/config.yaml:1723`）。留 0 的话两个节点差 1 毫秒也要换，手机网络
/// 抖动大会导致反复横跳。推导与依据见 [defaultSmartTolerance]。
 int get smartTolerance;/// 目标 ASN 未知时，是否额外做一次解析把它补出来，让 Smart 按"目标属于哪个
/// 运营商"归纳经验。代价是未知目标要多一次查询。
///
/// **桌面版没有这一项**，默认关＝不写这个键。
 bool get smartPreferAsn;/// 训练数据采样率，取值 (0, 1]。只影响"收集数据"写盘的量，**与选路无关**。
///
/// **桌面版没有这一项**，默认 1＝全采样，等于不写这个键。
 double get smartSampleRate;/// 让内核自己定期下载 / 更新 Smart 的模型文件（内核 `lgbm-auto-update`）。
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
 bool get smartLgbmAutoUpdate;/// 自动更新的间隔，单位小时。内核默认 72。
 int get smartLgbmUpdateInterval;/// 模型下载地址（内核 `lgbm-url`）。留空＝用内核内置的那个地址。
///
/// 填不同的地址可以选模型大小：标准版约 9 MB、中等约 18 MB、大号约 26 MB。
/// 填错了不会损坏现有模型——内核先下到临时文件并真正加载一遍，验不过就不落盘。
 String get smartLgbmUrl;/// 只在 Wi-Fi 下更新模型。**默认开**。
///
/// **内核自己做不到这件事**：下载是内核发起的，它不知道当前走的是 Wi-Fi 还是
/// 蜂窝。所以这道闸在应用侧——只有当前确实在 Wi-Fi 上时，才把
/// `lgbm-auto-update` 按 true 下发；切到流量就按 false 下发。
/// 判断逻辑见 [SmartOptions.lgbmAutoUpdateNow]。
 bool get smartLgbmWifiOnly;
/// Create a copy of AppSettingProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingPropsCopyWith<AppSettingProps> get copyWith => _$AppSettingPropsCopyWithImpl<AppSettingProps>(this as AppSettingProps, _$identity);

  /// Serializes this AppSettingProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettingProps&&(identical(other.locale, locale) || other.locale == locale)&&const DeepCollectionEquality().equals(other.dashboardWidgets, dashboardWidgets)&&const DeepCollectionEquality().equals(other.dashboardWidgetSpans, dashboardWidgetSpans)&&const DeepCollectionEquality().equals(other.dashboardWidgetRows, dashboardWidgetRows)&&(identical(other.onlyStatisticsProxy, onlyStatisticsProxy) || other.onlyStatisticsProxy == onlyStatisticsProxy)&&(identical(other.showNotificationSpeed, showNotificationSpeed) || other.showNotificationSpeed == showNotificationSpeed)&&(identical(other.autoLaunch, autoLaunch) || other.autoLaunch == autoLaunch)&&(identical(other.silentLaunch, silentLaunch) || other.silentLaunch == silentLaunch)&&(identical(other.autoRun, autoRun) || other.autoRun == autoRun)&&(identical(other.openLogs, openLogs) || other.openLogs == openLogs)&&(identical(other.closeConnections, closeConnections) || other.closeConnections == closeConnections)&&(identical(other.testUrl, testUrl) || other.testUrl == testUrl)&&(identical(other.isAnimateToPage, isAnimateToPage) || other.isAnimateToPage == isAnimateToPage)&&(identical(other.autoCheckUpdate, autoCheckUpdate) || other.autoCheckUpdate == autoCheckUpdate)&&(identical(other.showLabel, showLabel) || other.showLabel == showLabel)&&(identical(other.disclaimerAccepted, disclaimerAccepted) || other.disclaimerAccepted == disclaimerAccepted)&&(identical(other.minimizeOnExit, minimizeOnExit) || other.minimizeOnExit == minimizeOnExit)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.developerMode, developerMode) || other.developerMode == developerMode)&&(identical(other.restoreStrategy, restoreStrategy) || other.restoreStrategy == restoreStrategy)&&(identical(other.showTrayTitle, showTrayTitle) || other.showTrayTitle == showTrayTitle)&&(identical(other.customUserAgent, customUserAgent) || other.customUserAgent == customUserAgent)&&(identical(other.allowInsecureCertificate, allowInsecureCertificate) || other.allowInsecureCertificate == allowInsecureCertificate)&&(identical(other.smartRouting, smartRouting) || other.smartRouting == smartRouting)&&(identical(other.smartUseLightGBM, smartUseLightGBM) || other.smartUseLightGBM == smartUseLightGBM)&&(identical(other.smartCollectData, smartCollectData) || other.smartCollectData == smartCollectData)&&(identical(other.smartCollectorSize, smartCollectorSize) || other.smartCollectorSize == smartCollectorSize)&&(identical(other.smartStrategy, smartStrategy) || other.smartStrategy == smartStrategy)&&(identical(other.smartTolerance, smartTolerance) || other.smartTolerance == smartTolerance)&&(identical(other.smartPreferAsn, smartPreferAsn) || other.smartPreferAsn == smartPreferAsn)&&(identical(other.smartSampleRate, smartSampleRate) || other.smartSampleRate == smartSampleRate)&&(identical(other.smartLgbmAutoUpdate, smartLgbmAutoUpdate) || other.smartLgbmAutoUpdate == smartLgbmAutoUpdate)&&(identical(other.smartLgbmUpdateInterval, smartLgbmUpdateInterval) || other.smartLgbmUpdateInterval == smartLgbmUpdateInterval)&&(identical(other.smartLgbmUrl, smartLgbmUrl) || other.smartLgbmUrl == smartLgbmUrl)&&(identical(other.smartLgbmWifiOnly, smartLgbmWifiOnly) || other.smartLgbmWifiOnly == smartLgbmWifiOnly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,locale,const DeepCollectionEquality().hash(dashboardWidgets),const DeepCollectionEquality().hash(dashboardWidgetSpans),const DeepCollectionEquality().hash(dashboardWidgetRows),onlyStatisticsProxy,showNotificationSpeed,autoLaunch,silentLaunch,autoRun,openLogs,closeConnections,testUrl,isAnimateToPage,autoCheckUpdate,showLabel,disclaimerAccepted,minimizeOnExit,hidden,developerMode,restoreStrategy,showTrayTitle,customUserAgent,allowInsecureCertificate,smartRouting,smartUseLightGBM,smartCollectData,smartCollectorSize,smartStrategy,smartTolerance,smartPreferAsn,smartSampleRate,smartLgbmAutoUpdate,smartLgbmUpdateInterval,smartLgbmUrl,smartLgbmWifiOnly]);

@override
String toString() {
  return 'AppSettingProps(locale: $locale, dashboardWidgets: $dashboardWidgets, dashboardWidgetSpans: $dashboardWidgetSpans, dashboardWidgetRows: $dashboardWidgetRows, onlyStatisticsProxy: $onlyStatisticsProxy, showNotificationSpeed: $showNotificationSpeed, autoLaunch: $autoLaunch, silentLaunch: $silentLaunch, autoRun: $autoRun, openLogs: $openLogs, closeConnections: $closeConnections, testUrl: $testUrl, isAnimateToPage: $isAnimateToPage, autoCheckUpdate: $autoCheckUpdate, showLabel: $showLabel, disclaimerAccepted: $disclaimerAccepted, minimizeOnExit: $minimizeOnExit, hidden: $hidden, developerMode: $developerMode, restoreStrategy: $restoreStrategy, showTrayTitle: $showTrayTitle, customUserAgent: $customUserAgent, allowInsecureCertificate: $allowInsecureCertificate, smartRouting: $smartRouting, smartUseLightGBM: $smartUseLightGBM, smartCollectData: $smartCollectData, smartCollectorSize: $smartCollectorSize, smartStrategy: $smartStrategy, smartTolerance: $smartTolerance, smartPreferAsn: $smartPreferAsn, smartSampleRate: $smartSampleRate, smartLgbmAutoUpdate: $smartLgbmAutoUpdate, smartLgbmUpdateInterval: $smartLgbmUpdateInterval, smartLgbmUrl: $smartLgbmUrl, smartLgbmWifiOnly: $smartLgbmWifiOnly)';
}


}

/// @nodoc
abstract mixin class $AppSettingPropsCopyWith<$Res>  {
  factory $AppSettingPropsCopyWith(AppSettingProps value, $Res Function(AppSettingProps) _then) = _$AppSettingPropsCopyWithImpl;
@useResult
$Res call({
 String? locale,@JsonKey(fromJson: dashboardWidgetsSafeFormJson) List<DashboardWidget> dashboardWidgets, Map<String, int> dashboardWidgetSpans, Map<String, int> dashboardWidgetRows, bool onlyStatisticsProxy, bool showNotificationSpeed, bool autoLaunch, bool silentLaunch, bool autoRun, bool openLogs, bool closeConnections, String testUrl, bool isAnimateToPage, bool autoCheckUpdate, bool showLabel, bool disclaimerAccepted, bool minimizeOnExit, bool hidden, bool developerMode, RestoreStrategy restoreStrategy, bool showTrayTitle, String customUserAgent, bool allowInsecureCertificate, bool smartRouting, bool smartUseLightGBM, bool smartCollectData, int smartCollectorSize, String smartStrategy, int smartTolerance, bool smartPreferAsn, double smartSampleRate, bool smartLgbmAutoUpdate, int smartLgbmUpdateInterval, String smartLgbmUrl, bool smartLgbmWifiOnly
});




}
/// @nodoc
class _$AppSettingPropsCopyWithImpl<$Res>
    implements $AppSettingPropsCopyWith<$Res> {
  _$AppSettingPropsCopyWithImpl(this._self, this._then);

  final AppSettingProps _self;
  final $Res Function(AppSettingProps) _then;

/// Create a copy of AppSettingProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locale = freezed,Object? dashboardWidgets = null,Object? dashboardWidgetSpans = null,Object? dashboardWidgetRows = null,Object? onlyStatisticsProxy = null,Object? showNotificationSpeed = null,Object? autoLaunch = null,Object? silentLaunch = null,Object? autoRun = null,Object? openLogs = null,Object? closeConnections = null,Object? testUrl = null,Object? isAnimateToPage = null,Object? autoCheckUpdate = null,Object? showLabel = null,Object? disclaimerAccepted = null,Object? minimizeOnExit = null,Object? hidden = null,Object? developerMode = null,Object? restoreStrategy = null,Object? showTrayTitle = null,Object? customUserAgent = null,Object? allowInsecureCertificate = null,Object? smartRouting = null,Object? smartUseLightGBM = null,Object? smartCollectData = null,Object? smartCollectorSize = null,Object? smartStrategy = null,Object? smartTolerance = null,Object? smartPreferAsn = null,Object? smartSampleRate = null,Object? smartLgbmAutoUpdate = null,Object? smartLgbmUpdateInterval = null,Object? smartLgbmUrl = null,Object? smartLgbmWifiOnly = null,}) {
  return _then(_self.copyWith(
locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,dashboardWidgets: null == dashboardWidgets ? _self.dashboardWidgets : dashboardWidgets // ignore: cast_nullable_to_non_nullable
as List<DashboardWidget>,dashboardWidgetSpans: null == dashboardWidgetSpans ? _self.dashboardWidgetSpans : dashboardWidgetSpans // ignore: cast_nullable_to_non_nullable
as Map<String, int>,dashboardWidgetRows: null == dashboardWidgetRows ? _self.dashboardWidgetRows : dashboardWidgetRows // ignore: cast_nullable_to_non_nullable
as Map<String, int>,onlyStatisticsProxy: null == onlyStatisticsProxy ? _self.onlyStatisticsProxy : onlyStatisticsProxy // ignore: cast_nullable_to_non_nullable
as bool,showNotificationSpeed: null == showNotificationSpeed ? _self.showNotificationSpeed : showNotificationSpeed // ignore: cast_nullable_to_non_nullable
as bool,autoLaunch: null == autoLaunch ? _self.autoLaunch : autoLaunch // ignore: cast_nullable_to_non_nullable
as bool,silentLaunch: null == silentLaunch ? _self.silentLaunch : silentLaunch // ignore: cast_nullable_to_non_nullable
as bool,autoRun: null == autoRun ? _self.autoRun : autoRun // ignore: cast_nullable_to_non_nullable
as bool,openLogs: null == openLogs ? _self.openLogs : openLogs // ignore: cast_nullable_to_non_nullable
as bool,closeConnections: null == closeConnections ? _self.closeConnections : closeConnections // ignore: cast_nullable_to_non_nullable
as bool,testUrl: null == testUrl ? _self.testUrl : testUrl // ignore: cast_nullable_to_non_nullable
as String,isAnimateToPage: null == isAnimateToPage ? _self.isAnimateToPage : isAnimateToPage // ignore: cast_nullable_to_non_nullable
as bool,autoCheckUpdate: null == autoCheckUpdate ? _self.autoCheckUpdate : autoCheckUpdate // ignore: cast_nullable_to_non_nullable
as bool,showLabel: null == showLabel ? _self.showLabel : showLabel // ignore: cast_nullable_to_non_nullable
as bool,disclaimerAccepted: null == disclaimerAccepted ? _self.disclaimerAccepted : disclaimerAccepted // ignore: cast_nullable_to_non_nullable
as bool,minimizeOnExit: null == minimizeOnExit ? _self.minimizeOnExit : minimizeOnExit // ignore: cast_nullable_to_non_nullable
as bool,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,developerMode: null == developerMode ? _self.developerMode : developerMode // ignore: cast_nullable_to_non_nullable
as bool,restoreStrategy: null == restoreStrategy ? _self.restoreStrategy : restoreStrategy // ignore: cast_nullable_to_non_nullable
as RestoreStrategy,showTrayTitle: null == showTrayTitle ? _self.showTrayTitle : showTrayTitle // ignore: cast_nullable_to_non_nullable
as bool,customUserAgent: null == customUserAgent ? _self.customUserAgent : customUserAgent // ignore: cast_nullable_to_non_nullable
as String,allowInsecureCertificate: null == allowInsecureCertificate ? _self.allowInsecureCertificate : allowInsecureCertificate // ignore: cast_nullable_to_non_nullable
as bool,smartRouting: null == smartRouting ? _self.smartRouting : smartRouting // ignore: cast_nullable_to_non_nullable
as bool,smartUseLightGBM: null == smartUseLightGBM ? _self.smartUseLightGBM : smartUseLightGBM // ignore: cast_nullable_to_non_nullable
as bool,smartCollectData: null == smartCollectData ? _self.smartCollectData : smartCollectData // ignore: cast_nullable_to_non_nullable
as bool,smartCollectorSize: null == smartCollectorSize ? _self.smartCollectorSize : smartCollectorSize // ignore: cast_nullable_to_non_nullable
as int,smartStrategy: null == smartStrategy ? _self.smartStrategy : smartStrategy // ignore: cast_nullable_to_non_nullable
as String,smartTolerance: null == smartTolerance ? _self.smartTolerance : smartTolerance // ignore: cast_nullable_to_non_nullable
as int,smartPreferAsn: null == smartPreferAsn ? _self.smartPreferAsn : smartPreferAsn // ignore: cast_nullable_to_non_nullable
as bool,smartSampleRate: null == smartSampleRate ? _self.smartSampleRate : smartSampleRate // ignore: cast_nullable_to_non_nullable
as double,smartLgbmAutoUpdate: null == smartLgbmAutoUpdate ? _self.smartLgbmAutoUpdate : smartLgbmAutoUpdate // ignore: cast_nullable_to_non_nullable
as bool,smartLgbmUpdateInterval: null == smartLgbmUpdateInterval ? _self.smartLgbmUpdateInterval : smartLgbmUpdateInterval // ignore: cast_nullable_to_non_nullable
as int,smartLgbmUrl: null == smartLgbmUrl ? _self.smartLgbmUrl : smartLgbmUrl // ignore: cast_nullable_to_non_nullable
as String,smartLgbmWifiOnly: null == smartLgbmWifiOnly ? _self.smartLgbmWifiOnly : smartLgbmWifiOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettingProps].
extension AppSettingPropsPatterns on AppSettingProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettingProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettingProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettingProps value)  $default,){
final _that = this;
switch (_that) {
case _AppSettingProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettingProps value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettingProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? locale, @JsonKey(fromJson: dashboardWidgetsSafeFormJson)  List<DashboardWidget> dashboardWidgets,  Map<String, int> dashboardWidgetSpans,  Map<String, int> dashboardWidgetRows,  bool onlyStatisticsProxy,  bool showNotificationSpeed,  bool autoLaunch,  bool silentLaunch,  bool autoRun,  bool openLogs,  bool closeConnections,  String testUrl,  bool isAnimateToPage,  bool autoCheckUpdate,  bool showLabel,  bool disclaimerAccepted,  bool minimizeOnExit,  bool hidden,  bool developerMode,  RestoreStrategy restoreStrategy,  bool showTrayTitle,  String customUserAgent,  bool allowInsecureCertificate,  bool smartRouting,  bool smartUseLightGBM,  bool smartCollectData,  int smartCollectorSize,  String smartStrategy,  int smartTolerance,  bool smartPreferAsn,  double smartSampleRate,  bool smartLgbmAutoUpdate,  int smartLgbmUpdateInterval,  String smartLgbmUrl,  bool smartLgbmWifiOnly)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettingProps() when $default != null:
return $default(_that.locale,_that.dashboardWidgets,_that.dashboardWidgetSpans,_that.dashboardWidgetRows,_that.onlyStatisticsProxy,_that.showNotificationSpeed,_that.autoLaunch,_that.silentLaunch,_that.autoRun,_that.openLogs,_that.closeConnections,_that.testUrl,_that.isAnimateToPage,_that.autoCheckUpdate,_that.showLabel,_that.disclaimerAccepted,_that.minimizeOnExit,_that.hidden,_that.developerMode,_that.restoreStrategy,_that.showTrayTitle,_that.customUserAgent,_that.allowInsecureCertificate,_that.smartRouting,_that.smartUseLightGBM,_that.smartCollectData,_that.smartCollectorSize,_that.smartStrategy,_that.smartTolerance,_that.smartPreferAsn,_that.smartSampleRate,_that.smartLgbmAutoUpdate,_that.smartLgbmUpdateInterval,_that.smartLgbmUrl,_that.smartLgbmWifiOnly);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? locale, @JsonKey(fromJson: dashboardWidgetsSafeFormJson)  List<DashboardWidget> dashboardWidgets,  Map<String, int> dashboardWidgetSpans,  Map<String, int> dashboardWidgetRows,  bool onlyStatisticsProxy,  bool showNotificationSpeed,  bool autoLaunch,  bool silentLaunch,  bool autoRun,  bool openLogs,  bool closeConnections,  String testUrl,  bool isAnimateToPage,  bool autoCheckUpdate,  bool showLabel,  bool disclaimerAccepted,  bool minimizeOnExit,  bool hidden,  bool developerMode,  RestoreStrategy restoreStrategy,  bool showTrayTitle,  String customUserAgent,  bool allowInsecureCertificate,  bool smartRouting,  bool smartUseLightGBM,  bool smartCollectData,  int smartCollectorSize,  String smartStrategy,  int smartTolerance,  bool smartPreferAsn,  double smartSampleRate,  bool smartLgbmAutoUpdate,  int smartLgbmUpdateInterval,  String smartLgbmUrl,  bool smartLgbmWifiOnly)  $default,) {final _that = this;
switch (_that) {
case _AppSettingProps():
return $default(_that.locale,_that.dashboardWidgets,_that.dashboardWidgetSpans,_that.dashboardWidgetRows,_that.onlyStatisticsProxy,_that.showNotificationSpeed,_that.autoLaunch,_that.silentLaunch,_that.autoRun,_that.openLogs,_that.closeConnections,_that.testUrl,_that.isAnimateToPage,_that.autoCheckUpdate,_that.showLabel,_that.disclaimerAccepted,_that.minimizeOnExit,_that.hidden,_that.developerMode,_that.restoreStrategy,_that.showTrayTitle,_that.customUserAgent,_that.allowInsecureCertificate,_that.smartRouting,_that.smartUseLightGBM,_that.smartCollectData,_that.smartCollectorSize,_that.smartStrategy,_that.smartTolerance,_that.smartPreferAsn,_that.smartSampleRate,_that.smartLgbmAutoUpdate,_that.smartLgbmUpdateInterval,_that.smartLgbmUrl,_that.smartLgbmWifiOnly);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? locale, @JsonKey(fromJson: dashboardWidgetsSafeFormJson)  List<DashboardWidget> dashboardWidgets,  Map<String, int> dashboardWidgetSpans,  Map<String, int> dashboardWidgetRows,  bool onlyStatisticsProxy,  bool showNotificationSpeed,  bool autoLaunch,  bool silentLaunch,  bool autoRun,  bool openLogs,  bool closeConnections,  String testUrl,  bool isAnimateToPage,  bool autoCheckUpdate,  bool showLabel,  bool disclaimerAccepted,  bool minimizeOnExit,  bool hidden,  bool developerMode,  RestoreStrategy restoreStrategy,  bool showTrayTitle,  String customUserAgent,  bool allowInsecureCertificate,  bool smartRouting,  bool smartUseLightGBM,  bool smartCollectData,  int smartCollectorSize,  String smartStrategy,  int smartTolerance,  bool smartPreferAsn,  double smartSampleRate,  bool smartLgbmAutoUpdate,  int smartLgbmUpdateInterval,  String smartLgbmUrl,  bool smartLgbmWifiOnly)?  $default,) {final _that = this;
switch (_that) {
case _AppSettingProps() when $default != null:
return $default(_that.locale,_that.dashboardWidgets,_that.dashboardWidgetSpans,_that.dashboardWidgetRows,_that.onlyStatisticsProxy,_that.showNotificationSpeed,_that.autoLaunch,_that.silentLaunch,_that.autoRun,_that.openLogs,_that.closeConnections,_that.testUrl,_that.isAnimateToPage,_that.autoCheckUpdate,_that.showLabel,_that.disclaimerAccepted,_that.minimizeOnExit,_that.hidden,_that.developerMode,_that.restoreStrategy,_that.showTrayTitle,_that.customUserAgent,_that.allowInsecureCertificate,_that.smartRouting,_that.smartUseLightGBM,_that.smartCollectData,_that.smartCollectorSize,_that.smartStrategy,_that.smartTolerance,_that.smartPreferAsn,_that.smartSampleRate,_that.smartLgbmAutoUpdate,_that.smartLgbmUpdateInterval,_that.smartLgbmUrl,_that.smartLgbmWifiOnly);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppSettingProps implements AppSettingProps {
  const _AppSettingProps({this.locale, @JsonKey(fromJson: dashboardWidgetsSafeFormJson) final  List<DashboardWidget> dashboardWidgets = defaultDashboardWidgets, final  Map<String, int> dashboardWidgetSpans = const <String, int>{}, final  Map<String, int> dashboardWidgetRows = const <String, int>{}, this.onlyStatisticsProxy = false, this.showNotificationSpeed = true, this.autoLaunch = false, this.silentLaunch = false, this.autoRun = false, this.openLogs = false, this.closeConnections = true, this.testUrl = defaultTestUrl, this.isAnimateToPage = true, this.autoCheckUpdate = true, this.showLabel = false, this.disclaimerAccepted = false, this.minimizeOnExit = true, this.hidden = false, this.developerMode = false, this.restoreStrategy = RestoreStrategy.compatible, this.showTrayTitle = true, this.customUserAgent = '', this.allowInsecureCertificate = false, this.smartRouting = false, this.smartUseLightGBM = true, this.smartCollectData = false, this.smartCollectorSize = defaultSmartCollectorSize, this.smartStrategy = smartStrategyStickySessions, this.smartTolerance = defaultSmartTolerance, this.smartPreferAsn = false, this.smartSampleRate = 1.0, this.smartLgbmAutoUpdate = true, this.smartLgbmUpdateInterval = defaultSmartLgbmInterval, this.smartLgbmUrl = '', this.smartLgbmWifiOnly = true}): _dashboardWidgets = dashboardWidgets,_dashboardWidgetSpans = dashboardWidgetSpans,_dashboardWidgetRows = dashboardWidgetRows;
  factory _AppSettingProps.fromJson(Map<String, dynamic> json) => _$AppSettingPropsFromJson(json);

@override final  String? locale;
 final  List<DashboardWidget> _dashboardWidgets;
@override@JsonKey(fromJson: dashboardWidgetsSafeFormJson) List<DashboardWidget> get dashboardWidgets {
  if (_dashboardWidgets is EqualUnmodifiableListView) return _dashboardWidgets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dashboardWidgets);
}

/// 每个磁贴的宽度（跨几列）。键是 DashboardWidget 的名字，缺省时用枚举里的默认值。
 final  Map<String, int> _dashboardWidgetSpans;
/// 每个磁贴的宽度（跨几列）。键是 DashboardWidget 的名字，缺省时用枚举里的默认值。
@override@JsonKey() Map<String, int> get dashboardWidgetSpans {
  if (_dashboardWidgetSpans is EqualUnmodifiableMapView) return _dashboardWidgetSpans;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_dashboardWidgetSpans);
}

 final  Map<String, int> _dashboardWidgetRows;
@override@JsonKey() Map<String, int> get dashboardWidgetRows {
  if (_dashboardWidgetRows is EqualUnmodifiableMapView) return _dashboardWidgetRows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_dashboardWidgetRows);
}

@override@JsonKey() final  bool onlyStatisticsProxy;
/// 通知栏那一行要不要显示实时速率。
///
/// **默认真**——以前是恒显示的，默认关掉等于给存量用户改现状。关掉之后通知
/// 栏只剩订阅名和「停止」按钮，通知本身不会消失（前台服务的通知不能撤）。
@override@JsonKey() final  bool showNotificationSpeed;
@override@JsonKey() final  bool autoLaunch;
@override@JsonKey() final  bool silentLaunch;
@override@JsonKey() final  bool autoRun;
@override@JsonKey() final  bool openLogs;
@override@JsonKey() final  bool closeConnections;
@override@JsonKey() final  String testUrl;
@override@JsonKey() final  bool isAnimateToPage;
@override@JsonKey() final  bool autoCheckUpdate;
@override@JsonKey() final  bool showLabel;
@override@JsonKey() final  bool disclaimerAccepted;
@override@JsonKey() final  bool minimizeOnExit;
@override@JsonKey() final  bool hidden;
@override@JsonKey() final  bool developerMode;
@override@JsonKey() final  RestoreStrategy restoreStrategy;
@override@JsonKey() final  bool showTrayTitle;
@override@JsonKey() final  String customUserAgent;
@override@JsonKey() final  bool allowInsecureCertificate;
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
@override@JsonKey() final  bool smartRouting;
/// 是否让 Smart 组用预训练的 LightGBM 模型选路。
///
/// **默认开**：Smart 的全部意义就是用训练好的模型选路，关掉它就退回启发式
/// 打分——开了 Smart 又不用模型，等于白开。模型文件不在时内核会自己下载。
///
/// 桌面版这个字段默认关，这里不照抄：桌面端的 Smart 总闸和这一项是分开两次
/// 决策，而这里总闸（[smartRouting]）本来就默认关，用户主动打开时理应拿到
/// 完整形态的 Smart，而不是一个被阉了一半的。
@override@JsonKey() final  bool smartUseLightGBM;
/// 是否收集本机的网络使用数据（用来训练自己的模型）。
/// 桌面版对应字段 `smartCoreCollectData`，默认关。
@override@JsonKey() final  bool smartCollectData;
/// 数据收集文件的大小上限，单位 MB。
/// 桌面版对应字段 `smartCollectorSize`，默认 100。
@override@JsonKey() final  int smartCollectorSize;
/// Smart 组的策略模式：`sticky-sessions`（粘性会话）或 `round-robin`（轮询）。
/// 桌面版对应字段 `smartCoreStrategy`，默认粘性会话。
///
/// 存字符串而不是枚举，是为了和桌面版写进配置里的值逐字节一致。
@override@JsonKey() final  String smartStrategy;
/// 延迟去抖：两个节点延迟差不超过这个毫秒数时视为一样快，保持原顺序不换。
///
/// **桌面版没有这一项**，是内核本来就支持的组级选项
/// （`adapter/outboundgroup/smart.go` 的 `SmartOption.Tolerance`）。
/// **默认 150 毫秒**，取自内核自带示例配置里同语义选项给的值
/// （`docs/config.yaml:1723`）。留 0 的话两个节点差 1 毫秒也要换，手机网络
/// 抖动大会导致反复横跳。推导与依据见 [defaultSmartTolerance]。
@override@JsonKey() final  int smartTolerance;
/// 目标 ASN 未知时，是否额外做一次解析把它补出来，让 Smart 按"目标属于哪个
/// 运营商"归纳经验。代价是未知目标要多一次查询。
///
/// **桌面版没有这一项**，默认关＝不写这个键。
@override@JsonKey() final  bool smartPreferAsn;
/// 训练数据采样率，取值 (0, 1]。只影响"收集数据"写盘的量，**与选路无关**。
///
/// **桌面版没有这一项**，默认 1＝全采样，等于不写这个键。
@override@JsonKey() final  double smartSampleRate;
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
@override@JsonKey() final  bool smartLgbmAutoUpdate;
/// 自动更新的间隔，单位小时。内核默认 72。
@override@JsonKey() final  int smartLgbmUpdateInterval;
/// 模型下载地址（内核 `lgbm-url`）。留空＝用内核内置的那个地址。
///
/// 填不同的地址可以选模型大小：标准版约 9 MB、中等约 18 MB、大号约 26 MB。
/// 填错了不会损坏现有模型——内核先下到临时文件并真正加载一遍，验不过就不落盘。
@override@JsonKey() final  String smartLgbmUrl;
/// 只在 Wi-Fi 下更新模型。**默认开**。
///
/// **内核自己做不到这件事**：下载是内核发起的，它不知道当前走的是 Wi-Fi 还是
/// 蜂窝。所以这道闸在应用侧——只有当前确实在 Wi-Fi 上时，才把
/// `lgbm-auto-update` 按 true 下发；切到流量就按 false 下发。
/// 判断逻辑见 [SmartOptions.lgbmAutoUpdateNow]。
@override@JsonKey() final  bool smartLgbmWifiOnly;

/// Create a copy of AppSettingProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingPropsCopyWith<_AppSettingProps> get copyWith => __$AppSettingPropsCopyWithImpl<_AppSettingProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppSettingPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettingProps&&(identical(other.locale, locale) || other.locale == locale)&&const DeepCollectionEquality().equals(other._dashboardWidgets, _dashboardWidgets)&&const DeepCollectionEquality().equals(other._dashboardWidgetSpans, _dashboardWidgetSpans)&&const DeepCollectionEquality().equals(other._dashboardWidgetRows, _dashboardWidgetRows)&&(identical(other.onlyStatisticsProxy, onlyStatisticsProxy) || other.onlyStatisticsProxy == onlyStatisticsProxy)&&(identical(other.showNotificationSpeed, showNotificationSpeed) || other.showNotificationSpeed == showNotificationSpeed)&&(identical(other.autoLaunch, autoLaunch) || other.autoLaunch == autoLaunch)&&(identical(other.silentLaunch, silentLaunch) || other.silentLaunch == silentLaunch)&&(identical(other.autoRun, autoRun) || other.autoRun == autoRun)&&(identical(other.openLogs, openLogs) || other.openLogs == openLogs)&&(identical(other.closeConnections, closeConnections) || other.closeConnections == closeConnections)&&(identical(other.testUrl, testUrl) || other.testUrl == testUrl)&&(identical(other.isAnimateToPage, isAnimateToPage) || other.isAnimateToPage == isAnimateToPage)&&(identical(other.autoCheckUpdate, autoCheckUpdate) || other.autoCheckUpdate == autoCheckUpdate)&&(identical(other.showLabel, showLabel) || other.showLabel == showLabel)&&(identical(other.disclaimerAccepted, disclaimerAccepted) || other.disclaimerAccepted == disclaimerAccepted)&&(identical(other.minimizeOnExit, minimizeOnExit) || other.minimizeOnExit == minimizeOnExit)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.developerMode, developerMode) || other.developerMode == developerMode)&&(identical(other.restoreStrategy, restoreStrategy) || other.restoreStrategy == restoreStrategy)&&(identical(other.showTrayTitle, showTrayTitle) || other.showTrayTitle == showTrayTitle)&&(identical(other.customUserAgent, customUserAgent) || other.customUserAgent == customUserAgent)&&(identical(other.allowInsecureCertificate, allowInsecureCertificate) || other.allowInsecureCertificate == allowInsecureCertificate)&&(identical(other.smartRouting, smartRouting) || other.smartRouting == smartRouting)&&(identical(other.smartUseLightGBM, smartUseLightGBM) || other.smartUseLightGBM == smartUseLightGBM)&&(identical(other.smartCollectData, smartCollectData) || other.smartCollectData == smartCollectData)&&(identical(other.smartCollectorSize, smartCollectorSize) || other.smartCollectorSize == smartCollectorSize)&&(identical(other.smartStrategy, smartStrategy) || other.smartStrategy == smartStrategy)&&(identical(other.smartTolerance, smartTolerance) || other.smartTolerance == smartTolerance)&&(identical(other.smartPreferAsn, smartPreferAsn) || other.smartPreferAsn == smartPreferAsn)&&(identical(other.smartSampleRate, smartSampleRate) || other.smartSampleRate == smartSampleRate)&&(identical(other.smartLgbmAutoUpdate, smartLgbmAutoUpdate) || other.smartLgbmAutoUpdate == smartLgbmAutoUpdate)&&(identical(other.smartLgbmUpdateInterval, smartLgbmUpdateInterval) || other.smartLgbmUpdateInterval == smartLgbmUpdateInterval)&&(identical(other.smartLgbmUrl, smartLgbmUrl) || other.smartLgbmUrl == smartLgbmUrl)&&(identical(other.smartLgbmWifiOnly, smartLgbmWifiOnly) || other.smartLgbmWifiOnly == smartLgbmWifiOnly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,locale,const DeepCollectionEquality().hash(_dashboardWidgets),const DeepCollectionEquality().hash(_dashboardWidgetSpans),const DeepCollectionEquality().hash(_dashboardWidgetRows),onlyStatisticsProxy,showNotificationSpeed,autoLaunch,silentLaunch,autoRun,openLogs,closeConnections,testUrl,isAnimateToPage,autoCheckUpdate,showLabel,disclaimerAccepted,minimizeOnExit,hidden,developerMode,restoreStrategy,showTrayTitle,customUserAgent,allowInsecureCertificate,smartRouting,smartUseLightGBM,smartCollectData,smartCollectorSize,smartStrategy,smartTolerance,smartPreferAsn,smartSampleRate,smartLgbmAutoUpdate,smartLgbmUpdateInterval,smartLgbmUrl,smartLgbmWifiOnly]);

@override
String toString() {
  return 'AppSettingProps(locale: $locale, dashboardWidgets: $dashboardWidgets, dashboardWidgetSpans: $dashboardWidgetSpans, dashboardWidgetRows: $dashboardWidgetRows, onlyStatisticsProxy: $onlyStatisticsProxy, showNotificationSpeed: $showNotificationSpeed, autoLaunch: $autoLaunch, silentLaunch: $silentLaunch, autoRun: $autoRun, openLogs: $openLogs, closeConnections: $closeConnections, testUrl: $testUrl, isAnimateToPage: $isAnimateToPage, autoCheckUpdate: $autoCheckUpdate, showLabel: $showLabel, disclaimerAccepted: $disclaimerAccepted, minimizeOnExit: $minimizeOnExit, hidden: $hidden, developerMode: $developerMode, restoreStrategy: $restoreStrategy, showTrayTitle: $showTrayTitle, customUserAgent: $customUserAgent, allowInsecureCertificate: $allowInsecureCertificate, smartRouting: $smartRouting, smartUseLightGBM: $smartUseLightGBM, smartCollectData: $smartCollectData, smartCollectorSize: $smartCollectorSize, smartStrategy: $smartStrategy, smartTolerance: $smartTolerance, smartPreferAsn: $smartPreferAsn, smartSampleRate: $smartSampleRate, smartLgbmAutoUpdate: $smartLgbmAutoUpdate, smartLgbmUpdateInterval: $smartLgbmUpdateInterval, smartLgbmUrl: $smartLgbmUrl, smartLgbmWifiOnly: $smartLgbmWifiOnly)';
}


}

/// @nodoc
abstract mixin class _$AppSettingPropsCopyWith<$Res> implements $AppSettingPropsCopyWith<$Res> {
  factory _$AppSettingPropsCopyWith(_AppSettingProps value, $Res Function(_AppSettingProps) _then) = __$AppSettingPropsCopyWithImpl;
@override @useResult
$Res call({
 String? locale,@JsonKey(fromJson: dashboardWidgetsSafeFormJson) List<DashboardWidget> dashboardWidgets, Map<String, int> dashboardWidgetSpans, Map<String, int> dashboardWidgetRows, bool onlyStatisticsProxy, bool showNotificationSpeed, bool autoLaunch, bool silentLaunch, bool autoRun, bool openLogs, bool closeConnections, String testUrl, bool isAnimateToPage, bool autoCheckUpdate, bool showLabel, bool disclaimerAccepted, bool minimizeOnExit, bool hidden, bool developerMode, RestoreStrategy restoreStrategy, bool showTrayTitle, String customUserAgent, bool allowInsecureCertificate, bool smartRouting, bool smartUseLightGBM, bool smartCollectData, int smartCollectorSize, String smartStrategy, int smartTolerance, bool smartPreferAsn, double smartSampleRate, bool smartLgbmAutoUpdate, int smartLgbmUpdateInterval, String smartLgbmUrl, bool smartLgbmWifiOnly
});




}
/// @nodoc
class __$AppSettingPropsCopyWithImpl<$Res>
    implements _$AppSettingPropsCopyWith<$Res> {
  __$AppSettingPropsCopyWithImpl(this._self, this._then);

  final _AppSettingProps _self;
  final $Res Function(_AppSettingProps) _then;

/// Create a copy of AppSettingProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locale = freezed,Object? dashboardWidgets = null,Object? dashboardWidgetSpans = null,Object? dashboardWidgetRows = null,Object? onlyStatisticsProxy = null,Object? showNotificationSpeed = null,Object? autoLaunch = null,Object? silentLaunch = null,Object? autoRun = null,Object? openLogs = null,Object? closeConnections = null,Object? testUrl = null,Object? isAnimateToPage = null,Object? autoCheckUpdate = null,Object? showLabel = null,Object? disclaimerAccepted = null,Object? minimizeOnExit = null,Object? hidden = null,Object? developerMode = null,Object? restoreStrategy = null,Object? showTrayTitle = null,Object? customUserAgent = null,Object? allowInsecureCertificate = null,Object? smartRouting = null,Object? smartUseLightGBM = null,Object? smartCollectData = null,Object? smartCollectorSize = null,Object? smartStrategy = null,Object? smartTolerance = null,Object? smartPreferAsn = null,Object? smartSampleRate = null,Object? smartLgbmAutoUpdate = null,Object? smartLgbmUpdateInterval = null,Object? smartLgbmUrl = null,Object? smartLgbmWifiOnly = null,}) {
  return _then(_AppSettingProps(
locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,dashboardWidgets: null == dashboardWidgets ? _self._dashboardWidgets : dashboardWidgets // ignore: cast_nullable_to_non_nullable
as List<DashboardWidget>,dashboardWidgetSpans: null == dashboardWidgetSpans ? _self._dashboardWidgetSpans : dashboardWidgetSpans // ignore: cast_nullable_to_non_nullable
as Map<String, int>,dashboardWidgetRows: null == dashboardWidgetRows ? _self._dashboardWidgetRows : dashboardWidgetRows // ignore: cast_nullable_to_non_nullable
as Map<String, int>,onlyStatisticsProxy: null == onlyStatisticsProxy ? _self.onlyStatisticsProxy : onlyStatisticsProxy // ignore: cast_nullable_to_non_nullable
as bool,showNotificationSpeed: null == showNotificationSpeed ? _self.showNotificationSpeed : showNotificationSpeed // ignore: cast_nullable_to_non_nullable
as bool,autoLaunch: null == autoLaunch ? _self.autoLaunch : autoLaunch // ignore: cast_nullable_to_non_nullable
as bool,silentLaunch: null == silentLaunch ? _self.silentLaunch : silentLaunch // ignore: cast_nullable_to_non_nullable
as bool,autoRun: null == autoRun ? _self.autoRun : autoRun // ignore: cast_nullable_to_non_nullable
as bool,openLogs: null == openLogs ? _self.openLogs : openLogs // ignore: cast_nullable_to_non_nullable
as bool,closeConnections: null == closeConnections ? _self.closeConnections : closeConnections // ignore: cast_nullable_to_non_nullable
as bool,testUrl: null == testUrl ? _self.testUrl : testUrl // ignore: cast_nullable_to_non_nullable
as String,isAnimateToPage: null == isAnimateToPage ? _self.isAnimateToPage : isAnimateToPage // ignore: cast_nullable_to_non_nullable
as bool,autoCheckUpdate: null == autoCheckUpdate ? _self.autoCheckUpdate : autoCheckUpdate // ignore: cast_nullable_to_non_nullable
as bool,showLabel: null == showLabel ? _self.showLabel : showLabel // ignore: cast_nullable_to_non_nullable
as bool,disclaimerAccepted: null == disclaimerAccepted ? _self.disclaimerAccepted : disclaimerAccepted // ignore: cast_nullable_to_non_nullable
as bool,minimizeOnExit: null == minimizeOnExit ? _self.minimizeOnExit : minimizeOnExit // ignore: cast_nullable_to_non_nullable
as bool,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,developerMode: null == developerMode ? _self.developerMode : developerMode // ignore: cast_nullable_to_non_nullable
as bool,restoreStrategy: null == restoreStrategy ? _self.restoreStrategy : restoreStrategy // ignore: cast_nullable_to_non_nullable
as RestoreStrategy,showTrayTitle: null == showTrayTitle ? _self.showTrayTitle : showTrayTitle // ignore: cast_nullable_to_non_nullable
as bool,customUserAgent: null == customUserAgent ? _self.customUserAgent : customUserAgent // ignore: cast_nullable_to_non_nullable
as String,allowInsecureCertificate: null == allowInsecureCertificate ? _self.allowInsecureCertificate : allowInsecureCertificate // ignore: cast_nullable_to_non_nullable
as bool,smartRouting: null == smartRouting ? _self.smartRouting : smartRouting // ignore: cast_nullable_to_non_nullable
as bool,smartUseLightGBM: null == smartUseLightGBM ? _self.smartUseLightGBM : smartUseLightGBM // ignore: cast_nullable_to_non_nullable
as bool,smartCollectData: null == smartCollectData ? _self.smartCollectData : smartCollectData // ignore: cast_nullable_to_non_nullable
as bool,smartCollectorSize: null == smartCollectorSize ? _self.smartCollectorSize : smartCollectorSize // ignore: cast_nullable_to_non_nullable
as int,smartStrategy: null == smartStrategy ? _self.smartStrategy : smartStrategy // ignore: cast_nullable_to_non_nullable
as String,smartTolerance: null == smartTolerance ? _self.smartTolerance : smartTolerance // ignore: cast_nullable_to_non_nullable
as int,smartPreferAsn: null == smartPreferAsn ? _self.smartPreferAsn : smartPreferAsn // ignore: cast_nullable_to_non_nullable
as bool,smartSampleRate: null == smartSampleRate ? _self.smartSampleRate : smartSampleRate // ignore: cast_nullable_to_non_nullable
as double,smartLgbmAutoUpdate: null == smartLgbmAutoUpdate ? _self.smartLgbmAutoUpdate : smartLgbmAutoUpdate // ignore: cast_nullable_to_non_nullable
as bool,smartLgbmUpdateInterval: null == smartLgbmUpdateInterval ? _self.smartLgbmUpdateInterval : smartLgbmUpdateInterval // ignore: cast_nullable_to_non_nullable
as int,smartLgbmUrl: null == smartLgbmUrl ? _self.smartLgbmUrl : smartLgbmUrl // ignore: cast_nullable_to_non_nullable
as String,smartLgbmWifiOnly: null == smartLgbmWifiOnly ? _self.smartLgbmWifiOnly : smartLgbmWifiOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$SmartOptions {

/// 见 [AppSettingProps.smartRouting]。为假时把 Smart 组改写回 url-test。
///
/// 默认跟着 [AppSettingProps.smartRouting] 一起是 false：这个类只在
/// `MakeRealProfileState` 没显式带 smart 时兜底，兜底值必须是"不改写用户配置"
/// 的那一侧。
 bool get enable; bool get useLightGBM; bool get collectData; int get collectorSize; String get strategy; int get tolerance; bool get preferAsn; double get sampleRate;/// 关掉 Smart 时改写出来的 url-test 组，组里没写 `url` 就用它兜底。
 String get testUrl;/// 见 [AppSettingProps.smartLgbmAutoUpdate] 等三项。这三个是**全局顶层键**。
 bool get lgbmAutoUpdate; int get lgbmUpdateInterval; String get lgbmUrl; bool get lgbmWifiOnly;/// 当前是不是连着 Wi-Fi。**运行时状态，不是用户设置**，由
/// `providers/state.dart` 的 smartOptionsState 从连接类型填进来。
 bool get onWifi;
/// Create a copy of SmartOptions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SmartOptionsCopyWith<SmartOptions> get copyWith => _$SmartOptionsCopyWithImpl<SmartOptions>(this as SmartOptions, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SmartOptions&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.useLightGBM, useLightGBM) || other.useLightGBM == useLightGBM)&&(identical(other.collectData, collectData) || other.collectData == collectData)&&(identical(other.collectorSize, collectorSize) || other.collectorSize == collectorSize)&&(identical(other.strategy, strategy) || other.strategy == strategy)&&(identical(other.tolerance, tolerance) || other.tolerance == tolerance)&&(identical(other.preferAsn, preferAsn) || other.preferAsn == preferAsn)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.testUrl, testUrl) || other.testUrl == testUrl)&&(identical(other.lgbmAutoUpdate, lgbmAutoUpdate) || other.lgbmAutoUpdate == lgbmAutoUpdate)&&(identical(other.lgbmUpdateInterval, lgbmUpdateInterval) || other.lgbmUpdateInterval == lgbmUpdateInterval)&&(identical(other.lgbmUrl, lgbmUrl) || other.lgbmUrl == lgbmUrl)&&(identical(other.lgbmWifiOnly, lgbmWifiOnly) || other.lgbmWifiOnly == lgbmWifiOnly)&&(identical(other.onWifi, onWifi) || other.onWifi == onWifi));
}


@override
int get hashCode => Object.hash(runtimeType,enable,useLightGBM,collectData,collectorSize,strategy,tolerance,preferAsn,sampleRate,testUrl,lgbmAutoUpdate,lgbmUpdateInterval,lgbmUrl,lgbmWifiOnly,onWifi);

@override
String toString() {
  return 'SmartOptions(enable: $enable, useLightGBM: $useLightGBM, collectData: $collectData, collectorSize: $collectorSize, strategy: $strategy, tolerance: $tolerance, preferAsn: $preferAsn, sampleRate: $sampleRate, testUrl: $testUrl, lgbmAutoUpdate: $lgbmAutoUpdate, lgbmUpdateInterval: $lgbmUpdateInterval, lgbmUrl: $lgbmUrl, lgbmWifiOnly: $lgbmWifiOnly, onWifi: $onWifi)';
}


}

/// @nodoc
abstract mixin class $SmartOptionsCopyWith<$Res>  {
  factory $SmartOptionsCopyWith(SmartOptions value, $Res Function(SmartOptions) _then) = _$SmartOptionsCopyWithImpl;
@useResult
$Res call({
 bool enable, bool useLightGBM, bool collectData, int collectorSize, String strategy, int tolerance, bool preferAsn, double sampleRate, String testUrl, bool lgbmAutoUpdate, int lgbmUpdateInterval, String lgbmUrl, bool lgbmWifiOnly, bool onWifi
});




}
/// @nodoc
class _$SmartOptionsCopyWithImpl<$Res>
    implements $SmartOptionsCopyWith<$Res> {
  _$SmartOptionsCopyWithImpl(this._self, this._then);

  final SmartOptions _self;
  final $Res Function(SmartOptions) _then;

/// Create a copy of SmartOptions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enable = null,Object? useLightGBM = null,Object? collectData = null,Object? collectorSize = null,Object? strategy = null,Object? tolerance = null,Object? preferAsn = null,Object? sampleRate = null,Object? testUrl = null,Object? lgbmAutoUpdate = null,Object? lgbmUpdateInterval = null,Object? lgbmUrl = null,Object? lgbmWifiOnly = null,Object? onWifi = null,}) {
  return _then(_self.copyWith(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,useLightGBM: null == useLightGBM ? _self.useLightGBM : useLightGBM // ignore: cast_nullable_to_non_nullable
as bool,collectData: null == collectData ? _self.collectData : collectData // ignore: cast_nullable_to_non_nullable
as bool,collectorSize: null == collectorSize ? _self.collectorSize : collectorSize // ignore: cast_nullable_to_non_nullable
as int,strategy: null == strategy ? _self.strategy : strategy // ignore: cast_nullable_to_non_nullable
as String,tolerance: null == tolerance ? _self.tolerance : tolerance // ignore: cast_nullable_to_non_nullable
as int,preferAsn: null == preferAsn ? _self.preferAsn : preferAsn // ignore: cast_nullable_to_non_nullable
as bool,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as double,testUrl: null == testUrl ? _self.testUrl : testUrl // ignore: cast_nullable_to_non_nullable
as String,lgbmAutoUpdate: null == lgbmAutoUpdate ? _self.lgbmAutoUpdate : lgbmAutoUpdate // ignore: cast_nullable_to_non_nullable
as bool,lgbmUpdateInterval: null == lgbmUpdateInterval ? _self.lgbmUpdateInterval : lgbmUpdateInterval // ignore: cast_nullable_to_non_nullable
as int,lgbmUrl: null == lgbmUrl ? _self.lgbmUrl : lgbmUrl // ignore: cast_nullable_to_non_nullable
as String,lgbmWifiOnly: null == lgbmWifiOnly ? _self.lgbmWifiOnly : lgbmWifiOnly // ignore: cast_nullable_to_non_nullable
as bool,onWifi: null == onWifi ? _self.onWifi : onWifi // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SmartOptions].
extension SmartOptionsPatterns on SmartOptions {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SmartOptions value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SmartOptions() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SmartOptions value)  $default,){
final _that = this;
switch (_that) {
case _SmartOptions():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SmartOptions value)?  $default,){
final _that = this;
switch (_that) {
case _SmartOptions() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enable,  bool useLightGBM,  bool collectData,  int collectorSize,  String strategy,  int tolerance,  bool preferAsn,  double sampleRate,  String testUrl,  bool lgbmAutoUpdate,  int lgbmUpdateInterval,  String lgbmUrl,  bool lgbmWifiOnly,  bool onWifi)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SmartOptions() when $default != null:
return $default(_that.enable,_that.useLightGBM,_that.collectData,_that.collectorSize,_that.strategy,_that.tolerance,_that.preferAsn,_that.sampleRate,_that.testUrl,_that.lgbmAutoUpdate,_that.lgbmUpdateInterval,_that.lgbmUrl,_that.lgbmWifiOnly,_that.onWifi);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enable,  bool useLightGBM,  bool collectData,  int collectorSize,  String strategy,  int tolerance,  bool preferAsn,  double sampleRate,  String testUrl,  bool lgbmAutoUpdate,  int lgbmUpdateInterval,  String lgbmUrl,  bool lgbmWifiOnly,  bool onWifi)  $default,) {final _that = this;
switch (_that) {
case _SmartOptions():
return $default(_that.enable,_that.useLightGBM,_that.collectData,_that.collectorSize,_that.strategy,_that.tolerance,_that.preferAsn,_that.sampleRate,_that.testUrl,_that.lgbmAutoUpdate,_that.lgbmUpdateInterval,_that.lgbmUrl,_that.lgbmWifiOnly,_that.onWifi);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enable,  bool useLightGBM,  bool collectData,  int collectorSize,  String strategy,  int tolerance,  bool preferAsn,  double sampleRate,  String testUrl,  bool lgbmAutoUpdate,  int lgbmUpdateInterval,  String lgbmUrl,  bool lgbmWifiOnly,  bool onWifi)?  $default,) {final _that = this;
switch (_that) {
case _SmartOptions() when $default != null:
return $default(_that.enable,_that.useLightGBM,_that.collectData,_that.collectorSize,_that.strategy,_that.tolerance,_that.preferAsn,_that.sampleRate,_that.testUrl,_that.lgbmAutoUpdate,_that.lgbmUpdateInterval,_that.lgbmUrl,_that.lgbmWifiOnly,_that.onWifi);case _:
  return null;

}
}

}

/// @nodoc


class _SmartOptions implements SmartOptions {
  const _SmartOptions({this.enable = false, this.useLightGBM = false, this.collectData = false, this.collectorSize = defaultSmartCollectorSize, this.strategy = smartStrategyStickySessions, this.tolerance = 0, this.preferAsn = false, this.sampleRate = 1.0, this.testUrl = defaultTestUrl, this.lgbmAutoUpdate = false, this.lgbmUpdateInterval = defaultSmartLgbmInterval, this.lgbmUrl = '', this.lgbmWifiOnly = true, this.onWifi = false});
  

/// 见 [AppSettingProps.smartRouting]。为假时把 Smart 组改写回 url-test。
///
/// 默认跟着 [AppSettingProps.smartRouting] 一起是 false：这个类只在
/// `MakeRealProfileState` 没显式带 smart 时兜底，兜底值必须是"不改写用户配置"
/// 的那一侧。
@override@JsonKey() final  bool enable;
@override@JsonKey() final  bool useLightGBM;
@override@JsonKey() final  bool collectData;
@override@JsonKey() final  int collectorSize;
@override@JsonKey() final  String strategy;
@override@JsonKey() final  int tolerance;
@override@JsonKey() final  bool preferAsn;
@override@JsonKey() final  double sampleRate;
/// 关掉 Smart 时改写出来的 url-test 组，组里没写 `url` 就用它兜底。
@override@JsonKey() final  String testUrl;
/// 见 [AppSettingProps.smartLgbmAutoUpdate] 等三项。这三个是**全局顶层键**。
@override@JsonKey() final  bool lgbmAutoUpdate;
@override@JsonKey() final  int lgbmUpdateInterval;
@override@JsonKey() final  String lgbmUrl;
@override@JsonKey() final  bool lgbmWifiOnly;
/// 当前是不是连着 Wi-Fi。**运行时状态，不是用户设置**，由
/// `providers/state.dart` 的 smartOptionsState 从连接类型填进来。
@override@JsonKey() final  bool onWifi;

/// Create a copy of SmartOptions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SmartOptionsCopyWith<_SmartOptions> get copyWith => __$SmartOptionsCopyWithImpl<_SmartOptions>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SmartOptions&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.useLightGBM, useLightGBM) || other.useLightGBM == useLightGBM)&&(identical(other.collectData, collectData) || other.collectData == collectData)&&(identical(other.collectorSize, collectorSize) || other.collectorSize == collectorSize)&&(identical(other.strategy, strategy) || other.strategy == strategy)&&(identical(other.tolerance, tolerance) || other.tolerance == tolerance)&&(identical(other.preferAsn, preferAsn) || other.preferAsn == preferAsn)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.testUrl, testUrl) || other.testUrl == testUrl)&&(identical(other.lgbmAutoUpdate, lgbmAutoUpdate) || other.lgbmAutoUpdate == lgbmAutoUpdate)&&(identical(other.lgbmUpdateInterval, lgbmUpdateInterval) || other.lgbmUpdateInterval == lgbmUpdateInterval)&&(identical(other.lgbmUrl, lgbmUrl) || other.lgbmUrl == lgbmUrl)&&(identical(other.lgbmWifiOnly, lgbmWifiOnly) || other.lgbmWifiOnly == lgbmWifiOnly)&&(identical(other.onWifi, onWifi) || other.onWifi == onWifi));
}


@override
int get hashCode => Object.hash(runtimeType,enable,useLightGBM,collectData,collectorSize,strategy,tolerance,preferAsn,sampleRate,testUrl,lgbmAutoUpdate,lgbmUpdateInterval,lgbmUrl,lgbmWifiOnly,onWifi);

@override
String toString() {
  return 'SmartOptions(enable: $enable, useLightGBM: $useLightGBM, collectData: $collectData, collectorSize: $collectorSize, strategy: $strategy, tolerance: $tolerance, preferAsn: $preferAsn, sampleRate: $sampleRate, testUrl: $testUrl, lgbmAutoUpdate: $lgbmAutoUpdate, lgbmUpdateInterval: $lgbmUpdateInterval, lgbmUrl: $lgbmUrl, lgbmWifiOnly: $lgbmWifiOnly, onWifi: $onWifi)';
}


}

/// @nodoc
abstract mixin class _$SmartOptionsCopyWith<$Res> implements $SmartOptionsCopyWith<$Res> {
  factory _$SmartOptionsCopyWith(_SmartOptions value, $Res Function(_SmartOptions) _then) = __$SmartOptionsCopyWithImpl;
@override @useResult
$Res call({
 bool enable, bool useLightGBM, bool collectData, int collectorSize, String strategy, int tolerance, bool preferAsn, double sampleRate, String testUrl, bool lgbmAutoUpdate, int lgbmUpdateInterval, String lgbmUrl, bool lgbmWifiOnly, bool onWifi
});




}
/// @nodoc
class __$SmartOptionsCopyWithImpl<$Res>
    implements _$SmartOptionsCopyWith<$Res> {
  __$SmartOptionsCopyWithImpl(this._self, this._then);

  final _SmartOptions _self;
  final $Res Function(_SmartOptions) _then;

/// Create a copy of SmartOptions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enable = null,Object? useLightGBM = null,Object? collectData = null,Object? collectorSize = null,Object? strategy = null,Object? tolerance = null,Object? preferAsn = null,Object? sampleRate = null,Object? testUrl = null,Object? lgbmAutoUpdate = null,Object? lgbmUpdateInterval = null,Object? lgbmUrl = null,Object? lgbmWifiOnly = null,Object? onWifi = null,}) {
  return _then(_SmartOptions(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,useLightGBM: null == useLightGBM ? _self.useLightGBM : useLightGBM // ignore: cast_nullable_to_non_nullable
as bool,collectData: null == collectData ? _self.collectData : collectData // ignore: cast_nullable_to_non_nullable
as bool,collectorSize: null == collectorSize ? _self.collectorSize : collectorSize // ignore: cast_nullable_to_non_nullable
as int,strategy: null == strategy ? _self.strategy : strategy // ignore: cast_nullable_to_non_nullable
as String,tolerance: null == tolerance ? _self.tolerance : tolerance // ignore: cast_nullable_to_non_nullable
as int,preferAsn: null == preferAsn ? _self.preferAsn : preferAsn // ignore: cast_nullable_to_non_nullable
as bool,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as double,testUrl: null == testUrl ? _self.testUrl : testUrl // ignore: cast_nullable_to_non_nullable
as String,lgbmAutoUpdate: null == lgbmAutoUpdate ? _self.lgbmAutoUpdate : lgbmAutoUpdate // ignore: cast_nullable_to_non_nullable
as bool,lgbmUpdateInterval: null == lgbmUpdateInterval ? _self.lgbmUpdateInterval : lgbmUpdateInterval // ignore: cast_nullable_to_non_nullable
as int,lgbmUrl: null == lgbmUrl ? _self.lgbmUrl : lgbmUrl // ignore: cast_nullable_to_non_nullable
as String,lgbmWifiOnly: null == lgbmWifiOnly ? _self.lgbmWifiOnly : lgbmWifiOnly // ignore: cast_nullable_to_non_nullable
as bool,onWifi: null == onWifi ? _self.onWifi : onWifi // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$AccessControlProps {

 bool get enable; AccessControlMode get mode; List<String> get acceptList; List<String> get rejectList; AccessSortType get sort; bool get isFilterSystemApp; bool get isFilterNonInternetApp;
/// Create a copy of AccessControlProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccessControlPropsCopyWith<AccessControlProps> get copyWith => _$AccessControlPropsCopyWithImpl<AccessControlProps>(this as AccessControlProps, _$identity);

  /// Serializes this AccessControlProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccessControlProps&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other.acceptList, acceptList)&&const DeepCollectionEquality().equals(other.rejectList, rejectList)&&(identical(other.sort, sort) || other.sort == sort)&&(identical(other.isFilterSystemApp, isFilterSystemApp) || other.isFilterSystemApp == isFilterSystemApp)&&(identical(other.isFilterNonInternetApp, isFilterNonInternetApp) || other.isFilterNonInternetApp == isFilterNonInternetApp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,mode,const DeepCollectionEquality().hash(acceptList),const DeepCollectionEquality().hash(rejectList),sort,isFilterSystemApp,isFilterNonInternetApp);

@override
String toString() {
  return 'AccessControlProps(enable: $enable, mode: $mode, acceptList: $acceptList, rejectList: $rejectList, sort: $sort, isFilterSystemApp: $isFilterSystemApp, isFilterNonInternetApp: $isFilterNonInternetApp)';
}


}

/// @nodoc
abstract mixin class $AccessControlPropsCopyWith<$Res>  {
  factory $AccessControlPropsCopyWith(AccessControlProps value, $Res Function(AccessControlProps) _then) = _$AccessControlPropsCopyWithImpl;
@useResult
$Res call({
 bool enable, AccessControlMode mode, List<String> acceptList, List<String> rejectList, AccessSortType sort, bool isFilterSystemApp, bool isFilterNonInternetApp
});




}
/// @nodoc
class _$AccessControlPropsCopyWithImpl<$Res>
    implements $AccessControlPropsCopyWith<$Res> {
  _$AccessControlPropsCopyWithImpl(this._self, this._then);

  final AccessControlProps _self;
  final $Res Function(AccessControlProps) _then;

/// Create a copy of AccessControlProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enable = null,Object? mode = null,Object? acceptList = null,Object? rejectList = null,Object? sort = null,Object? isFilterSystemApp = null,Object? isFilterNonInternetApp = null,}) {
  return _then(_self.copyWith(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as AccessControlMode,acceptList: null == acceptList ? _self.acceptList : acceptList // ignore: cast_nullable_to_non_nullable
as List<String>,rejectList: null == rejectList ? _self.rejectList : rejectList // ignore: cast_nullable_to_non_nullable
as List<String>,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as AccessSortType,isFilterSystemApp: null == isFilterSystemApp ? _self.isFilterSystemApp : isFilterSystemApp // ignore: cast_nullable_to_non_nullable
as bool,isFilterNonInternetApp: null == isFilterNonInternetApp ? _self.isFilterNonInternetApp : isFilterNonInternetApp // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AccessControlProps].
extension AccessControlPropsPatterns on AccessControlProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccessControlProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccessControlProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccessControlProps value)  $default,){
final _that = this;
switch (_that) {
case _AccessControlProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccessControlProps value)?  $default,){
final _that = this;
switch (_that) {
case _AccessControlProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enable,  AccessControlMode mode,  List<String> acceptList,  List<String> rejectList,  AccessSortType sort,  bool isFilterSystemApp,  bool isFilterNonInternetApp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccessControlProps() when $default != null:
return $default(_that.enable,_that.mode,_that.acceptList,_that.rejectList,_that.sort,_that.isFilterSystemApp,_that.isFilterNonInternetApp);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enable,  AccessControlMode mode,  List<String> acceptList,  List<String> rejectList,  AccessSortType sort,  bool isFilterSystemApp,  bool isFilterNonInternetApp)  $default,) {final _that = this;
switch (_that) {
case _AccessControlProps():
return $default(_that.enable,_that.mode,_that.acceptList,_that.rejectList,_that.sort,_that.isFilterSystemApp,_that.isFilterNonInternetApp);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enable,  AccessControlMode mode,  List<String> acceptList,  List<String> rejectList,  AccessSortType sort,  bool isFilterSystemApp,  bool isFilterNonInternetApp)?  $default,) {final _that = this;
switch (_that) {
case _AccessControlProps() when $default != null:
return $default(_that.enable,_that.mode,_that.acceptList,_that.rejectList,_that.sort,_that.isFilterSystemApp,_that.isFilterNonInternetApp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccessControlProps implements AccessControlProps {
  const _AccessControlProps({this.enable = false, this.mode = AccessControlMode.rejectSelected, final  List<String> acceptList = const [], final  List<String> rejectList = const [], this.sort = AccessSortType.none, this.isFilterSystemApp = true, this.isFilterNonInternetApp = true}): _acceptList = acceptList,_rejectList = rejectList;
  factory _AccessControlProps.fromJson(Map<String, dynamic> json) => _$AccessControlPropsFromJson(json);

@override@JsonKey() final  bool enable;
@override@JsonKey() final  AccessControlMode mode;
 final  List<String> _acceptList;
@override@JsonKey() List<String> get acceptList {
  if (_acceptList is EqualUnmodifiableListView) return _acceptList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_acceptList);
}

 final  List<String> _rejectList;
@override@JsonKey() List<String> get rejectList {
  if (_rejectList is EqualUnmodifiableListView) return _rejectList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rejectList);
}

@override@JsonKey() final  AccessSortType sort;
@override@JsonKey() final  bool isFilterSystemApp;
@override@JsonKey() final  bool isFilterNonInternetApp;

/// Create a copy of AccessControlProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccessControlPropsCopyWith<_AccessControlProps> get copyWith => __$AccessControlPropsCopyWithImpl<_AccessControlProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccessControlPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccessControlProps&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other._acceptList, _acceptList)&&const DeepCollectionEquality().equals(other._rejectList, _rejectList)&&(identical(other.sort, sort) || other.sort == sort)&&(identical(other.isFilterSystemApp, isFilterSystemApp) || other.isFilterSystemApp == isFilterSystemApp)&&(identical(other.isFilterNonInternetApp, isFilterNonInternetApp) || other.isFilterNonInternetApp == isFilterNonInternetApp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,mode,const DeepCollectionEquality().hash(_acceptList),const DeepCollectionEquality().hash(_rejectList),sort,isFilterSystemApp,isFilterNonInternetApp);

@override
String toString() {
  return 'AccessControlProps(enable: $enable, mode: $mode, acceptList: $acceptList, rejectList: $rejectList, sort: $sort, isFilterSystemApp: $isFilterSystemApp, isFilterNonInternetApp: $isFilterNonInternetApp)';
}


}

/// @nodoc
abstract mixin class _$AccessControlPropsCopyWith<$Res> implements $AccessControlPropsCopyWith<$Res> {
  factory _$AccessControlPropsCopyWith(_AccessControlProps value, $Res Function(_AccessControlProps) _then) = __$AccessControlPropsCopyWithImpl;
@override @useResult
$Res call({
 bool enable, AccessControlMode mode, List<String> acceptList, List<String> rejectList, AccessSortType sort, bool isFilterSystemApp, bool isFilterNonInternetApp
});




}
/// @nodoc
class __$AccessControlPropsCopyWithImpl<$Res>
    implements _$AccessControlPropsCopyWith<$Res> {
  __$AccessControlPropsCopyWithImpl(this._self, this._then);

  final _AccessControlProps _self;
  final $Res Function(_AccessControlProps) _then;

/// Create a copy of AccessControlProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enable = null,Object? mode = null,Object? acceptList = null,Object? rejectList = null,Object? sort = null,Object? isFilterSystemApp = null,Object? isFilterNonInternetApp = null,}) {
  return _then(_AccessControlProps(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as AccessControlMode,acceptList: null == acceptList ? _self._acceptList : acceptList // ignore: cast_nullable_to_non_nullable
as List<String>,rejectList: null == rejectList ? _self._rejectList : rejectList // ignore: cast_nullable_to_non_nullable
as List<String>,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as AccessSortType,isFilterSystemApp: null == isFilterSystemApp ? _self.isFilterSystemApp : isFilterSystemApp // ignore: cast_nullable_to_non_nullable
as bool,isFilterNonInternetApp: null == isFilterNonInternetApp ? _self.isFilterNonInternetApp : isFilterNonInternetApp // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$WindowProps {

 double get width; double get height; double? get top; double? get left;
/// Create a copy of WindowProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WindowPropsCopyWith<WindowProps> get copyWith => _$WindowPropsCopyWithImpl<WindowProps>(this as WindowProps, _$identity);

  /// Serializes this WindowProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WindowProps&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.top, top) || other.top == top)&&(identical(other.left, left) || other.left == left));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,width,height,top,left);

@override
String toString() {
  return 'WindowProps(width: $width, height: $height, top: $top, left: $left)';
}


}

/// @nodoc
abstract mixin class $WindowPropsCopyWith<$Res>  {
  factory $WindowPropsCopyWith(WindowProps value, $Res Function(WindowProps) _then) = _$WindowPropsCopyWithImpl;
@useResult
$Res call({
 double width, double height, double? top, double? left
});




}
/// @nodoc
class _$WindowPropsCopyWithImpl<$Res>
    implements $WindowPropsCopyWith<$Res> {
  _$WindowPropsCopyWithImpl(this._self, this._then);

  final WindowProps _self;
  final $Res Function(WindowProps) _then;

/// Create a copy of WindowProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? width = null,Object? height = null,Object? top = freezed,Object? left = freezed,}) {
  return _then(_self.copyWith(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,top: freezed == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as double?,left: freezed == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [WindowProps].
extension WindowPropsPatterns on WindowProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WindowProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WindowProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WindowProps value)  $default,){
final _that = this;
switch (_that) {
case _WindowProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WindowProps value)?  $default,){
final _that = this;
switch (_that) {
case _WindowProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double width,  double height,  double? top,  double? left)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WindowProps() when $default != null:
return $default(_that.width,_that.height,_that.top,_that.left);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double width,  double height,  double? top,  double? left)  $default,) {final _that = this;
switch (_that) {
case _WindowProps():
return $default(_that.width,_that.height,_that.top,_that.left);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double width,  double height,  double? top,  double? left)?  $default,) {final _that = this;
switch (_that) {
case _WindowProps() when $default != null:
return $default(_that.width,_that.height,_that.top,_that.left);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WindowProps implements WindowProps {
  const _WindowProps({this.width = 0, this.height = 0, this.top, this.left});
  factory _WindowProps.fromJson(Map<String, dynamic> json) => _$WindowPropsFromJson(json);

@override@JsonKey() final  double width;
@override@JsonKey() final  double height;
@override final  double? top;
@override final  double? left;

/// Create a copy of WindowProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WindowPropsCopyWith<_WindowProps> get copyWith => __$WindowPropsCopyWithImpl<_WindowProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WindowPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WindowProps&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.top, top) || other.top == top)&&(identical(other.left, left) || other.left == left));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,width,height,top,left);

@override
String toString() {
  return 'WindowProps(width: $width, height: $height, top: $top, left: $left)';
}


}

/// @nodoc
abstract mixin class _$WindowPropsCopyWith<$Res> implements $WindowPropsCopyWith<$Res> {
  factory _$WindowPropsCopyWith(_WindowProps value, $Res Function(_WindowProps) _then) = __$WindowPropsCopyWithImpl;
@override @useResult
$Res call({
 double width, double height, double? top, double? left
});




}
/// @nodoc
class __$WindowPropsCopyWithImpl<$Res>
    implements _$WindowPropsCopyWith<$Res> {
  __$WindowPropsCopyWithImpl(this._self, this._then);

  final _WindowProps _self;
  final $Res Function(_WindowProps) _then;

/// Create a copy of WindowProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,Object? top = freezed,Object? left = freezed,}) {
  return _then(_WindowProps(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,top: freezed == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as double?,left: freezed == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$VpnProps {

 bool get enable; bool get systemProxy;/// VPN 隧道口本身要不要 IPv6。
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
 bool get ipv6; bool get allowBypass; bool get dnsHijacking; AccessControlProps get accessControlProps;
/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VpnPropsCopyWith<VpnProps> get copyWith => _$VpnPropsCopyWithImpl<VpnProps>(this as VpnProps, _$identity);

  /// Serializes this VpnProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnProps&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.systemProxy, systemProxy) || other.systemProxy == systemProxy)&&(identical(other.ipv6, ipv6) || other.ipv6 == ipv6)&&(identical(other.allowBypass, allowBypass) || other.allowBypass == allowBypass)&&(identical(other.dnsHijacking, dnsHijacking) || other.dnsHijacking == dnsHijacking)&&(identical(other.accessControlProps, accessControlProps) || other.accessControlProps == accessControlProps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,systemProxy,ipv6,allowBypass,dnsHijacking,accessControlProps);

@override
String toString() {
  return 'VpnProps(enable: $enable, systemProxy: $systemProxy, ipv6: $ipv6, allowBypass: $allowBypass, dnsHijacking: $dnsHijacking, accessControlProps: $accessControlProps)';
}


}

/// @nodoc
abstract mixin class $VpnPropsCopyWith<$Res>  {
  factory $VpnPropsCopyWith(VpnProps value, $Res Function(VpnProps) _then) = _$VpnPropsCopyWithImpl;
@useResult
$Res call({
 bool enable, bool systemProxy, bool ipv6, bool allowBypass, bool dnsHijacking, AccessControlProps accessControlProps
});


$AccessControlPropsCopyWith<$Res> get accessControlProps;

}
/// @nodoc
class _$VpnPropsCopyWithImpl<$Res>
    implements $VpnPropsCopyWith<$Res> {
  _$VpnPropsCopyWithImpl(this._self, this._then);

  final VpnProps _self;
  final $Res Function(VpnProps) _then;

/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enable = null,Object? systemProxy = null,Object? ipv6 = null,Object? allowBypass = null,Object? dnsHijacking = null,Object? accessControlProps = null,}) {
  return _then(_self.copyWith(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,systemProxy: null == systemProxy ? _self.systemProxy : systemProxy // ignore: cast_nullable_to_non_nullable
as bool,ipv6: null == ipv6 ? _self.ipv6 : ipv6 // ignore: cast_nullable_to_non_nullable
as bool,allowBypass: null == allowBypass ? _self.allowBypass : allowBypass // ignore: cast_nullable_to_non_nullable
as bool,dnsHijacking: null == dnsHijacking ? _self.dnsHijacking : dnsHijacking // ignore: cast_nullable_to_non_nullable
as bool,accessControlProps: null == accessControlProps ? _self.accessControlProps : accessControlProps // ignore: cast_nullable_to_non_nullable
as AccessControlProps,
  ));
}
/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccessControlPropsCopyWith<$Res> get accessControlProps {
  
  return $AccessControlPropsCopyWith<$Res>(_self.accessControlProps, (value) {
    return _then(_self.copyWith(accessControlProps: value));
  });
}
}


/// Adds pattern-matching-related methods to [VpnProps].
extension VpnPropsPatterns on VpnProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VpnProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VpnProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VpnProps value)  $default,){
final _that = this;
switch (_that) {
case _VpnProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VpnProps value)?  $default,){
final _that = this;
switch (_that) {
case _VpnProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enable,  bool systemProxy,  bool ipv6,  bool allowBypass,  bool dnsHijacking,  AccessControlProps accessControlProps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VpnProps() when $default != null:
return $default(_that.enable,_that.systemProxy,_that.ipv6,_that.allowBypass,_that.dnsHijacking,_that.accessControlProps);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enable,  bool systemProxy,  bool ipv6,  bool allowBypass,  bool dnsHijacking,  AccessControlProps accessControlProps)  $default,) {final _that = this;
switch (_that) {
case _VpnProps():
return $default(_that.enable,_that.systemProxy,_that.ipv6,_that.allowBypass,_that.dnsHijacking,_that.accessControlProps);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enable,  bool systemProxy,  bool ipv6,  bool allowBypass,  bool dnsHijacking,  AccessControlProps accessControlProps)?  $default,) {final _that = this;
switch (_that) {
case _VpnProps() when $default != null:
return $default(_that.enable,_that.systemProxy,_that.ipv6,_that.allowBypass,_that.dnsHijacking,_that.accessControlProps);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VpnProps implements VpnProps {
  const _VpnProps({this.enable = true, this.systemProxy = true, this.ipv6 = true, this.allowBypass = true, this.dnsHijacking = false, this.accessControlProps = defaultAccessControlProps});
  factory _VpnProps.fromJson(Map<String, dynamic> json) => _$VpnPropsFromJson(json);

@override@JsonKey() final  bool enable;
@override@JsonKey() final  bool systemProxy;
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
@override@JsonKey() final  bool ipv6;
@override@JsonKey() final  bool allowBypass;
@override@JsonKey() final  bool dnsHijacking;
@override@JsonKey() final  AccessControlProps accessControlProps;

/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VpnPropsCopyWith<_VpnProps> get copyWith => __$VpnPropsCopyWithImpl<_VpnProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VpnPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VpnProps&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.systemProxy, systemProxy) || other.systemProxy == systemProxy)&&(identical(other.ipv6, ipv6) || other.ipv6 == ipv6)&&(identical(other.allowBypass, allowBypass) || other.allowBypass == allowBypass)&&(identical(other.dnsHijacking, dnsHijacking) || other.dnsHijacking == dnsHijacking)&&(identical(other.accessControlProps, accessControlProps) || other.accessControlProps == accessControlProps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,systemProxy,ipv6,allowBypass,dnsHijacking,accessControlProps);

@override
String toString() {
  return 'VpnProps(enable: $enable, systemProxy: $systemProxy, ipv6: $ipv6, allowBypass: $allowBypass, dnsHijacking: $dnsHijacking, accessControlProps: $accessControlProps)';
}


}

/// @nodoc
abstract mixin class _$VpnPropsCopyWith<$Res> implements $VpnPropsCopyWith<$Res> {
  factory _$VpnPropsCopyWith(_VpnProps value, $Res Function(_VpnProps) _then) = __$VpnPropsCopyWithImpl;
@override @useResult
$Res call({
 bool enable, bool systemProxy, bool ipv6, bool allowBypass, bool dnsHijacking, AccessControlProps accessControlProps
});


@override $AccessControlPropsCopyWith<$Res> get accessControlProps;

}
/// @nodoc
class __$VpnPropsCopyWithImpl<$Res>
    implements _$VpnPropsCopyWith<$Res> {
  __$VpnPropsCopyWithImpl(this._self, this._then);

  final _VpnProps _self;
  final $Res Function(_VpnProps) _then;

/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enable = null,Object? systemProxy = null,Object? ipv6 = null,Object? allowBypass = null,Object? dnsHijacking = null,Object? accessControlProps = null,}) {
  return _then(_VpnProps(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,systemProxy: null == systemProxy ? _self.systemProxy : systemProxy // ignore: cast_nullable_to_non_nullable
as bool,ipv6: null == ipv6 ? _self.ipv6 : ipv6 // ignore: cast_nullable_to_non_nullable
as bool,allowBypass: null == allowBypass ? _self.allowBypass : allowBypass // ignore: cast_nullable_to_non_nullable
as bool,dnsHijacking: null == dnsHijacking ? _self.dnsHijacking : dnsHijacking // ignore: cast_nullable_to_non_nullable
as bool,accessControlProps: null == accessControlProps ? _self.accessControlProps : accessControlProps // ignore: cast_nullable_to_non_nullable
as AccessControlProps,
  ));
}

/// Create a copy of VpnProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccessControlPropsCopyWith<$Res> get accessControlProps {
  
  return $AccessControlPropsCopyWith<$Res>(_self.accessControlProps, (value) {
    return _then(_self.copyWith(accessControlProps: value));
  });
}
}


/// @nodoc
mixin _$NetworkProps {

 bool get systemProxy; List<String> get bypassDomain; RouteMode get routeMode; bool get autoSetSystemDns; bool get appendSystemDns;
/// Create a copy of NetworkProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NetworkPropsCopyWith<NetworkProps> get copyWith => _$NetworkPropsCopyWithImpl<NetworkProps>(this as NetworkProps, _$identity);

  /// Serializes this NetworkProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NetworkProps&&(identical(other.systemProxy, systemProxy) || other.systemProxy == systemProxy)&&const DeepCollectionEquality().equals(other.bypassDomain, bypassDomain)&&(identical(other.routeMode, routeMode) || other.routeMode == routeMode)&&(identical(other.autoSetSystemDns, autoSetSystemDns) || other.autoSetSystemDns == autoSetSystemDns)&&(identical(other.appendSystemDns, appendSystemDns) || other.appendSystemDns == appendSystemDns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,systemProxy,const DeepCollectionEquality().hash(bypassDomain),routeMode,autoSetSystemDns,appendSystemDns);

@override
String toString() {
  return 'NetworkProps(systemProxy: $systemProxy, bypassDomain: $bypassDomain, routeMode: $routeMode, autoSetSystemDns: $autoSetSystemDns, appendSystemDns: $appendSystemDns)';
}


}

/// @nodoc
abstract mixin class $NetworkPropsCopyWith<$Res>  {
  factory $NetworkPropsCopyWith(NetworkProps value, $Res Function(NetworkProps) _then) = _$NetworkPropsCopyWithImpl;
@useResult
$Res call({
 bool systemProxy, List<String> bypassDomain, RouteMode routeMode, bool autoSetSystemDns, bool appendSystemDns
});




}
/// @nodoc
class _$NetworkPropsCopyWithImpl<$Res>
    implements $NetworkPropsCopyWith<$Res> {
  _$NetworkPropsCopyWithImpl(this._self, this._then);

  final NetworkProps _self;
  final $Res Function(NetworkProps) _then;

/// Create a copy of NetworkProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? systemProxy = null,Object? bypassDomain = null,Object? routeMode = null,Object? autoSetSystemDns = null,Object? appendSystemDns = null,}) {
  return _then(_self.copyWith(
systemProxy: null == systemProxy ? _self.systemProxy : systemProxy // ignore: cast_nullable_to_non_nullable
as bool,bypassDomain: null == bypassDomain ? _self.bypassDomain : bypassDomain // ignore: cast_nullable_to_non_nullable
as List<String>,routeMode: null == routeMode ? _self.routeMode : routeMode // ignore: cast_nullable_to_non_nullable
as RouteMode,autoSetSystemDns: null == autoSetSystemDns ? _self.autoSetSystemDns : autoSetSystemDns // ignore: cast_nullable_to_non_nullable
as bool,appendSystemDns: null == appendSystemDns ? _self.appendSystemDns : appendSystemDns // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NetworkProps].
extension NetworkPropsPatterns on NetworkProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NetworkProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NetworkProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NetworkProps value)  $default,){
final _that = this;
switch (_that) {
case _NetworkProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NetworkProps value)?  $default,){
final _that = this;
switch (_that) {
case _NetworkProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool systemProxy,  List<String> bypassDomain,  RouteMode routeMode,  bool autoSetSystemDns,  bool appendSystemDns)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NetworkProps() when $default != null:
return $default(_that.systemProxy,_that.bypassDomain,_that.routeMode,_that.autoSetSystemDns,_that.appendSystemDns);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool systemProxy,  List<String> bypassDomain,  RouteMode routeMode,  bool autoSetSystemDns,  bool appendSystemDns)  $default,) {final _that = this;
switch (_that) {
case _NetworkProps():
return $default(_that.systemProxy,_that.bypassDomain,_that.routeMode,_that.autoSetSystemDns,_that.appendSystemDns);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool systemProxy,  List<String> bypassDomain,  RouteMode routeMode,  bool autoSetSystemDns,  bool appendSystemDns)?  $default,) {final _that = this;
switch (_that) {
case _NetworkProps() when $default != null:
return $default(_that.systemProxy,_that.bypassDomain,_that.routeMode,_that.autoSetSystemDns,_that.appendSystemDns);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NetworkProps implements NetworkProps {
  const _NetworkProps({this.systemProxy = true, final  List<String> bypassDomain = defaultBypassDomain, this.routeMode = RouteMode.config, this.autoSetSystemDns = true, this.appendSystemDns = false}): _bypassDomain = bypassDomain;
  factory _NetworkProps.fromJson(Map<String, dynamic> json) => _$NetworkPropsFromJson(json);

@override@JsonKey() final  bool systemProxy;
 final  List<String> _bypassDomain;
@override@JsonKey() List<String> get bypassDomain {
  if (_bypassDomain is EqualUnmodifiableListView) return _bypassDomain;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bypassDomain);
}

@override@JsonKey() final  RouteMode routeMode;
@override@JsonKey() final  bool autoSetSystemDns;
@override@JsonKey() final  bool appendSystemDns;

/// Create a copy of NetworkProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NetworkPropsCopyWith<_NetworkProps> get copyWith => __$NetworkPropsCopyWithImpl<_NetworkProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NetworkPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NetworkProps&&(identical(other.systemProxy, systemProxy) || other.systemProxy == systemProxy)&&const DeepCollectionEquality().equals(other._bypassDomain, _bypassDomain)&&(identical(other.routeMode, routeMode) || other.routeMode == routeMode)&&(identical(other.autoSetSystemDns, autoSetSystemDns) || other.autoSetSystemDns == autoSetSystemDns)&&(identical(other.appendSystemDns, appendSystemDns) || other.appendSystemDns == appendSystemDns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,systemProxy,const DeepCollectionEquality().hash(_bypassDomain),routeMode,autoSetSystemDns,appendSystemDns);

@override
String toString() {
  return 'NetworkProps(systemProxy: $systemProxy, bypassDomain: $bypassDomain, routeMode: $routeMode, autoSetSystemDns: $autoSetSystemDns, appendSystemDns: $appendSystemDns)';
}


}

/// @nodoc
abstract mixin class _$NetworkPropsCopyWith<$Res> implements $NetworkPropsCopyWith<$Res> {
  factory _$NetworkPropsCopyWith(_NetworkProps value, $Res Function(_NetworkProps) _then) = __$NetworkPropsCopyWithImpl;
@override @useResult
$Res call({
 bool systemProxy, List<String> bypassDomain, RouteMode routeMode, bool autoSetSystemDns, bool appendSystemDns
});




}
/// @nodoc
class __$NetworkPropsCopyWithImpl<$Res>
    implements _$NetworkPropsCopyWith<$Res> {
  __$NetworkPropsCopyWithImpl(this._self, this._then);

  final _NetworkProps _self;
  final $Res Function(_NetworkProps) _then;

/// Create a copy of NetworkProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? systemProxy = null,Object? bypassDomain = null,Object? routeMode = null,Object? autoSetSystemDns = null,Object? appendSystemDns = null,}) {
  return _then(_NetworkProps(
systemProxy: null == systemProxy ? _self.systemProxy : systemProxy // ignore: cast_nullable_to_non_nullable
as bool,bypassDomain: null == bypassDomain ? _self._bypassDomain : bypassDomain // ignore: cast_nullable_to_non_nullable
as List<String>,routeMode: null == routeMode ? _self.routeMode : routeMode // ignore: cast_nullable_to_non_nullable
as RouteMode,autoSetSystemDns: null == autoSetSystemDns ? _self.autoSetSystemDns : autoSetSystemDns // ignore: cast_nullable_to_non_nullable
as bool,appendSystemDns: null == appendSystemDns ? _self.appendSystemDns : appendSystemDns // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ProxiesStyleProps {

 ProxiesSortType get sortType; ProxiesLayout get layout; ProxiesIconStyle get iconStyle; ProxyCardType get cardType;
/// Create a copy of ProxiesStyleProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProxiesStylePropsCopyWith<ProxiesStyleProps> get copyWith => _$ProxiesStylePropsCopyWithImpl<ProxiesStyleProps>(this as ProxiesStyleProps, _$identity);

  /// Serializes this ProxiesStyleProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProxiesStyleProps&&(identical(other.sortType, sortType) || other.sortType == sortType)&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.iconStyle, iconStyle) || other.iconStyle == iconStyle)&&(identical(other.cardType, cardType) || other.cardType == cardType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sortType,layout,iconStyle,cardType);

@override
String toString() {
  return 'ProxiesStyleProps(sortType: $sortType, layout: $layout, iconStyle: $iconStyle, cardType: $cardType)';
}


}

/// @nodoc
abstract mixin class $ProxiesStylePropsCopyWith<$Res>  {
  factory $ProxiesStylePropsCopyWith(ProxiesStyleProps value, $Res Function(ProxiesStyleProps) _then) = _$ProxiesStylePropsCopyWithImpl;
@useResult
$Res call({
 ProxiesSortType sortType, ProxiesLayout layout, ProxiesIconStyle iconStyle, ProxyCardType cardType
});




}
/// @nodoc
class _$ProxiesStylePropsCopyWithImpl<$Res>
    implements $ProxiesStylePropsCopyWith<$Res> {
  _$ProxiesStylePropsCopyWithImpl(this._self, this._then);

  final ProxiesStyleProps _self;
  final $Res Function(ProxiesStyleProps) _then;

/// Create a copy of ProxiesStyleProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sortType = null,Object? layout = null,Object? iconStyle = null,Object? cardType = null,}) {
  return _then(_self.copyWith(
sortType: null == sortType ? _self.sortType : sortType // ignore: cast_nullable_to_non_nullable
as ProxiesSortType,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as ProxiesLayout,iconStyle: null == iconStyle ? _self.iconStyle : iconStyle // ignore: cast_nullable_to_non_nullable
as ProxiesIconStyle,cardType: null == cardType ? _self.cardType : cardType // ignore: cast_nullable_to_non_nullable
as ProxyCardType,
  ));
}

}


/// Adds pattern-matching-related methods to [ProxiesStyleProps].
extension ProxiesStylePropsPatterns on ProxiesStyleProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProxiesStyleProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProxiesStyleProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProxiesStyleProps value)  $default,){
final _that = this;
switch (_that) {
case _ProxiesStyleProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProxiesStyleProps value)?  $default,){
final _that = this;
switch (_that) {
case _ProxiesStyleProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProxiesSortType sortType,  ProxiesLayout layout,  ProxiesIconStyle iconStyle,  ProxyCardType cardType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProxiesStyleProps() when $default != null:
return $default(_that.sortType,_that.layout,_that.iconStyle,_that.cardType);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProxiesSortType sortType,  ProxiesLayout layout,  ProxiesIconStyle iconStyle,  ProxyCardType cardType)  $default,) {final _that = this;
switch (_that) {
case _ProxiesStyleProps():
return $default(_that.sortType,_that.layout,_that.iconStyle,_that.cardType);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProxiesSortType sortType,  ProxiesLayout layout,  ProxiesIconStyle iconStyle,  ProxyCardType cardType)?  $default,) {final _that = this;
switch (_that) {
case _ProxiesStyleProps() when $default != null:
return $default(_that.sortType,_that.layout,_that.iconStyle,_that.cardType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProxiesStyleProps implements ProxiesStyleProps {
  const _ProxiesStyleProps({this.sortType = ProxiesSortType.none, this.layout = ProxiesLayout.standard, this.iconStyle = ProxiesIconStyle.standard, this.cardType = ProxyCardType.expand});
  factory _ProxiesStyleProps.fromJson(Map<String, dynamic> json) => _$ProxiesStylePropsFromJson(json);

@override@JsonKey() final  ProxiesSortType sortType;
@override@JsonKey() final  ProxiesLayout layout;
@override@JsonKey() final  ProxiesIconStyle iconStyle;
@override@JsonKey() final  ProxyCardType cardType;

/// Create a copy of ProxiesStyleProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProxiesStylePropsCopyWith<_ProxiesStyleProps> get copyWith => __$ProxiesStylePropsCopyWithImpl<_ProxiesStyleProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProxiesStylePropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProxiesStyleProps&&(identical(other.sortType, sortType) || other.sortType == sortType)&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.iconStyle, iconStyle) || other.iconStyle == iconStyle)&&(identical(other.cardType, cardType) || other.cardType == cardType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sortType,layout,iconStyle,cardType);

@override
String toString() {
  return 'ProxiesStyleProps(sortType: $sortType, layout: $layout, iconStyle: $iconStyle, cardType: $cardType)';
}


}

/// @nodoc
abstract mixin class _$ProxiesStylePropsCopyWith<$Res> implements $ProxiesStylePropsCopyWith<$Res> {
  factory _$ProxiesStylePropsCopyWith(_ProxiesStyleProps value, $Res Function(_ProxiesStyleProps) _then) = __$ProxiesStylePropsCopyWithImpl;
@override @useResult
$Res call({
 ProxiesSortType sortType, ProxiesLayout layout, ProxiesIconStyle iconStyle, ProxyCardType cardType
});




}
/// @nodoc
class __$ProxiesStylePropsCopyWithImpl<$Res>
    implements _$ProxiesStylePropsCopyWith<$Res> {
  __$ProxiesStylePropsCopyWithImpl(this._self, this._then);

  final _ProxiesStyleProps _self;
  final $Res Function(_ProxiesStyleProps) _then;

/// Create a copy of ProxiesStyleProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sortType = null,Object? layout = null,Object? iconStyle = null,Object? cardType = null,}) {
  return _then(_ProxiesStyleProps(
sortType: null == sortType ? _self.sortType : sortType // ignore: cast_nullable_to_non_nullable
as ProxiesSortType,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as ProxiesLayout,iconStyle: null == iconStyle ? _self.iconStyle : iconStyle // ignore: cast_nullable_to_non_nullable
as ProxiesIconStyle,cardType: null == cardType ? _self.cardType : cardType // ignore: cast_nullable_to_non_nullable
as ProxyCardType,
  ));
}


}


/// @nodoc
mixin _$TextScale {

 bool get enable; double get scale;
/// Create a copy of TextScale
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextScaleCopyWith<TextScale> get copyWith => _$TextScaleCopyWithImpl<TextScale>(this as TextScale, _$identity);

  /// Serializes this TextScale to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextScale&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.scale, scale) || other.scale == scale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,scale);

@override
String toString() {
  return 'TextScale(enable: $enable, scale: $scale)';
}


}

/// @nodoc
abstract mixin class $TextScaleCopyWith<$Res>  {
  factory $TextScaleCopyWith(TextScale value, $Res Function(TextScale) _then) = _$TextScaleCopyWithImpl;
@useResult
$Res call({
 bool enable, double scale
});




}
/// @nodoc
class _$TextScaleCopyWithImpl<$Res>
    implements $TextScaleCopyWith<$Res> {
  _$TextScaleCopyWithImpl(this._self, this._then);

  final TextScale _self;
  final $Res Function(TextScale) _then;

/// Create a copy of TextScale
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enable = null,Object? scale = null,}) {
  return _then(_self.copyWith(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [TextScale].
extension TextScalePatterns on TextScale {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TextScale value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TextScale() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TextScale value)  $default,){
final _that = this;
switch (_that) {
case _TextScale():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TextScale value)?  $default,){
final _that = this;
switch (_that) {
case _TextScale() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enable,  double scale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TextScale() when $default != null:
return $default(_that.enable,_that.scale);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enable,  double scale)  $default,) {final _that = this;
switch (_that) {
case _TextScale():
return $default(_that.enable,_that.scale);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enable,  double scale)?  $default,) {final _that = this;
switch (_that) {
case _TextScale() when $default != null:
return $default(_that.enable,_that.scale);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TextScale implements TextScale {
  const _TextScale({this.enable = false, this.scale = 1.0});
  factory _TextScale.fromJson(Map<String, dynamic> json) => _$TextScaleFromJson(json);

@override@JsonKey() final  bool enable;
@override@JsonKey() final  double scale;

/// Create a copy of TextScale
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TextScaleCopyWith<_TextScale> get copyWith => __$TextScaleCopyWithImpl<_TextScale>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TextScaleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TextScale&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.scale, scale) || other.scale == scale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enable,scale);

@override
String toString() {
  return 'TextScale(enable: $enable, scale: $scale)';
}


}

/// @nodoc
abstract mixin class _$TextScaleCopyWith<$Res> implements $TextScaleCopyWith<$Res> {
  factory _$TextScaleCopyWith(_TextScale value, $Res Function(_TextScale) _then) = __$TextScaleCopyWithImpl;
@override @useResult
$Res call({
 bool enable, double scale
});




}
/// @nodoc
class __$TextScaleCopyWithImpl<$Res>
    implements _$TextScaleCopyWith<$Res> {
  __$TextScaleCopyWithImpl(this._self, this._then);

  final _TextScale _self;
  final $Res Function(_TextScale) _then;

/// Create a copy of TextScale
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enable = null,Object? scale = null,}) {
  return _then(_TextScale(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$ThemeProps {

 ThemeMode get themeMode;/// **必须走 `safeFromJson`。** 生成的解码对认不出的枚举值会直接抛；
/// 「Material You」那一档删掉之后，用过它的机器存档里还留着那个名字，不兜底
/// 的话整份配置读不出来——用户看到的是应用起不来，而不是"风格变回默认"。
@JsonKey(fromJson: AppStyle.safeFromJson) AppStyle get appStyle; TextScale get textScale;
/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThemePropsCopyWith<ThemeProps> get copyWith => _$ThemePropsCopyWithImpl<ThemeProps>(this as ThemeProps, _$identity);

  /// Serializes this ThemeProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeProps&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.appStyle, appStyle) || other.appStyle == appStyle)&&(identical(other.textScale, textScale) || other.textScale == textScale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,themeMode,appStyle,textScale);

@override
String toString() {
  return 'ThemeProps(themeMode: $themeMode, appStyle: $appStyle, textScale: $textScale)';
}


}

/// @nodoc
abstract mixin class $ThemePropsCopyWith<$Res>  {
  factory $ThemePropsCopyWith(ThemeProps value, $Res Function(ThemeProps) _then) = _$ThemePropsCopyWithImpl;
@useResult
$Res call({
 ThemeMode themeMode,@JsonKey(fromJson: AppStyle.safeFromJson) AppStyle appStyle, TextScale textScale
});


$TextScaleCopyWith<$Res> get textScale;

}
/// @nodoc
class _$ThemePropsCopyWithImpl<$Res>
    implements $ThemePropsCopyWith<$Res> {
  _$ThemePropsCopyWithImpl(this._self, this._then);

  final ThemeProps _self;
  final $Res Function(ThemeProps) _then;

/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeMode = null,Object? appStyle = null,Object? textScale = null,}) {
  return _then(_self.copyWith(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,appStyle: null == appStyle ? _self.appStyle : appStyle // ignore: cast_nullable_to_non_nullable
as AppStyle,textScale: null == textScale ? _self.textScale : textScale // ignore: cast_nullable_to_non_nullable
as TextScale,
  ));
}
/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TextScaleCopyWith<$Res> get textScale {
  
  return $TextScaleCopyWith<$Res>(_self.textScale, (value) {
    return _then(_self.copyWith(textScale: value));
  });
}
}


/// Adds pattern-matching-related methods to [ThemeProps].
extension ThemePropsPatterns on ThemeProps {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThemeProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThemeProps() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThemeProps value)  $default,){
final _that = this;
switch (_that) {
case _ThemeProps():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThemeProps value)?  $default,){
final _that = this;
switch (_that) {
case _ThemeProps() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ThemeMode themeMode, @JsonKey(fromJson: AppStyle.safeFromJson)  AppStyle appStyle,  TextScale textScale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThemeProps() when $default != null:
return $default(_that.themeMode,_that.appStyle,_that.textScale);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ThemeMode themeMode, @JsonKey(fromJson: AppStyle.safeFromJson)  AppStyle appStyle,  TextScale textScale)  $default,) {final _that = this;
switch (_that) {
case _ThemeProps():
return $default(_that.themeMode,_that.appStyle,_that.textScale);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ThemeMode themeMode, @JsonKey(fromJson: AppStyle.safeFromJson)  AppStyle appStyle,  TextScale textScale)?  $default,) {final _that = this;
switch (_that) {
case _ThemeProps() when $default != null:
return $default(_that.themeMode,_that.appStyle,_that.textScale);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ThemeProps implements ThemeProps {
  const _ThemeProps({this.themeMode = ThemeMode.dark, @JsonKey(fromJson: AppStyle.safeFromJson) this.appStyle = AppStyle.clashParty, this.textScale = const TextScale()});
  factory _ThemeProps.fromJson(Map<String, dynamic> json) => _$ThemePropsFromJson(json);

@override@JsonKey() final  ThemeMode themeMode;
/// **必须走 `safeFromJson`。** 生成的解码对认不出的枚举值会直接抛；
/// 「Material You」那一档删掉之后，用过它的机器存档里还留着那个名字，不兜底
/// 的话整份配置读不出来——用户看到的是应用起不来，而不是"风格变回默认"。
@override@JsonKey(fromJson: AppStyle.safeFromJson) final  AppStyle appStyle;
@override@JsonKey() final  TextScale textScale;

/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemePropsCopyWith<_ThemeProps> get copyWith => __$ThemePropsCopyWithImpl<_ThemeProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ThemePropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeProps&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.appStyle, appStyle) || other.appStyle == appStyle)&&(identical(other.textScale, textScale) || other.textScale == textScale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,themeMode,appStyle,textScale);

@override
String toString() {
  return 'ThemeProps(themeMode: $themeMode, appStyle: $appStyle, textScale: $textScale)';
}


}

/// @nodoc
abstract mixin class _$ThemePropsCopyWith<$Res> implements $ThemePropsCopyWith<$Res> {
  factory _$ThemePropsCopyWith(_ThemeProps value, $Res Function(_ThemeProps) _then) = __$ThemePropsCopyWithImpl;
@override @useResult
$Res call({
 ThemeMode themeMode,@JsonKey(fromJson: AppStyle.safeFromJson) AppStyle appStyle, TextScale textScale
});


@override $TextScaleCopyWith<$Res> get textScale;

}
/// @nodoc
class __$ThemePropsCopyWithImpl<$Res>
    implements _$ThemePropsCopyWith<$Res> {
  __$ThemePropsCopyWithImpl(this._self, this._then);

  final _ThemeProps _self;
  final $Res Function(_ThemeProps) _then;

/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeMode = null,Object? appStyle = null,Object? textScale = null,}) {
  return _then(_ThemeProps(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,appStyle: null == appStyle ? _self.appStyle : appStyle // ignore: cast_nullable_to_non_nullable
as AppStyle,textScale: null == textScale ? _self.textScale : textScale // ignore: cast_nullable_to_non_nullable
as TextScale,
  ));
}

/// Create a copy of ThemeProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TextScaleCopyWith<$Res> get textScale {
  
  return $TextScaleCopyWith<$Res>(_self.textScale, (value) {
    return _then(_self.copyWith(textScale: value));
  });
}
}


/// @nodoc
mixin _$Config {

 int? get currentProfileId; bool get overrideDns; List<HotKeyAction> get hotKeyActions;@JsonKey(fromJson: AppSettingProps.safeFromJson) AppSettingProps get appSettingProps; DAVProps? get davProps; NetworkProps get networkProps; VpnProps get vpnProps;@JsonKey(fromJson: ThemeProps.safeFromJson) ThemeProps get themeProps; ProxiesStyleProps get proxiesStyleProps; WindowProps get windowProps; PatchClashConfig get patchClashConfig; List<String> get excludeSSIDs;
/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfigCopyWith<Config> get copyWith => _$ConfigCopyWithImpl<Config>(this as Config, _$identity);

  /// Serializes this Config to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Config&&(identical(other.currentProfileId, currentProfileId) || other.currentProfileId == currentProfileId)&&(identical(other.overrideDns, overrideDns) || other.overrideDns == overrideDns)&&const DeepCollectionEquality().equals(other.hotKeyActions, hotKeyActions)&&(identical(other.appSettingProps, appSettingProps) || other.appSettingProps == appSettingProps)&&(identical(other.davProps, davProps) || other.davProps == davProps)&&(identical(other.networkProps, networkProps) || other.networkProps == networkProps)&&(identical(other.vpnProps, vpnProps) || other.vpnProps == vpnProps)&&(identical(other.themeProps, themeProps) || other.themeProps == themeProps)&&(identical(other.proxiesStyleProps, proxiesStyleProps) || other.proxiesStyleProps == proxiesStyleProps)&&(identical(other.windowProps, windowProps) || other.windowProps == windowProps)&&(identical(other.patchClashConfig, patchClashConfig) || other.patchClashConfig == patchClashConfig)&&const DeepCollectionEquality().equals(other.excludeSSIDs, excludeSSIDs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentProfileId,overrideDns,const DeepCollectionEquality().hash(hotKeyActions),appSettingProps,davProps,networkProps,vpnProps,themeProps,proxiesStyleProps,windowProps,patchClashConfig,const DeepCollectionEquality().hash(excludeSSIDs));

@override
String toString() {
  return 'Config(currentProfileId: $currentProfileId, overrideDns: $overrideDns, hotKeyActions: $hotKeyActions, appSettingProps: $appSettingProps, davProps: $davProps, networkProps: $networkProps, vpnProps: $vpnProps, themeProps: $themeProps, proxiesStyleProps: $proxiesStyleProps, windowProps: $windowProps, patchClashConfig: $patchClashConfig, excludeSSIDs: $excludeSSIDs)';
}


}

/// @nodoc
abstract mixin class $ConfigCopyWith<$Res>  {
  factory $ConfigCopyWith(Config value, $Res Function(Config) _then) = _$ConfigCopyWithImpl;
@useResult
$Res call({
 int? currentProfileId, bool overrideDns, List<HotKeyAction> hotKeyActions,@JsonKey(fromJson: AppSettingProps.safeFromJson) AppSettingProps appSettingProps, DAVProps? davProps, NetworkProps networkProps, VpnProps vpnProps,@JsonKey(fromJson: ThemeProps.safeFromJson) ThemeProps themeProps, ProxiesStyleProps proxiesStyleProps, WindowProps windowProps, PatchClashConfig patchClashConfig, List<String> excludeSSIDs
});


$AppSettingPropsCopyWith<$Res> get appSettingProps;$DAVPropsCopyWith<$Res>? get davProps;$NetworkPropsCopyWith<$Res> get networkProps;$VpnPropsCopyWith<$Res> get vpnProps;$ThemePropsCopyWith<$Res> get themeProps;$ProxiesStylePropsCopyWith<$Res> get proxiesStyleProps;$WindowPropsCopyWith<$Res> get windowProps;$PatchClashConfigCopyWith<$Res> get patchClashConfig;

}
/// @nodoc
class _$ConfigCopyWithImpl<$Res>
    implements $ConfigCopyWith<$Res> {
  _$ConfigCopyWithImpl(this._self, this._then);

  final Config _self;
  final $Res Function(Config) _then;

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentProfileId = freezed,Object? overrideDns = null,Object? hotKeyActions = null,Object? appSettingProps = null,Object? davProps = freezed,Object? networkProps = null,Object? vpnProps = null,Object? themeProps = null,Object? proxiesStyleProps = null,Object? windowProps = null,Object? patchClashConfig = null,Object? excludeSSIDs = null,}) {
  return _then(_self.copyWith(
currentProfileId: freezed == currentProfileId ? _self.currentProfileId : currentProfileId // ignore: cast_nullable_to_non_nullable
as int?,overrideDns: null == overrideDns ? _self.overrideDns : overrideDns // ignore: cast_nullable_to_non_nullable
as bool,hotKeyActions: null == hotKeyActions ? _self.hotKeyActions : hotKeyActions // ignore: cast_nullable_to_non_nullable
as List<HotKeyAction>,appSettingProps: null == appSettingProps ? _self.appSettingProps : appSettingProps // ignore: cast_nullable_to_non_nullable
as AppSettingProps,davProps: freezed == davProps ? _self.davProps : davProps // ignore: cast_nullable_to_non_nullable
as DAVProps?,networkProps: null == networkProps ? _self.networkProps : networkProps // ignore: cast_nullable_to_non_nullable
as NetworkProps,vpnProps: null == vpnProps ? _self.vpnProps : vpnProps // ignore: cast_nullable_to_non_nullable
as VpnProps,themeProps: null == themeProps ? _self.themeProps : themeProps // ignore: cast_nullable_to_non_nullable
as ThemeProps,proxiesStyleProps: null == proxiesStyleProps ? _self.proxiesStyleProps : proxiesStyleProps // ignore: cast_nullable_to_non_nullable
as ProxiesStyleProps,windowProps: null == windowProps ? _self.windowProps : windowProps // ignore: cast_nullable_to_non_nullable
as WindowProps,patchClashConfig: null == patchClashConfig ? _self.patchClashConfig : patchClashConfig // ignore: cast_nullable_to_non_nullable
as PatchClashConfig,excludeSSIDs: null == excludeSSIDs ? _self.excludeSSIDs : excludeSSIDs // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppSettingPropsCopyWith<$Res> get appSettingProps {
  
  return $AppSettingPropsCopyWith<$Res>(_self.appSettingProps, (value) {
    return _then(_self.copyWith(appSettingProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DAVPropsCopyWith<$Res>? get davProps {
    if (_self.davProps == null) {
    return null;
  }

  return $DAVPropsCopyWith<$Res>(_self.davProps!, (value) {
    return _then(_self.copyWith(davProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NetworkPropsCopyWith<$Res> get networkProps {
  
  return $NetworkPropsCopyWith<$Res>(_self.networkProps, (value) {
    return _then(_self.copyWith(networkProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VpnPropsCopyWith<$Res> get vpnProps {
  
  return $VpnPropsCopyWith<$Res>(_self.vpnProps, (value) {
    return _then(_self.copyWith(vpnProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThemePropsCopyWith<$Res> get themeProps {
  
  return $ThemePropsCopyWith<$Res>(_self.themeProps, (value) {
    return _then(_self.copyWith(themeProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProxiesStylePropsCopyWith<$Res> get proxiesStyleProps {
  
  return $ProxiesStylePropsCopyWith<$Res>(_self.proxiesStyleProps, (value) {
    return _then(_self.copyWith(proxiesStyleProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPropsCopyWith<$Res> get windowProps {
  
  return $WindowPropsCopyWith<$Res>(_self.windowProps, (value) {
    return _then(_self.copyWith(windowProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PatchClashConfigCopyWith<$Res> get patchClashConfig {
  
  return $PatchClashConfigCopyWith<$Res>(_self.patchClashConfig, (value) {
    return _then(_self.copyWith(patchClashConfig: value));
  });
}
}


/// Adds pattern-matching-related methods to [Config].
extension ConfigPatterns on Config {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Config value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Config() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Config value)  $default,){
final _that = this;
switch (_that) {
case _Config():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Config value)?  $default,){
final _that = this;
switch (_that) {
case _Config() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? currentProfileId,  bool overrideDns,  List<HotKeyAction> hotKeyActions, @JsonKey(fromJson: AppSettingProps.safeFromJson)  AppSettingProps appSettingProps,  DAVProps? davProps,  NetworkProps networkProps,  VpnProps vpnProps, @JsonKey(fromJson: ThemeProps.safeFromJson)  ThemeProps themeProps,  ProxiesStyleProps proxiesStyleProps,  WindowProps windowProps,  PatchClashConfig patchClashConfig,  List<String> excludeSSIDs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Config() when $default != null:
return $default(_that.currentProfileId,_that.overrideDns,_that.hotKeyActions,_that.appSettingProps,_that.davProps,_that.networkProps,_that.vpnProps,_that.themeProps,_that.proxiesStyleProps,_that.windowProps,_that.patchClashConfig,_that.excludeSSIDs);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? currentProfileId,  bool overrideDns,  List<HotKeyAction> hotKeyActions, @JsonKey(fromJson: AppSettingProps.safeFromJson)  AppSettingProps appSettingProps,  DAVProps? davProps,  NetworkProps networkProps,  VpnProps vpnProps, @JsonKey(fromJson: ThemeProps.safeFromJson)  ThemeProps themeProps,  ProxiesStyleProps proxiesStyleProps,  WindowProps windowProps,  PatchClashConfig patchClashConfig,  List<String> excludeSSIDs)  $default,) {final _that = this;
switch (_that) {
case _Config():
return $default(_that.currentProfileId,_that.overrideDns,_that.hotKeyActions,_that.appSettingProps,_that.davProps,_that.networkProps,_that.vpnProps,_that.themeProps,_that.proxiesStyleProps,_that.windowProps,_that.patchClashConfig,_that.excludeSSIDs);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? currentProfileId,  bool overrideDns,  List<HotKeyAction> hotKeyActions, @JsonKey(fromJson: AppSettingProps.safeFromJson)  AppSettingProps appSettingProps,  DAVProps? davProps,  NetworkProps networkProps,  VpnProps vpnProps, @JsonKey(fromJson: ThemeProps.safeFromJson)  ThemeProps themeProps,  ProxiesStyleProps proxiesStyleProps,  WindowProps windowProps,  PatchClashConfig patchClashConfig,  List<String> excludeSSIDs)?  $default,) {final _that = this;
switch (_that) {
case _Config() when $default != null:
return $default(_that.currentProfileId,_that.overrideDns,_that.hotKeyActions,_that.appSettingProps,_that.davProps,_that.networkProps,_that.vpnProps,_that.themeProps,_that.proxiesStyleProps,_that.windowProps,_that.patchClashConfig,_that.excludeSSIDs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Config implements Config {
  const _Config({this.currentProfileId, this.overrideDns = false, final  List<HotKeyAction> hotKeyActions = const [], @JsonKey(fromJson: AppSettingProps.safeFromJson) this.appSettingProps = defaultAppSettingProps, this.davProps, this.networkProps = defaultNetworkProps, this.vpnProps = defaultVpnProps, @JsonKey(fromJson: ThemeProps.safeFromJson) required this.themeProps, this.proxiesStyleProps = defaultProxiesStyleProps, this.windowProps = defaultWindowProps, this.patchClashConfig = defaultClashConfig, final  List<String> excludeSSIDs = const []}): _hotKeyActions = hotKeyActions,_excludeSSIDs = excludeSSIDs;
  factory _Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);

@override final  int? currentProfileId;
@override@JsonKey() final  bool overrideDns;
 final  List<HotKeyAction> _hotKeyActions;
@override@JsonKey() List<HotKeyAction> get hotKeyActions {
  if (_hotKeyActions is EqualUnmodifiableListView) return _hotKeyActions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hotKeyActions);
}

@override@JsonKey(fromJson: AppSettingProps.safeFromJson) final  AppSettingProps appSettingProps;
@override final  DAVProps? davProps;
@override@JsonKey() final  NetworkProps networkProps;
@override@JsonKey() final  VpnProps vpnProps;
@override@JsonKey(fromJson: ThemeProps.safeFromJson) final  ThemeProps themeProps;
@override@JsonKey() final  ProxiesStyleProps proxiesStyleProps;
@override@JsonKey() final  WindowProps windowProps;
@override@JsonKey() final  PatchClashConfig patchClashConfig;
 final  List<String> _excludeSSIDs;
@override@JsonKey() List<String> get excludeSSIDs {
  if (_excludeSSIDs is EqualUnmodifiableListView) return _excludeSSIDs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_excludeSSIDs);
}


/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConfigCopyWith<_Config> get copyWith => __$ConfigCopyWithImpl<_Config>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Config&&(identical(other.currentProfileId, currentProfileId) || other.currentProfileId == currentProfileId)&&(identical(other.overrideDns, overrideDns) || other.overrideDns == overrideDns)&&const DeepCollectionEquality().equals(other._hotKeyActions, _hotKeyActions)&&(identical(other.appSettingProps, appSettingProps) || other.appSettingProps == appSettingProps)&&(identical(other.davProps, davProps) || other.davProps == davProps)&&(identical(other.networkProps, networkProps) || other.networkProps == networkProps)&&(identical(other.vpnProps, vpnProps) || other.vpnProps == vpnProps)&&(identical(other.themeProps, themeProps) || other.themeProps == themeProps)&&(identical(other.proxiesStyleProps, proxiesStyleProps) || other.proxiesStyleProps == proxiesStyleProps)&&(identical(other.windowProps, windowProps) || other.windowProps == windowProps)&&(identical(other.patchClashConfig, patchClashConfig) || other.patchClashConfig == patchClashConfig)&&const DeepCollectionEquality().equals(other._excludeSSIDs, _excludeSSIDs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentProfileId,overrideDns,const DeepCollectionEquality().hash(_hotKeyActions),appSettingProps,davProps,networkProps,vpnProps,themeProps,proxiesStyleProps,windowProps,patchClashConfig,const DeepCollectionEquality().hash(_excludeSSIDs));

@override
String toString() {
  return 'Config(currentProfileId: $currentProfileId, overrideDns: $overrideDns, hotKeyActions: $hotKeyActions, appSettingProps: $appSettingProps, davProps: $davProps, networkProps: $networkProps, vpnProps: $vpnProps, themeProps: $themeProps, proxiesStyleProps: $proxiesStyleProps, windowProps: $windowProps, patchClashConfig: $patchClashConfig, excludeSSIDs: $excludeSSIDs)';
}


}

/// @nodoc
abstract mixin class _$ConfigCopyWith<$Res> implements $ConfigCopyWith<$Res> {
  factory _$ConfigCopyWith(_Config value, $Res Function(_Config) _then) = __$ConfigCopyWithImpl;
@override @useResult
$Res call({
 int? currentProfileId, bool overrideDns, List<HotKeyAction> hotKeyActions,@JsonKey(fromJson: AppSettingProps.safeFromJson) AppSettingProps appSettingProps, DAVProps? davProps, NetworkProps networkProps, VpnProps vpnProps,@JsonKey(fromJson: ThemeProps.safeFromJson) ThemeProps themeProps, ProxiesStyleProps proxiesStyleProps, WindowProps windowProps, PatchClashConfig patchClashConfig, List<String> excludeSSIDs
});


@override $AppSettingPropsCopyWith<$Res> get appSettingProps;@override $DAVPropsCopyWith<$Res>? get davProps;@override $NetworkPropsCopyWith<$Res> get networkProps;@override $VpnPropsCopyWith<$Res> get vpnProps;@override $ThemePropsCopyWith<$Res> get themeProps;@override $ProxiesStylePropsCopyWith<$Res> get proxiesStyleProps;@override $WindowPropsCopyWith<$Res> get windowProps;@override $PatchClashConfigCopyWith<$Res> get patchClashConfig;

}
/// @nodoc
class __$ConfigCopyWithImpl<$Res>
    implements _$ConfigCopyWith<$Res> {
  __$ConfigCopyWithImpl(this._self, this._then);

  final _Config _self;
  final $Res Function(_Config) _then;

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentProfileId = freezed,Object? overrideDns = null,Object? hotKeyActions = null,Object? appSettingProps = null,Object? davProps = freezed,Object? networkProps = null,Object? vpnProps = null,Object? themeProps = null,Object? proxiesStyleProps = null,Object? windowProps = null,Object? patchClashConfig = null,Object? excludeSSIDs = null,}) {
  return _then(_Config(
currentProfileId: freezed == currentProfileId ? _self.currentProfileId : currentProfileId // ignore: cast_nullable_to_non_nullable
as int?,overrideDns: null == overrideDns ? _self.overrideDns : overrideDns // ignore: cast_nullable_to_non_nullable
as bool,hotKeyActions: null == hotKeyActions ? _self._hotKeyActions : hotKeyActions // ignore: cast_nullable_to_non_nullable
as List<HotKeyAction>,appSettingProps: null == appSettingProps ? _self.appSettingProps : appSettingProps // ignore: cast_nullable_to_non_nullable
as AppSettingProps,davProps: freezed == davProps ? _self.davProps : davProps // ignore: cast_nullable_to_non_nullable
as DAVProps?,networkProps: null == networkProps ? _self.networkProps : networkProps // ignore: cast_nullable_to_non_nullable
as NetworkProps,vpnProps: null == vpnProps ? _self.vpnProps : vpnProps // ignore: cast_nullable_to_non_nullable
as VpnProps,themeProps: null == themeProps ? _self.themeProps : themeProps // ignore: cast_nullable_to_non_nullable
as ThemeProps,proxiesStyleProps: null == proxiesStyleProps ? _self.proxiesStyleProps : proxiesStyleProps // ignore: cast_nullable_to_non_nullable
as ProxiesStyleProps,windowProps: null == windowProps ? _self.windowProps : windowProps // ignore: cast_nullable_to_non_nullable
as WindowProps,patchClashConfig: null == patchClashConfig ? _self.patchClashConfig : patchClashConfig // ignore: cast_nullable_to_non_nullable
as PatchClashConfig,excludeSSIDs: null == excludeSSIDs ? _self._excludeSSIDs : excludeSSIDs // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppSettingPropsCopyWith<$Res> get appSettingProps {
  
  return $AppSettingPropsCopyWith<$Res>(_self.appSettingProps, (value) {
    return _then(_self.copyWith(appSettingProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DAVPropsCopyWith<$Res>? get davProps {
    if (_self.davProps == null) {
    return null;
  }

  return $DAVPropsCopyWith<$Res>(_self.davProps!, (value) {
    return _then(_self.copyWith(davProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NetworkPropsCopyWith<$Res> get networkProps {
  
  return $NetworkPropsCopyWith<$Res>(_self.networkProps, (value) {
    return _then(_self.copyWith(networkProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VpnPropsCopyWith<$Res> get vpnProps {
  
  return $VpnPropsCopyWith<$Res>(_self.vpnProps, (value) {
    return _then(_self.copyWith(vpnProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThemePropsCopyWith<$Res> get themeProps {
  
  return $ThemePropsCopyWith<$Res>(_self.themeProps, (value) {
    return _then(_self.copyWith(themeProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProxiesStylePropsCopyWith<$Res> get proxiesStyleProps {
  
  return $ProxiesStylePropsCopyWith<$Res>(_self.proxiesStyleProps, (value) {
    return _then(_self.copyWith(proxiesStyleProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPropsCopyWith<$Res> get windowProps {
  
  return $WindowPropsCopyWith<$Res>(_self.windowProps, (value) {
    return _then(_self.copyWith(windowProps: value));
  });
}/// Create a copy of Config
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PatchClashConfigCopyWith<$Res> get patchClashConfig {
  
  return $PatchClashConfigCopyWith<$Res>(_self.patchClashConfig, (value) {
    return _then(_self.copyWith(patchClashConfig: value));
  });
}
}

// dart format on
