import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/core_status_button.dart';
import 'package:clash_party/widgets/hero_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'holds connecting for the minimum duration after a fast restart',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: CoreStatusButton()),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byType(HeroSpinner), findsNothing);

      container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HeroSpinner), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await tester.pump();
      expect(find.byType(HeroSpinner), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.pump(const Duration(milliseconds: 199));
      expect(find.byType(HeroSpinner), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byType(HeroSpinner), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );

  testWidgets(
    'shows disconnected immediately when restart fails during the hold',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: CoreStatusButton()),
        ),
      );
      await tester.pump();

      container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HeroSpinner), findsOneWidget);

      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      await tester.pump();
      expect(find.byIcon(Icons.restart_alt_sharp), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.restart_alt_sharp), findsOneWidget);
      expect(find.byType(HeroSpinner), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.restart_alt_sharp), findsOneWidget);
      expect(find.byType(HeroSpinner), findsNothing);
    },
  );

  testWidgets('does not clip a connecting state longer than the hold', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: CoreStatusButton()),
      ),
    );
    await tester.pump();

    container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(HeroSpinner), findsOneWidget);

    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(HeroSpinner), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('holds connecting when restarting from disconnected', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: CoreStatusButton()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.restart_alt_sharp), findsOneWidget);

    container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HeroSpinner), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt_sharp), findsNothing);

    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    await tester.pump();
    expect(find.byType(HeroSpinner), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 199));
    expect(find.byType(HeroSpinner), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(HeroSpinner), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        globalState.measure = Measure.of(context, 1);
        return child!;
      },
      home: Scaffold(body: Center(child: child)),
    );
  }
}
