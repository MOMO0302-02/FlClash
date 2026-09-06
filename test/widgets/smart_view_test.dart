import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/config/smart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smart 内核设置页。
///
/// 钉住两件平时看不出来、坏了也没人发现的事：
/// 1. 每一行的**标题和说明都真的有译文**——l10n 少补一层的话页面上会出现
///    空白行或者报错，而单测里只查 arb 是查不出"页面上到底显示了什么"的；
/// 2. 总开关关掉时下面那一组必须**整组消失**——留在那儿的话用户会去拨那些
///    其实不生效的选项。
void main() {
  Future<ProviderContainer> pumpSmartView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: SmartView()),
      ),
    );
    await tester.pump();
    return container;
  }

  /// Smart 现在默认是关的，下面那一组选项要看得见就得先把总开关拨开。
  Future<void> turnSmartOn(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(smartRouting: true));
    await tester.pumpAndSettle();
  }

  testWidgets('默认是关的，首次进来只看到总开关这一行', (tester) async {
    final container = await pumpSmartView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    // 钉住默认值本身。Smart 覆写会改写用户订阅里的代理组和规则，
    // 默认开着就是"升级即改配置"，用户一个按钮都没点过。
    expect(container.read(appSettingProvider).smartRouting, isFalse);

    expect(find.text(l10n.smartRouting), findsOneWidget);
    for (final text in [
      l10n.smartUseLightGBM,
      l10n.smartCollectData,
      l10n.smartCollectorSize,
      l10n.smartTolerance,
      l10n.smartPreferAsn,
      l10n.smartStrategy,
    ]) {
      expect(find.text(text), findsNothing, reason: '总开关关着时不该出现「$text」');
    }
    expect(tester.takeException(), null);
  });

  testWidgets('打开总开关之后，每一行的标题和说明都在页面上', (tester) async {
    final container = await pumpSmartView(tester);
    await turnSmartOn(tester, container);
    // 采样率跟着"收集数据"走，默认关着，所以这一趟看不到它——单独测。
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(smartCollectData: true));
    await tester.pump();

    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));
    for (final text in [
      // **不查 `smartRoutingDetail`**：总开关下面那行说明按用户要求删掉了
      // （原话「smart内核选项下有一行字，需要删除」）。它还留在这个名单里，
      // 是这个文件一度整片变红的原因。
      l10n.smartRouting,
      l10n.smartUseLightGBM,
      l10n.smartUseLightGBMDesc,
      l10n.smartCollectData,
      l10n.smartCollectDataDesc,
      l10n.smartSampleRate,
      l10n.smartSampleRateDesc,
      l10n.smartCollectorSize,
      l10n.smartCollectorSizeDesc,
      l10n.smartTolerance,
      l10n.smartToleranceDesc,
      l10n.smartPreferAsn,
      l10n.smartPreferAsnDesc,
      l10n.smartStrategy,
      l10n.smartStrategyDesc,
    ]) {
      expect(find.text(text), findsOneWidget, reason: '页面上找不到「$text」');
    }
    expect(tester.takeException(), null);
  });

  testWidgets('关掉总开关，下面那一组选项整组消失', (tester) async {
    final container = await pumpSmartView(tester);
    await turnSmartOn(tester, container);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));
    expect(find.text(l10n.smartUseLightGBM), findsOneWidget);

    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(smartRouting: false));
    // 收起是带动画的，得让它跑完再看。
    await tester.pumpAndSettle();

    expect(find.text(l10n.smartUseLightGBM), findsNothing);
    expect(find.text(l10n.smartStrategy), findsNothing);
    // 总开关自己要留着，否则就再也开不回来了。
    expect(find.text(l10n.smartRouting), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('拨动总开关会写回设置', (tester) async {
    final container = await pumpSmartView(tester);
    expect(container.read(appSettingProvider).smartRouting, isFalse);

    // The Switch sits behind the capsule bar overlay. Invoke onChanged directly.
    tester.widget<Switch>(find.byType(Switch).first).onChanged!(true);
    await tester.pumpAndSettle();

    expect(container.read(appSettingProvider).smartRouting, isTrue);

    tester.widget<Switch>(find.byType(Switch).first).onChanged!(false);
    await tester.pumpAndSettle();

    expect(container.read(appSettingProvider).smartRouting, isFalse);
  });

  testWidgets('策略模式显示的是译名，不是内核里的原始值', (tester) async {
    final container = await pumpSmartView(tester);
    await turnSmartOn(tester, container);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    expect(find.text(l10n.smartStrategyStickySessions), findsOneWidget);
    expect(find.text(smartStrategyStickySessions), findsNothing);

    container
        .read(appSettingProvider.notifier)
        .update(
          (state) => state.copyWith(smartStrategy: smartStrategyRoundRobin),
        );
    await tester.pump();

    expect(find.text(l10n.smartStrategyRoundRobin), findsOneWidget);
  });

  /// 模型那一组。钉住的是「别出现拨了没反应的假开关」这一类问题：模型只有开了
  /// LightGBM 才被内核读，自动更新的两个细项也只有开了自动更新才有作用对象。
  testWidgets('LightGBM 关着时，模型那一组整组不出现', (tester) async {
    final container = await pumpSmartView(tester);
    await turnSmartOn(tester, container);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    // 现在默认是**开**的（见 smart_defaults_test.dart 的依据），所以这里得
    // 显式关掉再验——这条钉的是「关着时这一组要消失」，不是默认值本身。
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(smartUseLightGBM: false));
    await tester.pumpAndSettle();

    for (final text in [
      l10n.smartModel,
      l10n.smartLgbmAutoUpdate,
      l10n.smartLgbmUrl,
    ]) {
      expect(find.text(text), findsNothing, reason: 'LightGBM 关着时不该出现「$text」');
    }
    expect(tester.takeException(), null);
  });

  testWidgets('打开 LightGBM，模型状态、自动更新、模型大小都出现', (tester) async {
    final container = await pumpSmartView(tester);
    await turnSmartOn(tester, container);
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(smartUseLightGBM: true));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));
    for (final text in [
      l10n.smartModel,
      l10n.smartLgbmAutoUpdate,
      l10n.smartLgbmAutoUpdateDesc,
      // 这一行已从「模型下载地址」改成「模型大小」（三档可选 + 自定义）。
      l10n.smartModelSize,
      l10n.smartModelSizeDesc,
    ]) {
      expect(find.text(text), findsOneWidget, reason: '页面上找不到「$text」');
    }
    expect(tester.takeException(), null);
  });

  testWidgets('自动更新关着时，仅 Wi-Fi 和更新间隔不出现；打开就出现', (tester) async {
    final container = await pumpSmartView(tester);
    await turnSmartOn(tester, container);
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(smartUseLightGBM: true));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    // 现在默认是**开**的（依据见 smart_defaults_test.dart），所以这条钉「关着
    // 时子项要消失」得先显式关掉。
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(smartLgbmAutoUpdate: false));
    await tester.pumpAndSettle();

    expect(find.text(l10n.smartLgbmWifiOnly), findsNothing);
    expect(find.text(l10n.smartLgbmUpdateInterval), findsNothing);

    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(smartLgbmAutoUpdate: true));
    await tester.pumpAndSettle();

    expect(find.text(l10n.smartLgbmWifiOnly), findsOneWidget);
    expect(find.text(l10n.smartLgbmUpdateInterval), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('模型下载地址出厂时留空＝用内核内置地址', (tester) async {
    final container = await pumpSmartView(tester);
    // 不预填一个我们自己猜的地址。
    expect(container.read(appSettingProvider).smartLgbmUrl, '');
    // 其余出厂值（自动更新、仅 Wi-Fi、间隔、去抖、采样率……）连同**为什么是
    // 这个值**一起钉在 `test/config/smart_defaults_test.dart`，不在这里重复。
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalState.navigatorKey,
      locale: const Locale('zh', 'CN'),
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
