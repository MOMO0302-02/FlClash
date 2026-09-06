import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/connection/item.dart';
import 'package:clash_party/views/dashboard/widgets/widgets.dart';
import 'package:clash_party/views/logs.dart';
import 'package:clash_party/views/profiles/profiles.dart';
import 'package:clash_party/views/proxies/card.dart' as proxies_card;
import 'package:clash_party/views/proxies/common.dart';
import 'package:clash_party/views/proxies/list.dart' as proxies_list;
import 'package:clash_party/views/proxies/setting.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 跨「屏幕尺寸 × 字号缩放 × 语言 × 极端数据」的排版溢出测试。
///
/// 为什么要有这一组：这个项目已经因为溢出被打脸过四次（卡片 18px / 10px / 42px、
/// 日志条目窄屏 7.2px），每一次都是**只在某一种组合下**才出现的——在自己那台手机、
/// 中文、默认字号下看一眼，什么都发现不了。肉眼永远只能覆盖矩阵里的一个点。
///
/// 四个维度分别对应四类真实翻车方式：
/// * 屏幕：小屏挤爆、横屏高度不够；
/// * 字号：应用内可放大到 1.4 倍（`maxTextScale`），行高跟着长，固定高度的容器会爆；
/// * 语言：俄语 / 日语的文案普遍比中文长很多，撑破的是宽度；
/// * 数据：超长节点名、TB 级流量、四位数延迟——用户的真实订阅里全都有。
///
/// 判定方式沿用 `card_layout_test.dart`：Flutter 溢出时往 `FlutterError.onError`
/// 抛异常，这里接住并筛 `overflowed`。

// ---------------------------------------------------------------------------
// 矩阵维度
// ---------------------------------------------------------------------------

/// 应用内「字号缩放」的上下限见 `constant.dart` 的 `maxTextScale` / `minTextScale`，
/// 系统级放大也会被 `theme_manager.dart` 钳进这个区间，所以 1.4 就是真实上界。
const _minScale = 1.0;
const _maxScale = maxTextScale;

const _small = Size(320, 568);
const _landscape = Size(844, 390);
const _tablet = Size(768, 1024);

/// 每个组件跑这六种组合。
///
/// **不做「五种屏幕 × 四种语言」的全排列**：那是 20 倍的用例数，而它们并不互相
/// 独立——宽度上的溢出只要在最窄的 320 上暴露了，390 / 430 上必然是同一处，测了
/// 只是把同一个 bug 报四遍。实际删减前跑过全排列（224 个用例），本轮抓到的四处
/// 溢出**全部**能被下面这六种命中，没有一处是只在被删掉的组合里出现的。
///
/// 保留的每一条都各自负责一个独立的翻车面：
/// * 三条 320 宽的不同语言——宽度是最主要的溢出维度，而哪种语言最长要看具体文案
///   （`infiniteTime` 是俄语最长，别的键可能是英语最长），所以三种都留；
/// * 横屏——高度只剩 390，按「竖屏至少有 600 高」写的排版在这里露馅；
/// * 平板——宽屏下列数、图标尺寸会走另一条分支；
/// * 1.0 倍中文基准——用来区分「本来就坏」和「放大字号才坏」，也防止修 A 坏 B。
const _cases = <(String, Size, Locale, double)>[
  ('小屏·ru·1.4x', _small, Locale('ru'), _maxScale),
  ('小屏·en·1.4x', _small, Locale('en'), _maxScale),
  ('小屏·ja·1.4x', _small, Locale('ja'), _maxScale),
  ('横屏·ru·1.4x', _landscape, Locale('ru'), _maxScale),
  ('平板·ru·1.4x', _tablet, Locale('ru'), _maxScale),
  ('小屏·zh·1.0x', _small, Locale('zh', 'CN'), _minScale),
];

// ---------------------------------------------------------------------------
// 极端数据
// ---------------------------------------------------------------------------

/// 真实订阅里常见的那种长名字：机场前缀 + 地区 + 倍率 + 备注，还带 emoji。
const _longNodeName =
    '🇭🇰 香港 IEPL 专线 中继 01 | 倍率 0.2x | 剩余流量充足 | BGP 优化线路';

