import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 首页「状态总览」那一行大字在**查不到出口 IP** 时该显示什么。
///
/// 这件事肉眼很难发现：出口正常的机器上永远走不到这条分支，而出口不通的机器上
/// 看到的是一行省略号——看起来就像「还在查」，于是没人会去报「它卡住了」。
/// 真相是查询早就结束了（provider 把 isLoading 置回 false、ipInfo 留 null），
/// 只有这块磁贴还在装作正在加载。
void main() {
  Future<AppLocalizations> pumpHero(
    WidgetTester tester, {
    required bool isStart,
    required NetworkDetectionState detection,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        networkDetectionProvider.overrideWithBuild((_, _) => detection),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(400, 900));
    container.read(profilesProvider.notifier).setAndReorder([Profile.normal()]);
    container.read(runTimeProvider.notifier).value = isStart ? 1000 : null;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: globalState.navigatorKey,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            extensions: <ThemeExtension<dynamic>>[AppStyleTokens.clashParty],
          ),
          builder: (context, inner) {
            globalState.measure = Measure.of(context, 1);
            globalState.theme = CommonTheme.of(context, 1);
            return inner!;
          },
          home: const Scaffold(body: StatusHero()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return AppLocalizations.of(tester.element(find.byType(StatusHero)));
  }

  testWidgets('检测还在跑时显示省略号', (tester) async {
    await pumpHero(
      tester,
      isStart: true,
      detection: const NetworkDetectionState(isLoading: true, ipInfo: null),
    );

    expect(find.text('···'), findsOneWidget);
  });

  testWidgets('检测结束却没拿到 IP 时显示「超时」，不再一直转', (tester) async {
    final l10n = await pumpHero(
      tester,
      isStart: true,
      detection: const NetworkDetectionState(isLoading: false, ipInfo: null),
    );

    expect(find.text(l10n.timeout), findsOneWidget);
    expect(find.text('···'), findsNothing);
  });

  testWidgets('拿到 IP 之后显示的是 IP 本身', (tester) async {
    final l10n = await pumpHero(
      tester,
      isStart: true,
      detection: const NetworkDetectionState(
        isLoading: false,
        ipInfo: IpInfo(ip: '198.51.100.7', countryCode: 'us'),
      ),
    );

    expect(find.text('198.51.100.7'), findsOneWidget);
    expect(find.text('···'), findsNothing);
    expect(find.text(l10n.timeout), findsNothing);
  });
}
