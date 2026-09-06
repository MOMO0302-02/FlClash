import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/providers/database.dart';
import 'package:clash_party/providers/state.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/config/advanced.dart';
import 'package:clash_party/views/config/dns.dart';
import 'package:clash_party/views/config/general.dart';
import 'package:clash_party/views/config/network.dart';
import 'package:clash_party/views/config/on_demand.dart';
import 'package:clash_party/views/hotkey.dart';
import 'package:clash_party/views/profiles/overwrite/custom/groups.dart';
import 'package:clash_party/views/profiles/overwrite/custom/proxies.dart';
import 'package:clash_party/views/profiles/overwrite/custom/proxy_providers.dart';
import 'package:clash_party/views/profiles/overwrite/custom/rules.dart';
import 'package:clash_party/views/proxies/list.dart';
import 'package:clash_party/views/theme.dart';
import 'package:clash_party/views/views.dart';
import 'package:clash_party/widgets/inherited.dart';
import 'package:clash_party/widgets/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

void main() {
  final cases = <String, Widget>{
    'dashboard': const DashboardView(),
    'proxies': const ProxiesView(),
    'profiles': const ProfilesView(),
    'requests': const RequestsView(),
    'resources': const ResourcesView(),
    'logs': const LogsView(),
    'tools': const ToolsView(),
    'basic config': const ConfigView(),
    'dns config': const Scaffold(body: DnsListView()),
    'network config': const Scaffold(body: NetworkListView()),
    'advanced config': const AdvancedConfigView(),
    'on demand config': const OnDemandView(),
    'theme': const ThemeView(),
    'application settings': const ApplicationSettingView(),
    'backup and restore': const BackupAndRestore(),
    'hotkeys': const HotKeyView(),
    'access control': const AccessView(),
    // 默认没配后端地址，所以这一趟只会走到「未设置」空状态，一个请求都不发。
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key} renders its default state', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [profilesProvider.overrideWith(_TestProfiles.new)],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _TestApp(child: entry.value),
        ),
      );
      await tester.pump();
      if (entry.key == 'access control') {
        await tester.pump(const Duration(milliseconds: 301));
      }
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        for (var index = 0; index < 8; index++) {
          // 胶囊顶栏浮在正文之上，滚动区域的中心点有可能正落在它底下。
          // `warnIfMissed: false` 让拖不中时安静跳过——这一组是冒烟测试，
          // 要钉的是"页面能渲染出来、不抛异常"，不是"一定滚得动"。
          await tester.drag(
            scrollables.first,
            const Offset(0, -700),
            warnIfMissed: false,
          );
          await tester.pump();
        }
      }

      expect(find.byWidget(entry.value), findsOneWidget);
      expect(tester.takeException(), null);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  final toolDestinations = <String, Type>{
    'Theme': ThemeView,
    'Backup and Restore': BackupAndRestore,
    'Basic configuration': ConfigView,
    'Advanced configuration': AdvancedConfigView,
    'Application': ApplicationSettingView,
  };

  for (final entry in toolDestinations.entries) {
    testWidgets('tools opens ${entry.key}', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [profilesProvider.overrideWith(_TestProfiles.new)],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(1400, 1000));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ToolsView()),
        ),
      );
      await tester.pump();

      // 设置页现在按「网络 / 主题 / 应用程序」分组，分组标题和某些行同名
      // （比如「主题」既是标题也是一行），只按文字找会命中两个。
      // 限定在 ListTile 里找，标题不是 ListTile。
      final target = find.widgetWithText(ListTile, entry.key);
      await tester.scrollUntilVisible(
        target,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(find.byType(entry.value), findsOneWidget);
      expect(tester.takeException(), null);
    });
  }

  testWidgets('user agent dialog applies a preset', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(_TestProfiles.new)],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1000, 800));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: Scaffold(body: ListView(children: const [UaItem()])),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('User-Agent'));
    await tester.pumpAndSettle();
    expect(find.text('clash-verge/v2.4.2'), findsOneWidget);

    await tester.tap(find.text('clash-verge/v2.4.2'));
    await tester.pumpAndSettle();

    expect(
      container.read(patchClashConfigProvider).globalUa,
      'clash-verge/v2.4.2',
    );
    expect(tester.takeException(), null);
  });

  testWidgets('DNS mode options update the patch configuration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(_TestProfiles.new)],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1000, 800));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: Scaffold(body: DnsModeItem())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('DNS mode'));
    await tester.pumpAndSettle();
    expect(find.text('fakeIp'), findsWidgets);

    await tester.tap(find.text('fakeIp').last);
    await tester.pumpAndSettle();

    expect(
      container.read(patchClashConfigProvider).dns.enhancedMode,
      DnsMode.fakeIp,
    );

    final previousOverride = container.read(overrideDnsProvider);
    final previousDns = container.read(patchClashConfigProvider).dns;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(
          child: Scaffold(
            body: Column(
              children: [
                OverrideItem(),
                StatusItem(),
                PreferH3Item(),
                IPv6Item(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Override Dns'));
    await tester.pump();
    await tester.tap(find.text('Status'));
    await tester.pump();
    await tester.tap(find.text('PreferH3'));
    await tester.pump();
    await tester.tap(find.text('IPv6'));
    await tester.pump();

    expect(container.read(overrideDnsProvider), !previousOverride);
    expect(
      container.read(patchClashConfigProvider).dns.enable,
      !previousDns.enable,
    );
    expect(
      container.read(patchClashConfigProvider).dns.preferH3,
      !previousDns.preferH3,
    );
    expect(
      container.read(patchClashConfigProvider).dns.ipv6,
      !previousDns.ipv6,
    );
    expect(tester.takeException(), null);
  });

  testWidgets('proxies renders populated tab and list layouts', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = Profile.normal().copyWith(
      currentGroupName: 'Selector',
      selectedMap: {'Selector': 'Proxy 1'},
      unfoldSet: {'Selector'},
    );
    final proxies = List.generate(
      24,
      (index) => Proxy(name: 'Proxy $index', type: 'Direct'),
    );
    final group = Group(
      name: 'Selector',
      type: GroupType.Selector,
      hidden: false,
      now: 'Proxy 1',
      all: proxies,
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => _TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        currentGroupsStateProvider.overrideWithValue(
          GroupsState(value: [group]),
        ),
        groupsProvider.overrideWithValue([group]),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1400, 1000));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: ProxiesView()),
      ),
    );
    await tester.pump();

    expect(container.read(proxiesTabStateProvider).groups, [group]);
    // 标签页排版按用户要求去掉了，只剩列表这一种。
    expect(find.byType(ProxiesListView), findsOneWidget);

    final scrollables = find.byType(Scrollable);
    for (var index = 0; index < 8; index++) {
      await tester.drag(
        scrollables.last,
        const Offset(0, -700),
        warnIfMissed: false,
      );
      await tester.pump();
    }
    expect(tester.takeException(), null);
  });

  testWidgets('custom overwrite editors render populated data', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = Profile.normal().copyWith(
      overwriteType: OverwriteType.custom,
    );
    final proxyGroups = List.generate(
      8,
      (index) => ProxyGroup(
        id: 100 + index,
        profileId: profile.id,
        name: 'Group $index',
        type: GroupType.Selector,
        proxies: const ['DIRECT'],
      ),
    );
    final rules = List.generate(
      12,
      (index) => Rule(
        id: 200 + index,
        content: 'example$index.com',
        ruleTarget: 'DIRECT',
        order: index.toString(),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => _TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        profileCustomRulesProvider.overrideWith2(
          (_) => _TestProfileCustomRules(rules),
        ),
        proxyGroupsProvider.overrideWith2((_) => _TestProxyGroups(proxyGroups)),
        proxyGroupProvider.overrideWithBuild((_, _) => proxyGroups.first),
        clashConfigProvider(profile.id).overrideWithValue(
          const AsyncData(
            ClashConfig(
              proxies: [Proxy(name: 'DIRECT', type: 'Direct')],
              proxyProviders: ['provider'],
            ),
          ),
        ),
        customOverwriteDateProvider(profile.id).overrideWithValue(
          CustomOverwriteDate(
            proxies: const [Proxy(name: 'DIRECT', type: 'Direct')],
            proxyGroups: proxyGroups,
            proxyProviders: const {'provider'},
            ruleTargets: {
              ...RuleTarget.baseTargets,
              ...proxyGroups.map((group) => group.name),
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1400, 1000));

    final views = <Widget>[
      CustomRulesView(profile.id),
      CustomProxyGroupsView(profile.id),
      SheetProvider(
        type: SheetType.page,
        child: ProfileIdProvider(
          profileId: profile.id,
          child: const EditProxiesView(),
        ),
      ),
      SheetProvider(
        type: SheetType.page,
        child: ProfileIdProvider(
          profileId: profile.id,
          child: const EditProxyProvidersView(),
        ),
      ),
    ];

    for (final view in views) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _TestApp(child: view),
        ),
      );
      await tester.pump();
      expect(find.byWidget(view), findsOneWidget);
      expect(tester.takeException(), null);

      if (view is CustomRulesView) {
        final list = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView),
        );
        list.onReorderItem!(0, 1);
        await tester.pump();

        // **先滚回顶部再点。** 悬浮胶囊浮在内容之上，内容可以滚到它底下——
        // 那块区域的点击会落在胶囊上，点不到下面的东西。上面那段通用流程把每个
        // 页面都拖了 8 次，不滚回来的话第一个复选框正好在胶囊底下。
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();
        expect(find.text('Select all'), findsOneWidget);
        await tester.tap(find.text('Select all'));
        await tester.pump();
        await tester.tap(find.text('Select all'));
        await tester.pump();
        expect(find.text('Add'), findsOneWidget);

        container
            .read(viewSizeProvider.notifier)
            .update((_) => const Size(500, 1000));
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(find.byType(SheetViewport), findsOneWidget);
        globalState.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        container
            .read(viewSizeProvider.notifier)
            .update((_) => const Size(1400, 1000));
      }

      if (view is CustomProxyGroupsView) {
        final list = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView),
        );
        list.onReorderItem!(0, 1);
        await tester.pump();

        container
            .read(viewSizeProvider.notifier)
            .update((_) => const Size(500, 1000));
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(find.byType(SheetViewport), findsOneWidget);
        globalState.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        container
            .read(viewSizeProvider.notifier)
            .update((_) => const Size(1400, 1000));
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TestProfiles extends Profiles {
  final List<Profile> initial;

  _TestProfiles([this.initial = const []]);

  @override
  List<Profile> build() => initial;
}

class _TestProfileCustomRules extends ProfileCustomRules {
  final List<Rule> initial;

  _TestProfileCustomRules(this.initial);

  @override
  Stream<List<Rule>> build(int profileId) => Stream.value(initial);

  @override
  void order(int oldIndex, int newIndex) {}
}

class _TestProxyGroups extends ProxyGroups {
  final List<ProxyGroup> initial;

  _TestProxyGroups(this.initial);

  @override
  Stream<List<ProxyGroup>> build(int profileId) => Stream.value(initial);

  @override
  void order(int oldIndex, int newIndex) {}
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
      home: child,
    );
  }
}