const _longGroupName = '🇺🇸 美国节点自动选择（延迟优先 · 故障转移 · 负载均衡）';

/// 安卓上的进程名就是完整包名，长得离谱。
const _longProcess = 'com.example.some.very.long.android.package.name.service';

const _longHost = 'very-long-subdomain-for-testing.example-cdn-provider.com';

/// `traffic.show` 能产出的最长字符串：`1000.0 YB`。
///
/// 两处都不是随手填的：
/// * **数值最长 6 个字符**，且只有一个来源——`999.99` 走「长度 6 → 改一位小数」
///   那条分支变成 `1000.0`（见 `traffic_format_parity_test.dart` 里的穷举）。
/// * **单位最长的一档是 YB**，桌面端 `calcTraffic` 到此为止，不再进位。
///
/// 上下行都给满，速率那两行就是 `1000.0 YB/s ↑` / `1000.0 YB/s ↓`。
/// 乘的是 1024 的 8 次方（YB 那一档），二进制下除 1024 是精确运算，不会有误差。
const _extremeTraffic = Traffic(
  up: 999.99 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024,
  down: 999.99 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024,
);

Group _extremeGroup({int proxyCount = 300}) => Group(
  type: GroupType.Selector,
  name: _longGroupName,
  testUrl: 'http://www.gstatic.com/generate_204',
  all: [
    for (var i = 0; i < proxyCount; i++)
      Proxy(name: '$_longNodeName #$i', type: 'ShadowsocksR'),
  ],
);

TrackerInfo _extremeTracker() => TrackerInfo(
  id: 'id',
  // TB 级流量：`traffic.show` 会给出 4 位数字 + 单位。
  upload: 1234 * 1024 * 1024 * 1024,
  download: 4321 * 1024 * 1024 * 1024,
  uploadSpeed: 987 * 1024 * 1024,
  downloadSpeed: 654 * 1024 * 1024,
  start: DateTime(2026, 1, 1),
  metadata: const Metadata(
    network: 'tcp',
    process: _longProcess,
    sourceIP: '192.168.31.181',
    sourcePort: '54321',
    destinationIP: '2404:6800:4004:80a::200e',
    destinationPort: '443',
    host: _longHost,
    uid: 10234,
  ),
  chains: const [_longGroupName, _longNodeName, 'GLOBAL'],
  rule: 'RuleSet',
  rulePayload: 'geosite:category-ads-all',
);

// ---------------------------------------------------------------------------
// 探针
// ---------------------------------------------------------------------------

/// 渲染 [child]，收集这一帧里所有布局溢出的报错。
///
/// [textScale] 必须同时喂给 `MediaQuery.textScaler` 和 `globalState.measure` /
/// `globalState.theme`——后两个是运行期全局量，`getWidgetHeight` / `getItemHeight`
/// / `listHeaderHeight` 全靠它们算固定高度。只改 MediaQuery 的话，文字变大了而
/// 容器高度没跟着变，测出来的是一个现实中不存在的场景。
/// 排查时把 `OVERFLOW_VERBOSE=1` 传进来，报错里会带上完整的 RenderFlex 诊断
/// （是哪一个 Row/Column、父链是什么）。平时只留第一行，免得失败信息糊满屏幕。
const _verbose = bool.fromEnvironment('OVERFLOW_VERBOSE');

