import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'clash_config.dart';

part 'generated/common.freezed.dart';

part 'generated/common.g.dart';

@freezed
abstract class NavigationItem with _$NavigationItem {
  const factory NavigationItem({
    required Icon icon,
    required PageLabel label,
    final String? description,
    required WidgetBuilder builder,
    @Default(true) bool keep,
    String? path,
    @Default([NavigationItemMode.mobile, NavigationItemMode.desktop])
    List<NavigationItemMode> modes,
  }) = _NavigationItem;
}

@freezed
abstract class Package with _$Package {
  const factory Package({
    required String packageName,
    required String label,
    required bool system,
    required bool internet,
    required int lastUpdateTime,
  }) = _Package;

  factory Package.fromJson(Map<String, Object?> json) =>
      _$PackageFromJson(json);
}

extension PackagesExt on List<Package> {
  List<Package> getViewList({
    required List<String> pinedList,
    required AccessSortType sortType,
    required bool isFilterSystemApp,
    required bool isFilterNonInternetApp,
  }) {
    return where(
      (item) =>
          (isFilterSystemApp ? item.system == false : true) &&
          (isFilterNonInternetApp ? item.internet == true : true),
    ).sorted((a, b) {
      final isSelectA = pinedList.contains(a.packageName);
      final isSelectB = pinedList.contains(b.packageName);

      if (isSelectA != isSelectB) {
        return isSelectA ? -1 : 1;
      }
      return switch (sortType) {
        AccessSortType.none => 0,
        AccessSortType.name => a.label.compareTo(b.label),
        AccessSortType.time => b.lastUpdateTime.compareTo(a.lastUpdateTime),
      };
    });
  }
}

@freezed
abstract class Metadata with _$Metadata {
  const factory Metadata({
    @Default(0) int uid,
    @Default('') String network,
    @Default('') String sourceIP,
    @Default('') String sourcePort,
    @Default('') String destinationIP,
    @Default('') String destinationPort,
    @Default('') String host,
    DnsMode? dnsMode,
    @Default('') String process,
    @Default('') String processPath,
    @Default('') String remoteDestination,
    @Default([]) List<String> sourceGeoIP,
    @Default([]) List<String> destinationGeoIP,
    @Default('') String destinationIPASN,
    @Default('') String sourceIPASN,
    @Default('') String specialRules,
    @Default('') String specialProxy,
  }) = _Metadata;

  factory Metadata.fromJson(Map<String, Object?> json) =>
      _$MetadataFromJson(json);
}

@freezed
abstract class TrackerInfo with _$TrackerInfo {
  const factory TrackerInfo({
    required String id,
    @Default(0) int upload,
    @Default(0) int download,
    required DateTime start,
    required Metadata metadata,
    required List<String> chains,
    required String rule,
    required String rulePayload,
    int? downloadSpeed,
    int? uploadSpeed,
  }) = _TrackerInfo;

  factory TrackerInfo.fromJson(Map<String, Object?> json) =>
      _$TrackerInfoFromJson(json);
}

extension TrackerInfoExt on TrackerInfo {
  String get desc {
    var text = '${metadata.network}://';
    final ips = [
      metadata.host,
      metadata.destinationIP,
    ].where((ip) => ip.isNotEmpty);
    text += ips.join('/');
    text += ':${metadata.destinationPort}';
    return text;
  }

  String get progressText {
    final process = metadata.process;
    final uid = metadata.uid;
    if (uid != 0) {
      return '$process($uid)'.trim();
    }
    return process.trim();
  }
}

String _logDateTime(dynamic _) {
  return DateTime.now().showFull;
}

// String _logId(_) {
//   return utils.id;
// }

@freezed
abstract class Log with _$Log {
  const factory Log({
    // @JsonKey(fromJson: _logId) required String id,
    @JsonKey(name: 'LogLevel') @Default(LogLevel.info) LogLevel logLevel,
    @JsonKey(name: 'Payload') @Default('') String payload,
    @JsonKey(fromJson: _logDateTime) required String dateTime,
  }) = _Log;

  factory Log.app(String payload) {
    return Log(
      payload: payload,
      dateTime: _logDateTime(null),
      // id: _logId(null),
    );
  }

  factory Log.fromJson(Map<String, Object?> json) => _$LogFromJson(json);
}

