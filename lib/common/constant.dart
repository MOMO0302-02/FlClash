// ignore_for_file: constant_identifier_names

import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:flutter/material.dart';

const appName = 'Clash MO';
const appHelperService = 'ClashPartyHelperService';
const coreManifestName = 'manifest.json';
const coreName = 'clash.meta';
const browserUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const packageName = 'com.clashparty.app';
final unixSocketPath = '/tmp/ClashPartySocket_${Random().nextInt(10000)}.sock';
final windowsPipeName = '\\\\.\\pipe\\ClashPartyCore_${_randomPipeId()}';
const helperPort = 47890;
const helperProtocolVersionHeader = 'x-flclash-helper-protocol';
const helperProtocolVersion = '6';
const maxTextScale = 1.4;
const minTextScale = 0.8;
final baseInfoEdgeInsets = EdgeInsets.symmetric(
  vertical: 16.mAp,
  horizontal: 16.mAp,
);
final listHeaderPadding = EdgeInsets.only(
  left: 16.mAp,
  right: 8.mAp,
  top: 24.mAp,
  bottom: 8.mAp,
);
const sheetAppBarHeight = 68.0;

const watchExecution = false;

String _randomPipeId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

final defaultTextScaleFactor =
    WidgetsBinding.instance.platformDispatcher.textScaleFactor;
const httpTimeoutDuration = Duration(milliseconds: 5000);
const moreDuration = Duration(milliseconds: 100);
const animateDuration = Duration(milliseconds: 100);
const midDuration = Duration(milliseconds: 200);
const commonDuration = Duration(milliseconds: 300);
const defaultUpdateDuration = Duration(days: 1);
const MMDB = 'GEOIP.metadb';
const ASN = 'ASN.mmdb';
const GEOIP = 'GEOIP.dat';
const GEOSITE = 'GEOSITE.dat';

/// 随安装包携带、首次启动时拷进工作目录的 geo 数据。
///
/// **[GEOIP] 故意不在此列。** 内核只有在配置写了 `geodata-mode: true` 时才读
/// GeoIP.dat（`component/geodata/init.go:121`），为假时用的是 [MMDB]；而
/// `geoMode` 默认为假、本应用从不写这个键、界面上也没有这个开关。带上它等于让
/// 每台设备白占 20.5 MB，从装到卸都不会被读一次。
///
/// 万一某份订阅真写了 `geodata-mode: true`，内核发现文件不存在会自己下载
/// （`init.go:122-127`），功能不丢。资源页的「更新」按钮走的也是这条路。
const bundledGeoFileNames = [MMDB, GEOSITE, ASN];
final double kHeaderHeight = system.isDesktop
    ? !system.isMacOS
          ? 40
          : 28
    : 0;
const profilesDirectoryName = 'profiles';
const localhost = '127.0.0.1';
const clashConfigKey = 'clash_config';
const configKey = 'config';
const double dialogCommonWidth = 300;
const repository = 'chen08209/ClashParty';
const defaultExternalController = '127.0.0.1:9090';

/// Smart 模型自动更新的间隔，单位小时。内核默认就是 72
/// （`config/config.go` 的 `LgbmUpdateInterval`）。
///
/// 放这儿而不是挨着 `defaultSmartCollectorSize`（在 `common/smart_routing.dart`）：
/// 那个文件管的是"怎么改写代理组"，而 lgbm 这三项是全局顶层键，不属于代理组改写。
/// 页面顶栏高度与标题字号。
///
/// 照桌面端来（`components/base/base-page.tsx:48-50`）：头部 `h-12` = 48，
/// 标题 `text-lg` = 18（`.title` 这个类在全项目 CSS 里没有任何规则，所以字重是
/// 默认的 400，没加粗）。
///
/// Material 3 顶栏的默认值是 56 高、22 号——同一个「仪表盘」在手机上比桌面端整整
/// 大一圈，也比页面里任何一行内容都重，用户原话是「太大了」。
///
/// **48 放得下操作按钮**：Material 的 `IconButton` 默认就是 48×48，正好填满，
/// 点击区一点没缩小。
/// 内核推送流量采样的间隔。
///
/// 出处：内核 `hub/route/server.go:384` 的 `time.NewTicker(time.Second)`。
///
/// 波形动画的时长取这个值——一段动画正好接上下一段，中间没有停顿，看上去是一条
/// 持续在流动的线，而不是"抖一下、停一下"。
const kTrafficSampleInterval = Duration(seconds: 1);