Future<List<String>> _probe(
  WidgetTester tester, {
  required Widget Function() build,
  required Size size,
  double textScale = _minScale,
  Locale locale = const Locale('en'),
  ProviderContainer Function() containerBuilder = ProviderContainer.new,
}) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      errors.add(
        _verbose
            ? '$text\n${details.toString()}'
            : text.split('\n').first.trim(),
      );
    } else {
      previous?.call(details);
    }
  };

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = containerBuilder();
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).update((_) => size);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: globalState.navigatorKey,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          extensions: <ThemeExtension<dynamic>>[AppStyleTokens.clashParty],
        ),
        builder: (context, inner) {
          // 必须在子树构建之前赋好：`getWidgetHeight` 这类函数在 build 期间就会
          // 被调用，晚一步拿到的是上一次的缩放值。
          globalState.measure = Measure.of(context, textScale);
          globalState.theme = CommonTheme.of(context, textScale);
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: inner!,
          );
        },
        // 必须用 Builder 把被测组件的构造推迟到这里：`getItemHeight` /
        // `listHeaderHeight` 这类固定高度是在**构造 widget 时**就算出来的，
        // 提前构造会拿到上一个用例遗留的 `globalState.measure`——单跑时直接
        // 报未初始化，连着跑时更坏：不报错，但用的是别的字号算出来的高度。
        home: Scaffold(body: Builder(builder: (_) => build())),
      ),
    ),
  );
  // 溢出可能只在动画中途出现（比如卡片选中过渡里字色/字号变化的那几帧），
  // 所以除了首帧还要往前推几帧。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 400));

  // 必须在 expect 之前**同步**还原，不能放进 addTearDown：测试体一结束
  // binding 就会检查 `FlutterError.onError` 是不是原样，晚一步会得到一条
  // 「A test overrode FlutterError.onError」的断言失败，把真正的溢出信息盖掉。
  FlutterError.onError = previous;
  // 把树拆掉再退出：留着的话下一个用例的 pumpWidget 会先跑一遍旧树的
  // 销毁逻辑，而那时全局的 measure / container 已经指向新的值了。
  await tester.pumpWidget(const SizedBox.shrink());
  return errors;
}