@freezed
abstract class LogsState with _$LogsState {
  const factory LogsState({
    @Default([]) List<Log> logs,
    @Default([]) List<String> keywords,
    @Default('') String query,
    @Default(true) bool autoScrollToEnd,
  }) = _LogsState;
}

extension LogsStateExt on LogsState {
  List<Log> get list {
    // 没在搜也没选级别时，下面那个 where 的结果必然是「全都要」：keywords 为空
    // 让第一个条件恒真，空串的 contains 也恒真。但它照样会把每条日志的 payload
    // （可能好几 KB）复制成小写再扫一遍——而这个 getter 在 build 里调用，
    // 日志页每秒刷新一次、缓冲有上千条。默认状态下这些活全是白干的。
    //
    // 直接把原列表还回去。freezed 给的是 EqualUnmodifiableListView，
    // 本来就不可变，不存在被调用方改坏的问题。
    if (query.isEmpty && keywords.isEmpty) {
      return logs;
    }
    final lowQuery = query.toLowerCase();
    return logs.where((log) {
      final logLevelName = log.logLevel.name;
      return (keywords.isEmpty || keywords.contains(logLevelName)) &&
          ((log.payload.toLowerCase().contains(lowQuery)) ||
              logLevelName.contains(lowQuery));
    }).toList();
  }
}

@freezed
abstract class TrackerInfosState with _$TrackerInfosState {
  const factory TrackerInfosState({
    @Default([]) List<TrackerInfo> trackerInfos,
    @Default([]) List<String> keywords,
    @Default('') String query,
    @Default(true) bool autoScrollToEnd,
  }) = _TrackerInfosState;
}

extension TrackerInfosStateExt on TrackerInfosState {
  List<TrackerInfo> get list {
    // 同 [LogsStateExt.list]：不搜不筛时结果就是原列表，但原来照样要为**每一条**
    // 连接造 5 个小写字符串副本、join 一次代理链、再建一个 Set 去 containsAll。
    // 连接页每秒重建一次、条目上千，这是全 App 最热的一处白干活。
    if (query.isEmpty && keywords.isEmpty) {
      return trackerInfos;
    }
    final lowerQuery = query.toLowerCase().trim();
    final lowQuery = query.toLowerCase();
    return trackerInfos.where((trackerInfo) {
      final chains = trackerInfo.chains;
      final process = trackerInfo.metadata.process;
      final networkText = trackerInfo.metadata.network.toLowerCase();
      final hostText = trackerInfo.metadata.host.toLowerCase();
      final destinationIPText = trackerInfo.metadata.destinationIP
          .toLowerCase();
      final processText = trackerInfo.metadata.process.toLowerCase();
      final chainsText = chains.join('').toLowerCase();
      return {...chains, process}.containsAll(keywords) &&
          (networkText.contains(lowerQuery) ||
              hostText.contains(lowerQuery) ||
              destinationIPText.contains(lowQuery) ||
              processText.contains(lowerQuery) ||
              chainsText.contains(lowerQuery));
    }).toList();
  }
}

const defaultDavFileName = 'backup.zip';
const _davPasswordFormatVersion = 'v1';
const _davPasswordNonceLength = 16;
const _davPasswordObfuscationMask = <int>[
  0x9d,
  0x42,
  0xe7,
  0x1b,
  0x68,
  0xb4,
  0x35,
  0xca,
  0x7f,
  0x20,
  0xd1,
  0x56,
  0x83,
  0xfa,
  0x0c,
  0xa9,
];

// This only prevents accidental plain-text disclosure. It is deliberately not
// a security boundary against reverse engineering or same-user access.
String _encodeDavPassword(String password) {
  if (password.isEmpty) {
    return '';
  }
  final random = Random.secure();
  final nonce = List<int>.generate(
    _davPasswordNonceLength,
    (_) => random.nextInt(256),
    growable: false,
  );
  final passwordBytes = utf8.encode(password);
  final obfuscated = List<int>.generate(
    passwordBytes.length,
    (index) =>
        passwordBytes[index] ^
        nonce[index % nonce.length] ^
        _davPasswordObfuscationMask[index % _davPasswordObfuscationMask.length],
    growable: false,
  );
  return [
    _davPasswordFormatVersion,
    base64UrlEncode(nonce),
    base64UrlEncode(obfuscated),
  ].join('.');
}

