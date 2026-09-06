import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/providers/database.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/connection/connections.dart';
import 'package:clash_party/views/connection/requests.dart';
import 'package:clash_party/views/dashboard/widgets/widgets.dart';
import 'package:clash_party/views/dashboard/widgets/intranet_ip_detail.dart';
import 'package:clash_party/views/dashboard/widgets/memory_info_detail.dart';
import 'package:clash_party/views/dashboard/widgets/network_speed_detail.dart';
import 'package:clash_party/views/dashboard/widgets/traffic_usage_detail.dart';
import 'package:clash_party/views/logs.dart';
import 'package:clash_party/views/profiles/add.dart';
import 'package:clash_party/views/profiles/profiles.dart';
import 'package:clash_party/views/proxies/proxies.dart';
import 'package:clash_party/views/resources.dart';
import 'package:clash_party/views/tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 每块磁贴点下去应该打开什么。
///
/// 这张表就是这次修改要钉住的东西：首页上「网速」「流量统计」「连接」三块磁贴
/// 曾经全都通向同一个连接列表，「内存」点了静默跑一次 GC 什么也不显示，
/// 「内网 IP」根本点不动。改完之后每块磁贴各去各的地方。
void main() {
  Future<void> pumpTile(WidgetTester tester, Widget tile) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(_TestProfiles.new)],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    // 窄屏才走「压栈打开」那条路径；宽屏是右侧抽屉，两条路都能验，
    // 但手机端才是这些磁贴的真实场景。
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(400, 900));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(child: tile),
      ),
    );
    await tester.pump();
  }

  Future<void> tapTile(WidgetTester tester, Widget tile) async {
    await tester.tap(find.byWidget(tile), warnIfMissed: false);
    // 不能用 pumpAndSettle：打开的页面里有每秒重排的采样定时器，永远settle不了。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  final tiles = <String, ({Widget tile, Type target})>{
    'proxy group tile': (tile: const ProxyGroupTile(), target: ProxiesView),
    'profile tile': (tile: const ProfileTile(), target: ProfilesView),
    'connection tile': (tile: const ConnectionTile(), target: ConnectionsView),
    'request tile': (tile: const RequestTile(), target: RequestsView),
    'log tile': (tile: const LogTile(), target: LogsView),
    'resource tile': (tile: const ResourceTile(), target: ResourcesView),
    'setting tile': (tile: const SettingTile(), target: ToolsView),
    // 流量统计现在是流量这件事的总入口：点进去是速率详情（上下行曲线、
    // 当前/平均/峰值、按速率排的连接排行）。这个入口原来挂在状态总览上。
    'traffic usage': (
      tile: const TrafficUsage(),
      target: NetworkSpeedDetailView,
    ),
    'intranet ip': (tile: const IntranetIP(), target: IntranetIpDetailView),
    'memory info': (tile: const MemoryInfo(), target: MemoryInfoDetailView),
  };

  for (final entry in tiles.entries) {
    testWidgets('${entry.key} opens ${entry.value.target}', (tester) async {
      await pumpTile(tester, entry.value.tile);
      await tapTile(tester, entry.value.tile);

      expect(find.byType(entry.value.target), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      if (entry.value.target == ConnectionsView) {
        // 连接列表会向内核发一次 IPC 请求，测试环境里没有内核，那个请求带着
        // 一个十秒的超时定时器。卸载之后把时钟拨过去，否则测试结束时会被判
        // 「还有定时器没清」——那不是磁贴跳转的问题。
        //
        // 只对这一条拨：把假时钟一次推 11 秒会顺带触发一路无关的周期回调，
        // 用不着的地方别推。
        await tester.pump(const Duration(seconds: 11));
      } else {
        await tester.pump();
      }
    });
  }

  testWidgets('the stream tiles no longer share one destination', (
    tester,
  ) async {
    // 原来这里还有一块独立的「网速」磁贴，已经并进状态总览（见下一条）。
    for (final tile in <Widget>[const TrafficUsage()]) {
      await pumpTile(tester, tile);
      await tapTile(tester, tile);

      // 这才是当初要修的 bug：这些磁贴以前和「连接」磁贴一样打开连接列表。
      expect(find.byType(ConnectionsView), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  // 状态总览原来有个隐藏入口：点右下角那两行速率数字才能进速率详情。用户反馈
  // 「只有点数字才能进二级菜单，没用过的根本找不到」，整个删掉了，速率详情改由
  // 流量统计磁贴承载（见上面的 tiles 表）。
  //
  // 这一条钉住删除的目的：**这块卡片只做启停，不再跳转任何详情页**。不钉的话，
  // 以后很容易有人顺手把入口加回来，又变成一块卡片两种点击含义。
  testWidgets('status hero does not open any detail page', (tester) async {
    await pumpTile(tester, const StatusHero());

    // 点卡片正中间——如果还藏着内层入口，这一下多半会命中它。
    await tester.tap(find.byType(StatusHero), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NetworkSpeedDetailView), findsNothing);
    expect(find.byType(TrafficUsageDetailView), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('status hero opens the add-profile panel when there is none', (
    tester,
  ) async {
    const tile = StatusHero();
    await pumpTile(tester, tile);
    await tapTile(tester, tile);

    expect(find.byType(AddProfileView), findsOneWidget);
    // 原来打开的是订阅列表页，而列表此刻必然是空的。
    expect(find.byType(ProfilesView), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('memory details releases memory only when asked', (tester) async {
    var released = 0;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: MemoryInfoDetailView(
            usageReader: () async => const MemoryUsage(app: 2048, core: 1024),
            gcRequester: () async {
              released++;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(released, 0);
    // 应用 2KB + 内核 1KB，合计必须是 3KB —— 合计行是这一页存在的理由之一。
    expect(find.text('3.00 KB'), findsOneWidget);

    await tester.tap(find.text('Release memory'));
    await tester.pump();
    await tester.pump();

    expect(released, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('traffic details rank by bytes, biggest first', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;

    TrackerInfo connection(String host, String chain, int bytes) {
      return TrackerInfo(
        id: '$host-$chain',
        upload: bytes,
        download: 0,
        start: DateTime(2026),
        metadata: Metadata(host: host),
        chains: [chain],
        rule: 'Match',
        rulePayload: '',
      );
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: TrafficUsageDetailView(
            connectionsReader: () async => [
              connection('small.example', 'A', 1),
              connection('big.example', 'B', 4096),
              connection('medium.example', 'A', 2048),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final connections = [
      connection('small.example', 'A', 1),
      connection('big.example', 'B', 4096),
      connection('medium.example', 'A', 2048),
    ];
    final ranked = rankConnections(connections, (item) => item.metadata.host);
    expect(ranked.map((entry) => entry.key).toList(), [
      'big.example',
      'medium.example',
      'small.example',
    ]);

    // 同一条代理链上的两条连接要合并，不能各占一行。
    final byChain = rankConnections(connections, (item) => item.chains.first);
    expect(byChain.length, 2);
    expect(byChain.first.key, 'B');
    expect(byChain.last.value, 2049);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _TestProfiles extends Profiles {
  @override
  List<Profile> build() => const [];
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalState.navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        globalState.measure = Measure.of(context, 1);
        globalState.theme = CommonTheme.of(context, 1);
        return child!;
      },
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, child: child)),
      ),
    );
  }
}
