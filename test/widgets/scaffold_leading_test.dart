import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/pages/home.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 手机上没有常驻导航栏，二级页面全靠 AppBar 左上角那个返回键才回得去。
/// 这组测试钉住三件事：压栈出来的页面有返回键、切页进来的页面也有、
/// 根页面（仪表盘）没有。
void main() {
  Widget buildApp({required Widget home, GlobalKey<NavigatorState>? key}) {
    return MaterialApp(
      navigatorKey: key,
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
      home: home,
    );
  }

  ProviderContainer register(ProviderContainer container) {
    addTearDown(container.dispose);
    globalState.container = container;
    return container;
  }

  /// 只放一个仪表盘和一个二级页，避免依赖真实页面的内容。
  NavigationItemsState buildItems() {
    return NavigationItemsState(
      value: [
        NavigationItem(
          keep: false,
          icon: const Icon(Icons.space_dashboard),
          label: PageLabel.dashboard,
          builder: (_) => const CommonScaffold(
            key: GlobalObjectKey(PageLabel.dashboard),
            title: 'Dashboard',
            body: SizedBox(),
          ),
        ),
        NavigationItem(
          icon: const Icon(Icons.folder),
          label: PageLabel.profiles,
          builder: (_) => const CommonScaffold(
            key: GlobalObjectKey(PageLabel.profiles),
            title: 'Profiles',
            body: SizedBox(),
          ),
        ),
      ],
    );
  }

  Future<ProviderContainer> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = register(
      ProviderContainer(
        overrides: [
          navigationItemsStateProvider.overrideWithValue(buildItems()),
        ],
      ),
    );
    container.read(viewSizeProvider.notifier).value = const Size(400, 900);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildApp(
          home: const HomePage(),
          key: globalState.navigatorKey,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return container;
  }

  testWidgets('a page opened with showExtend can be closed from its app bar', (
    tester,
  ) async {
    register(
      ProviderContainer(
        overrides: [isMobileViewProvider.overrideWithValue(true)],
      ),
    );
    late BuildContext rootContext;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: globalState.container,
        child: buildApp(
          home: Builder(
            builder: (context) {
              rootContext = context;
              return const CommonScaffold(title: 'Dashboard', body: SizedBox());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    showExtend(
      rootContext,
      builder: (_) => const CommonScaffold(title: 'Extended', body: SizedBox()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Extended'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Extended'), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('the root page has no back button', (tester) async {
    await pumpHome(tester);

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('a page switched to without a push still gets a back button', (
    tester,
  ) async {
    final container = await pumpHome(tester);

    // 导入订阅后跳到配置页走的就是这一条：换页而不是压栈，
    // 所以 AppBar 自己补不出返回键。
    container.read(currentPageLabelProvider.notifier).toProfiles();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Profiles'), findsOneWidget);
    expect(Navigator.of(globalState.navigatorKey.currentContext!).canPop(),
        isFalse);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(container.read(currentPageLabelProvider), PageLabel.dashboard);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('system back returns to the root page instead of closing', (
    tester,
  ) async {
    final container = await pumpHome(tester);

    container.read(currentPageLabelProvider.notifier).toProfiles();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(currentPageLabelProvider), PageLabel.profiles);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(container.read(currentPageLabelProvider), PageLabel.dashboard);
  });

  testWidgets('the edit layer keeps its own close icon', (tester) async {
    register(ProviderContainer());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: globalState.container,
        child: buildApp(
          home: CommonScaffoldBackActionProvider(
            backAction: () {},
            child: CommonScaffold(
              title: 'Profiles',
              editState: AppBarEditState(editCount: 1, onExit: () {}),
              body: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('the search layer keeps its own back arrow', (tester) async {
    register(ProviderContainer());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: globalState.container,
        child: buildApp(
          home: CommonScaffoldBackActionProvider(
            backAction: () {},
            child: CommonScaffold(
              title: 'Profiles',
              searchState: AppBarSearchState(onSearch: (_) {}),
              body: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    // 搜索态的左上角是「退出搜索」，不是「回上一页」。
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