String _decodeDavPassword(String? value) {
  if (value == null || value.isEmpty) {
    return '';
  }
  final parts = value.split('.');
  if (parts.length != 3 || parts[0] != _davPasswordFormatVersion) {
    return value;
  }
  try {
    final nonce = base64Url.decode(parts[1]);
    final obfuscated = base64Url.decode(parts[2]);
    if (nonce.length != _davPasswordNonceLength) {
      return '';
    }
    final passwordBytes = List<int>.generate(
      obfuscated.length,
      (index) =>
          obfuscated[index] ^
          nonce[index % nonce.length] ^
          _davPasswordObfuscationMask[index %
              _davPasswordObfuscationMask.length],
      growable: false,
    );
    return utf8.decode(passwordBytes);
  } on FormatException {
    return '';
  }
}

@Freezed(toStringOverride: false)
abstract class DAVProps with _$DAVProps {
  const DAVProps._();

  const factory DAVProps({
    required String uri,
    required String user,
    @JsonKey(fromJson: _decodeDavPassword, toJson: _encodeDavPassword)
    @Default('')
    String password,
    @Default(defaultDavFileName) String fileName,
  }) = _DAVProps;

  factory DAVProps.fromJson(Map<String, Object?> json) =>
      _$DAVPropsFromJson(json);

  @override
  String toString() =>
      'DAVProps(uri: $uri, user: $user, password: ***, fileName: $fileName)';
}

@freezed
abstract class FileInfo with _$FileInfo {
  const factory FileInfo({required int size, DateTime? lastModified}) =
      _FileInfo;
}

extension FileInfoFileExt on File {
  Future<FileInfo?> getFileInfo() async {
    if (!await exists()) {
      return null;
    }
    final size = await length();
    final lastModified = await _getValidLastModified();
    return FileInfo(size: size, lastModified: lastModified);
  }

  Future<DateTime?> _getValidLastModified() async {
    try {
      final value = await lastModified();
      return value.year > 1970 ? value : null;
    } on FileSystemException {
      return null;
    }
  }
}

extension FileInfoExt on FileInfo {
  String getDesc(BuildContext context) {
    final lastModifiedDesc =
        lastModified?.getLastUpdateTimeDesc(context) ??
        context.appLocalizations.unknown;
    return '${size.traffic.show}  ·  $lastModifiedDesc';
  }
}

@freezed
abstract class VersionInfo with _$VersionInfo {
  const factory VersionInfo({
    @Default('') String clashName,
    @Default('') String version,
  }) = _VersionInfo;

  factory VersionInfo.fromJson(Map<String, Object?> json) =>
      _$VersionInfoFromJson(json);
}

@freezed
abstract class Traffic with _$Traffic {
  const factory Traffic({@Default(0) num up, @Default(0) num down}) = _Traffic;

  factory Traffic.fromJson(Map<String, Object?> json) =>
      _$TrafficFromJson(json);
}

extension TrafficExt on Traffic {
  String get speedText {
    return '↑ ${up.traffic.show}/s   ↓ ${down.traffic.show}/s';
  }

  String get desc {
    return '${up.traffic.show} ↑ ${down.traffic.show} ↓';
  }

  String get trayTitle {
    return '${up.shortTraffic.show}/s\n${down.shortTraffic.show}/s';
  }

  num get speed => up + down;
}

@freezed
abstract class TrafficShow with _$TrafficShow {
  const factory TrafficShow({required String value, required String unit}) =
      _TrafficShow;
}

extension TrafficShowExt on TrafficShow {
  /// 数值和单位之间有一个空格，和桌面端 `calcTraffic` 的 `` `${num} KB` `` 一致。
  ///
  /// 空格加在这里而不是 `unit` 里：单位和数值分两个 `Text` 摆的地方（流量磁贴、
  /// 内存磁贴）取的是 `unit` 本身，带空格会多出一个前导空格。
  String get show => '$value $unit';
}

@freezed
abstract class Group with _$Group {
  const factory Group({
    @JsonKey(fromJson: GroupType.parse) required GroupType type,
    @Default([]) List<Proxy> all,
    String? now,
    bool? hidden,
    String? testUrl,
    @Default('') String icon,
    required String name,
  }) = _Group;

  factory Group.fromJson(Map<String, Object?> json) => _$GroupFromJson(json);
}

extension GroupsExt on List<Group> {
  Group? getGroup(String groupName) {
    final index = indexWhere((element) => element.name == groupName);
    return index != -1 ? this[index] : null;
  }
}