/// 把一个组件按 [_cases] 里的六种组合各渲染一遍，任何一次溢出都算失败。
///
/// [width] 是给「本来就不占整行」的组件用的（半宽磁贴、网格里的一格）：不限死的话
/// 它会被拉到整屏宽，测出来的是一个界面上不存在的形态。
void _matrix(
  String name,
  Widget Function() build, {
  double width = double.infinity,
  ProviderContainer Function() containerBuilder = ProviderContainer.new,
}) {
  for (final (label, size, locale, scale) in _cases) {
    testWidgets('$name · $label', (tester) async {
      final errors = await _probe(
        tester,
        build: () => width.isFinite
            ? Center(child: SizedBox(width: width, child: build()))
            : build(),
        size: size,
        textScale: scale,
        locale: locale,
        containerBuilder: containerBuilder,
      );
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  }
}

// ---------------------------------------------------------------------------
// 用例
// ---------------------------------------------------------------------------

void main() {
  // 状态总览是首屏面积最大的一块，且高度写死为 getWidgetHeight(2)。
  // 里面有 44 像素的圆按钮 + headlineSmall 大字 + 两行小字，字号一放大最先爆的就是它。
  group('状态总览', () {
    _matrix('状态总览', () => const StatusHero(), width: 320);

    // 「网络速度」并进来之后，那行大字旁边多了两行实时速率。默认容器里流量是
    // 空的（只会显示 `0.00 B/s`），量不到真实宽度——必须灌进最长的那种：
    // `1000.0 YB/s` 是 `traffic.show` 能产出的最长字符串，再配上箭头图标。
    _matrix(
      '状态总览(极端速率)',
      () => const StatusHero(),
      width: 320,
      containerBuilder: () => ProviderContainer(
        overrides: [
          trafficsProvider.overrideWithBuild(
            (_, _) => FixedList(
              30,
              list: [
                for (var i = 0; i < 10; i++) _extremeTraffic,
              ],
            ),
          ),
          totalTrafficProvider.overrideWithBuild((_, _) => _extremeTraffic),
        ],
      ),
    );
  });

  // 入口磁贴高度写死 getWidgetHeight(1)，只有一行高，余量最小。
  // 角标给到四位数（几百个组的订阅真的存在）。
  group('入口磁贴', () {
    _matrix('代理组磁贴', () => const ProxyGroupTile(), width: 160);
    _matrix('设置磁贴', () => const SettingTile(), width: 140);
  });

  // 代理组卡片：固定 listHeaderHeight + 图标 + 两行文字 + 角标 + 三个图标按钮。
  // 这一块的高度预算是靠 titleMedium/bodyMedium 的行高差凑出来的，最脆。
  group('代理组卡片', () {
    for (final expand in [true, false]) {
      _matrix(
        expand ? '代理组卡片(展开)' : '代理组卡片(收起)',
        () => SizedBox(
          height: listHeaderHeight,
          child: proxies_list.ListHeader(
            enterAnimated: false,
            group: _extremeGroup(),
            isExpand: expand,
            onChange: (_) {},
            onScrollToSelected: (_) {},
          ),
        ),
      );
    }
  });

  // 节点卡片：高度由 getItemHeight 写死，三种信息密度各自算一套。
  group('节点卡片', () {
    for (final type in ProxyCardType.values) {
      _matrix(
        '节点卡片 ${type.name}',
        () => SizedBox(
          height: getItemHeight(type),
          child: proxies_card.ProxyCard(
            groupName: _longGroupName,
            testUrl: null,
            proxy: const Proxy(name: _longNodeName, type: 'ShadowsocksR'),
            groupType: GroupType.Selector,
            type: type,
          ),
        ),
        width: 150,
      );
    }
  });

  // 连接条目：标题行是「进程 → 目标 + 时间」，下面一排横滑胶囊。
  group('连接条目', () {
    _matrix(
      '连接条目',
      () => TrackerInfoItem(
        trackerInfo: _extremeTracker(),
        detailTitle: 'detail',
      ),
    );
  });

  // 日志条目：曾经在窄屏溢出 7.2 像素，是本项目有记录的真实翻车点。
  group('日志条目', () {
    _matrix(
      '日志条目',
      () => LogItem(
        log: Log(
          logLevel: LogLevel.warning,
          payload: '$_longHost $_longProcess connection refused',
          dateTime: DateTime(2026, 9, 3, 23, 59, 59).showFull,
        ),
      ),
    );
  });

  // 订阅卡片：流量条 + 「已用/总量 · 百分比」+ 到期日期，右边那个日期没有 Flexible。
  group('订阅卡片', () {
    _matrix(
      '订阅卡片(超额)',
      () => ProfileItem(
        profile: const Profile(
          id: 1,
          label: _longGroupName,
          url: 'https://example.com/sub',
          autoUpdateDuration: defaultUpdateDuration,
          subscriptionInfo: SubscriptionInfo(
            upload: 1200 * 1024 * 1024 * 1024,
            download: 1500 * 1024 * 1024 * 1024,
            total: 2000 * 1024 * 1024 * 1024,
            expire: 1798761600,
          ),
        ),
        groupValue: 1,
        onChanged: (_) {},
      ),
      width: 300,
    );

    _matrix(
      '订阅卡片(无限期)',
      () => ProfileItem(
        profile: const Profile(
          id: 2,
          label: _longGroupName,
          url: 'https://example.com/sub',
          autoUpdateDuration: defaultUpdateDuration,
          subscriptionInfo: SubscriptionInfo(
            upload: 0,
            download: 0,
            total: 1024 * 1024 * 1024 * 1024,
          ),
        ),
        groupValue: null,
        onChanged: (_) {},
      ),
      width: 300,
    );
  });

  // 设置分组卡片：一行「左图标 / 中标题 + 副标题 / 右当前值」，俄语最容易挤。
  group('设置分组卡片', () {
    _matrix(
      '设置分组卡片',
      () => Builder(
        builder: (context) => ListView(
          children: generateSection(
            title: context.appLocalizations.settings,
            isFirst: true,
            items: [
              ListItem(
                leading: const Icon(Icons.language),
                title: Text(context.appLocalizations.language),
                subtitle: Text(context.appLocalizations.allowBypassDesc),
                trailing: Text(context.appLocalizations.defaultText),
                onTap: () {},
              ),

              ListItem.toggle(
                leading: const Icon(Icons.vpn_lock),
                title: Text(context.appLocalizations.allowBypass),
                subtitle: Text(context.appLocalizations.allowBypassDesc),
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
  });

  // 代理页设置面板：三组单选，每行「图标 + 名称 + 对勾」。
  group('代理页设置面板', () {
    _matrix('代理页设置面板', () => const ProxiesSetting());
  });
}