const kAppBarToolbarHeight = 48.0;

/// 悬浮胶囊顶栏离屏幕左右两边的距离。
///
/// 页面底色从这两侧透出来，胶囊才像"浮在页面上的一块功能条"，而不是压在顶上的
/// 一整条通栏。
const kCapsuleBarMargin = 12.0;

/// 胶囊上下各留多少空。上面那一段在状态栏之下（外面套了 SafeArea），
/// 下面那一段把胶囊和正文分开。
const kCapsuleBarGap = 8.0;
const kAppBarTitleFontSize = 18.0;

const defaultSmartLgbmInterval = 72;

/// Smart 组的延迟去抖，单位毫秒。
///
/// 两个节点延迟差不超过这个数时视为一样快，保持原顺序不换
/// （内核 `adapter/outboundgroup/smart.go:633-644`）。
///
/// **150 来自内核自带的示例配置**（`docs/config.yaml:1723` 的 `# tolerance: 150`，
/// url-test 组下，和 Smart 组是同一套比较逻辑），不是拍脑袋定的。
///
/// 为什么不能留 0：0 意味着两个节点差 1 毫秒也要换。手机网络抖动本来就大，
/// 结果是节点反复横跳，连接被反复重建。
///
/// 不会盖掉模型的判断：`smart.go:674` 那次排序排的是**送进模型之前的候选集**，
/// 模型打分在后面；tolerance 只是让延迟接近的节点保持原序、少换候选。
const defaultSmartTolerance = 150;

/// Smart 的模型文件名。内核在自己的工作目录里认死这个名字，三种尺寸的模型下下来
/// 都得叫它。
const smartModelFileName = 'Model.bin';

const maxMobileWidth = 600;
const maxLaptopWidth = 840;
const defaultTestUrl = 'https://www.gstatic.com/generate_204';
final commonFilter = ImageFilter.blur(
  sigmaX: 5,
  sigmaY: 5,
  tileMode: TileMode.clamp,
);

const listEquality = ListEquality();
const navigationItemListEquality = ListEquality<NavigationItem>();
const trackerInfoListEquality = ListEquality<TrackerInfo>();
const stringListEquality = ListEquality<String>();
const intListEquality = ListEquality<int>();
const logListEquality = ListEquality<Log>();
const groupListEquality = ListEquality<Group>();
const ruleListEquality = ListEquality<Rule>();
const scriptListEquality = ListEquality<Script>();
const externalProviderListEquality = ListEquality<ExternalProvider>();
const packageListEquality = ListEquality<Package>();
const profileListEquality = ListEquality<Profile>();
const proxyGroupsEquality = ListEquality<ProxyGroup>();
const hotKeyActionListEquality = ListEquality<HotKeyAction>();
const stringAndStringMapEquality = MapEquality<String, String>();
const stringAndStringMapEntryListEquality =
    ListEquality<MapEntry<String, String>>();
const stringAndStringMapEntryIterableEquality =
    IterableEquality<MapEntry<String, String>>();
const stringAndObjectMapEntryIterableEquality =
    IterableEquality<MapEntry<String, Object?>>();
const delayMapEquality = MapEquality<String, Map<String, int?>>();
const stringSetEquality = SetEquality<String>();
const keyboardModifierListEquality = SetEquality<KeyboardModifier>();

const viewModeColumnsMap = {
  ViewMode.mobile: [2, 1],
  ViewMode.laptop: [3, 2],
  ViewMode.desktop: [4, 3],
};

const proxiesListStoreKey = PageStorageKey<String>('proxies_list');
const toolsStoreKey = PageStorageKey<String>('tools');
const profilesStoreKey = PageStorageKey<String>('profiles');

// Clash MO 的主色（HeroUI 默认蓝）。换掉原本的淡粉，是整体观感变化最大的一处。
const defaultPrimaryColor = 0xFF006FEE;

double getWidgetHeight(num lines) {
  final space = 14.mAp;
  return max(lines * (80.ap + space) - space, 0);
}

const maxLength = 1000;

const mainIsolate = 'ClashPartyMainIsolate';

const serviceIsolate = 'ClashPartyServiceIsolate';

const scriptTemplate = '''
const main = (config) => {
  return config;
}''';

const backupDatabaseName = 'database.sqlite';
const configJsonName = 'config.json';