extension GroupExt on Group {
  String get realNow => now ?? '';

  String getCurrentSelectedName(String proxyName) {
    if (type.isComputedSelected) {
      return realNow.isNotEmpty ? realNow : proxyName;
    }
    return proxyName.isNotEmpty ? proxyName : realNow;
  }
}

@freezed
abstract class ColorSchemes with _$ColorSchemes {
  const factory ColorSchemes({
    ColorScheme? lightColorScheme,
    ColorScheme? darkColorScheme,
  }) = _ColorSchemes;
}

extension ColorSchemesExt on ColorSchemes {
  ColorScheme getColorSchemeForBrightness(
    Brightness brightness,
    DynamicSchemeVariant schemeVariant,
  ) {
    if (brightness == Brightness.dark) {
      return darkColorScheme != null
          ? ColorScheme.fromSeed(
              seedColor: darkColorScheme!.primary,
              brightness: Brightness.dark,
              dynamicSchemeVariant: schemeVariant,
            )
          : ColorScheme.fromSeed(
              seedColor: const Color(defaultPrimaryColor),
              brightness: Brightness.dark,
              dynamicSchemeVariant: schemeVariant,
            );
    }
    return lightColorScheme != null
        ? ColorScheme.fromSeed(
            seedColor: lightColorScheme!.primary,
            dynamicSchemeVariant: schemeVariant,
          )
        : ColorScheme.fromSeed(
            seedColor: const Color(defaultPrimaryColor),
            dynamicSchemeVariant: schemeVariant,
          );
  }
}

/// 出口 IP 的画像。
///
/// 只有 [ip] 和 [countryCode] 是必填——这两项是「我现在从哪儿出去的」的最小
/// 答案，磁贴上就显示它们。其余字段全部可空：不同数据源给的东西不一样，而
/// [Request.checkIp] 是「谁先返回用谁」的竞速，拿到哪一个源事先并不确定，
/// 所以任何一项都可能缺席，界面必须能只显示拿得到的部分。
@freezed
abstract class IpInfo with _$IpInfo {
  // freezed 生成的实现类只实现 factory 声明的成员；要在类体里写普通方法
  // （这里是 fillMissingFrom），就必须留这个私有构造，否则生成的类会缺实现。
  const IpInfo._();

  const factory IpInfo({
    required String ip,
    required String countryCode,

    /// 国家全名，如 `United States`。[countryCode] 是两位字母代码。
    String? country,
    String? region,
    String? city,
    String? timezone,
    double? latitude,
    double? longitude,

    /// 自治域号，不带 `AS` 前缀。
    int? asn,

    /// 自治域的持有者，如 `Google LLC`。
    String? asnOrganization,
    String? isp,

    /// 使用这段地址的企业，通常比 [asnOrganization] 更具体：ASN 属于机房，
    /// 企业才是租用者。
    String? company,

    /// 地址用途：`hosting`（机房）/ `isp`（家宽）/ `business` / `education`
    /// / `government`。机场节点几乎都是 `hosting`。
    String? ipType,

    /// 第三方给出的滥用风险评分原文，如 `0.0012 (Low)`。**不是我们自己算的**，
    /// 只能当参考。
    String? risk,

    /// ASN 在注册局登记的国家，可能和 [countryCode] 不同：注册在美国的 ASN
    /// 完全可以把机器放在日本。
    String? registryCountry,

    /// 区域互联网注册管理机构，如 `ARIN` / `RIPE` / `APNIC`。
    String? registry,

    /// 这个 IP 所属的路由前缀，如 `8.8.8.0/24`。
    String? cidr,
    bool? isProxy,
    bool? isVpn,
    bool? isTor,

    /// 是否属于机房地址段。为真基本可以确定这是台服务器而不是家宽。
    bool? isDatacenter,
  }) = _IpInfo;

  /// 用 [other] 补上自己缺的字段，已有的一律不动。
  ///
  /// 检测分两步：先竞速拿到 IP 和地区（快，磁贴马上能显示），再单独请求一次
  /// 富信息补齐 ASN / 企业 / 风险这些。第二步的结果用这个方法并进来——「补空」
  /// 而不是「覆盖」，是为了让第一步已经确认的 IP 和国家保持稳定，不会在用户
  /// 眼前跳一下变成另一个值。
  IpInfo fillMissingFrom(IpInfo other) {
    return IpInfo(
      ip: ip,
      countryCode: countryCode.isNotEmpty ? countryCode : other.countryCode,
      country: country ?? other.country,
      region: region ?? other.region,
      city: city ?? other.city,
      timezone: timezone ?? other.timezone,
      latitude: latitude ?? other.latitude,
      longitude: longitude ?? other.longitude,
      asn: asn ?? other.asn,
      asnOrganization: asnOrganization ?? other.asnOrganization,
      isp: isp ?? other.isp,
      company: company ?? other.company,
      ipType: ipType ?? other.ipType,
      risk: risk ?? other.risk,
      registryCountry: registryCountry ?? other.registryCountry,
      registry: registry ?? other.registry,
      cidr: cidr ?? other.cidr,
      isProxy: isProxy ?? other.isProxy,
      isVpn: isVpn ?? other.isVpn,
      isTor: isTor ?? other.isTor,
      isDatacenter: isDatacenter ?? other.isDatacenter,
    );
  }

  static IpInfo fromIpInfoIoJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'country': final String country} => IpInfo(
        ip: ip,
        countryCode: country,
        region: _ipInfoString(json['region']),
        city: _ipInfoString(json['city']),
        timezone: _ipInfoString(json['timezone']),
        // ipinfo.io 把经纬度塞在一个 "37.4056,-122.0775" 里。
        latitude: _ipInfoCoordinate(json['loc'], 0),
        longitude: _ipInfoCoordinate(json['loc'], 1),
        asn: _ipInfoAsnNumber(json['org']),
        asnOrganization: _ipInfoAsnOwner(json['org']),
      ),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromIpApiCoJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'country_code': final String countryCode} =>
        IpInfo(
          ip: ip,
          countryCode: countryCode,
          country: _ipInfoString(json['country_name']),
          region: _ipInfoString(json['region']),
          city: _ipInfoString(json['city']),
          timezone: _ipInfoString(json['timezone']),
          latitude: _ipInfoDouble(json['latitude']),
          longitude: _ipInfoDouble(json['longitude']),
          asn: _ipInfoAsnNumber(json['asn']),
          asnOrganization: _ipInfoString(json['org']),
        ),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromIpSbJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'country_code': final String countryCode} =>
        IpInfo(
          ip: ip,
          countryCode: countryCode,
          country: _ipInfoString(json['country']),
          region: _ipInfoString(json['region']),
          city: _ipInfoString(json['city']),
          timezone: _ipInfoString(json['timezone']),
          latitude: _ipInfoDouble(json['latitude']),
          longitude: _ipInfoDouble(json['longitude']),
          asn: _ipInfoAsnNumber(json['asn']),
          asnOrganization: _ipInfoString(json['asn_organization']),
          isp: _ipInfoString(json['isp']),
        ),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromIpWhoIsJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'country_code': final String countryCode} =>
        IpInfo(
          ip: ip,
          countryCode: countryCode,
          country: _ipInfoString(json['country']),
          region: _ipInfoString(json['region']),
          city: _ipInfoString(json['city']),
          // ipwho.is 的 timezone 是个对象，真正的名字在 id 里。
          timezone: _ipInfoString(_ipInfoMap(json['timezone'])?['id']),
          latitude: _ipInfoDouble(json['latitude']),
          longitude: _ipInfoDouble(json['longitude']),
          asn: _ipInfoAsnNumber(_ipInfoMap(json['connection'])?['asn']),
          asnOrganization: _ipInfoString(
            _ipInfoMap(json['connection'])?['org'],
          ),
          isp: _ipInfoString(_ipInfoMap(json['connection'])?['isp']),
        ),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromMyIpJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'cc': final String countryCode} => IpInfo(
        ip: ip,
        countryCode: countryCode,
        country: _ipInfoString(json['country']),
      ),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromIpAPIJson(Map<String, dynamic> json) {
    return switch (json) {
      {'query': final String ip, 'countryCode': final String countryCode} =>
        IpInfo(
          ip: ip,
          countryCode: countryCode,
          country: _ipInfoString(json['country']),
          region: _ipInfoString(json['regionName']),
          city: _ipInfoString(json['city']),
          timezone: _ipInfoString(json['timezone']),
          latitude: _ipInfoDouble(json['lat']),
          longitude: _ipInfoDouble(json['lon']),
          asn: _ipInfoAsnNumber(json['as']),
          asnOrganization:
              _ipInfoAsnOwner(json['as']) ?? _ipInfoString(json['org']),
          isp: _ipInfoString(json['isp']),
        ),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromIdentMeJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'cc': final String countryCode} => IpInfo(
        ip: ip,
        countryCode: countryCode,
        country: _ipInfoString(json['country']),
        city: _ipInfoString(json['city']),
        timezone: _ipInfoString(json['tz']),
        latitude: _ipInfoDouble(json['latitude']),
        longitude: _ipInfoDouble(json['longitude']),
        asn: _ipInfoAsnNumber(json['asn']),
        asnOrganization: _ipInfoString(json['aso']),
      ),
      _ => throw const FormatException('invalid json'),
    };
  }

  /// ipapi.is 的响应。桌面版（`src/renderer/src/pages/network.tsx`）用的也是
  /// 这个源，它是目前唯一一个同时给出企业、风险评分、注册局和 CIDR 的接口。
  ///
  /// 它把内容分装在 `location` / `asn` / `company` 三个子对象里，顶层只放
  /// `ip` 和一堆 `is_*` 布尔量。
  static IpInfo fromIpApiIsJson(Map<String, dynamic> json) {
    final location = _ipInfoMap(json['location']);
    final asn = _ipInfoMap(json['asn']);
    final company = _ipInfoMap(json['company']);
    final ip = json['ip'];
    final countryCode = _ipInfoString(location?['country_code']);
    if (ip is! String || ip.isEmpty || countryCode == null) {
      throw const FormatException('invalid json');
    }
    return IpInfo(
      ip: ip,
      countryCode: countryCode,
      country: _ipInfoString(location?['country']),
      region: _ipInfoString(location?['state']),
      city: _ipInfoString(location?['city']),
      timezone: _ipInfoString(location?['timezone']),
      latitude: _ipInfoDouble(location?['latitude']),
      longitude: _ipInfoDouble(location?['longitude']),
      asn: _ipInfoAsnNumber(asn?['asn']),
      asnOrganization:
          _ipInfoString(asn?['org']) ?? _ipInfoString(asn?['descr']),
      company: _ipInfoString(company?['name']),
      ipType: _ipInfoString(asn?['type']) ?? _ipInfoString(company?['type']),
      // 两个子对象各有一份评分，企业那份更贴近这个具体地址段。
      risk:
          _ipInfoString(company?['abuser_score']) ??
          _ipInfoString(asn?['abuser_score']),
      registryCountry: _ipInfoString(asn?['country']),
      registry: _ipInfoString(asn?['rir']) ?? _ipInfoString(json['rir']),
      cidr: _ipInfoString(asn?['route']) ?? _ipInfoString(company?['network']),
      isProxy: _ipInfoBool(json['is_proxy']),
      isVpn: _ipInfoBool(json['is_vpn']),
      isTor: _ipInfoBool(json['is_tor']),
      isDatacenter: _ipInfoBool(json['is_datacenter']),
    );
  }
}

/// 下面这几个是 [IpInfo] 各家数据源解析时的取值助手。
///
/// 之所以要它们，是因为这些接口对同一种信息的表达五花八门：经纬度有的是数字
/// 有的是字符串，ASN 有的给 `15169` 有的给 `"AS15169 Google LLC"`，空值有的
/// 给 `null` 有的给空串。全部收敛到「拿不到就返回 null」，调用处不必逐个判断。
String? _ipInfoString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) return value.toString();
  return null;
}

double? _ipInfoDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool? _ipInfoBool(dynamic value) => value is bool ? value : null;

Map<String, dynamic>? _ipInfoMap(dynamic value) =>
    value is Map<String, dynamic> ? value : null;

/// 从 `"37.4056,-122.0775"` 这种合写的坐标里取第 [index] 项。
double? _ipInfoCoordinate(dynamic value, int index) {
  if (value is! String) return null;
  final parts = value.split(',');
  if (index >= parts.length) return null;
  return double.tryParse(parts[index].trim());
}

/// 取自治域号。接受 `15169`、`"15169"`、`"AS15169"`、`"AS15169 Google LLC"`。
int? _ipInfoAsnNumber(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is! String) return null;
  final match = RegExp(
    r'^\s*(?:AS)?(\d+)',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// 取 `"AS15169 Google LLC"` 里 `AS15169` 后面那截持有者名字。
///
/// 只有号码没有名字（`"AS15169"`）时返回 null，不要返回空串——空串会让界面
/// 显示一行有标题没内容的「ASN 所有者」，比不显示更糟。
///
/// 剥号码这一步**必须认准 `AS` 前缀**：有些运营商的名字本身就以数字开头
/// （`"3 Ireland"`），按「开头的数字」去剥会把它剥成 `"Ireland"`。
String? _ipInfoAsnOwner(dynamic value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^\s*AS\d+\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return _ipInfoString(value);
  return _ipInfoString(match.group(1));
}

@freezed
abstract class HotKeyAction with _$HotKeyAction {
  const factory HotKeyAction({
    required HotAction action,
    int? key,
    @Default({}) Set<KeyboardModifier> modifiers,
  }) = _HotKeyAction;

  factory HotKeyAction.fromJson(Map<String, Object?> json) =>
      _$HotKeyActionFromJson(json);
}

typedef Validator = String? Function(String? value);

@freezed
abstract class Field with _$Field {
  const factory Field({
    required String label,
    required String value,
    Validator? validator,
  }) = _Field;
}

class PopupMenuItemData {
  const PopupMenuItemData({
    this.icon,
    required this.label,
    this.onPressed,
    this.danger = false,
    this.subItems = const [],
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final List<PopupMenuItemData> subItems;
}

class CloseWindowIntent extends Intent {
  const CloseWindowIntent();
}

class EscapeBackIntent extends Intent {
  const EscapeBackIntent();
}

@freezed
abstract class Result<T> with _$Result<T> {
  const factory Result({
    required T? data,
    required ResultType type,
    required String message,
  }) = _Result;

  factory Result.success(T data) =>
      Result(data: data, type: ResultType.success, message: '');

  factory Result.error(String message) =>
      Result(data: null, type: ResultType.error, message: message);
}

extension ResultExt on Result {
  bool get isError => type == ResultType.error;

  bool get isSuccess => type == ResultType.success;
}

@freezed
abstract class Script with _$Script {
  const factory Script({
    required int id,
    required String label,
    required DateTime lastUpdateTime,
  }) = _Script;

  factory Script.fromJson(Map<String, Object?> json) => _$ScriptFromJson(json);

  factory Script.create({required String label}) {
    return Script(
      id: snowflake.id,
      label: label,
      lastUpdateTime: DateTime.now(),
    );
  }
}

extension ScriptsExt on List<Script> {
  Script? get(int? id) {
    if (id == null) {
      return null;
    }
    final index = indexWhere((script) => script.id == id);
    if (index != -1) {
      return this[index];
    }
    return null;
  }
}

extension ScriptExt on Script {
  String get fileName => '$id.js';

  Future<String> get path async => appPath.getScriptPath(id.toString());

  Future<String?> get content async {
    final file = File(await path);
    if (await file.exists()) {
      return file.readAsString();
    }
    return null;
  }

  Future<Script> save(String content) async {
    final file = File(await path);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(content);
    return copyWith(lastUpdateTime: DateTime.now());
  }

  Future<Script> saveWithPath(String copyPath) async {
    final file = File(await path);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await File(copyPath).copy(copyPath);
    return copyWith(lastUpdateTime: DateTime.now());
  }
}

@freezed
abstract class DelayState with _$DelayState {
  const factory DelayState({required int delay, required bool group}) =
      _DelayState;
}

extension DelayStateExt on DelayState {
  int get priority {
    if (delay > 0) return 0;
    if (delay == 0) return 1;
    return 2;
  }

  int compareTo(DelayState other) {
    if (priority != other.priority) {
      return priority.compareTo(other.priority);
    }
    if (delay != other.delay) {
      return delay.compareTo(other.delay);
    }
    if (group && !other.group) return -1;
    if (!group && other.group) return 1;
    return 0;
  }
}

@freezed
abstract class UpdatingMessage with _$UpdatingMessage {
  const factory UpdatingMessage({
    required String label,
    required String message,
  }) = _UpdatingMessage;
}

@freezed
abstract class IconButtonData with _$IconButtonData {
  const factory IconButtonData({
    required IconData icon,
    required VoidCallback onPressed,
  }) = _IconButtonData;
}
