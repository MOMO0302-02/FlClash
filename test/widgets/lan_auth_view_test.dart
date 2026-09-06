import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/config/lan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 局域网访问密码。
///
/// 钉住四件事，每一件坏了都不会有人发现：
/// 1. 开了局域网又没设密码时**必须报警**——这是一个开放代理端口，用户在咖啡馆
///    连着公共 Wi-Fi 的时候完全看不出来；
/// 2. 局域网没开时**不报警**——见谁都喊狼来了，用户就会开始无视警告；
/// 3. 密码在列表里**不显示明文**；
/// 4. 用户名里带冒号要被拦下来——内核 `parseAuthentication` 按第一个冒号切，
///    带冒号的用户名会被悄悄截断，用户会对着"密码明明是对的"发愁。
void main() {
  Future<ProviderContainer> pumpLanAuthView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    // CommonDialog 拿 viewSizeProvider 算最大高度（`widgets/dialog.dart:56`
    // 的 `size.height - 40`）。测试容器里它默认是 Size.zero，不填就会算出
    // 负的约束，弹窗一开就炸。
    container.read(viewSizeProvider.notifier).value = const Size(1400, 2400);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: LanAuthView()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  void allowLan(ProviderContainer container, bool value) {
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(allowLan: value));
  }

  void setAuth(ProviderContainer container, List<String> entries) {
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(authentication: entries));
  }

  testWidgets('开了局域网又没设密码时报警', (tester) async {
    final container = await pumpLanAuthView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    expect(find.text(l10n.lanAuthWarning), findsNothing);

    allowLan(container, true);
    await tester.pumpAndSettle();

    expect(find.text(l10n.lanAuthWarning), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('局域网没开时不报警——只有门开着才叫危险', (tester) async {
    final container = await pumpLanAuthView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    expect(container.read(patchClashConfigProvider).allowLan, isFalse);
    expect(container.read(patchClashConfigProvider).authentication, isEmpty);
    expect(find.text(l10n.lanAuthWarning), findsNothing);
  });

  testWidgets('设了密码之后警告消失', (tester) async {
    final container = await pumpLanAuthView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    allowLan(container, true);
    await tester.pumpAndSettle();
    expect(find.text(l10n.lanAuthWarning), findsOneWidget);

    setAuth(container, ['alice:hunter2']);
    await tester.pumpAndSettle();

    expect(find.text(l10n.lanAuthWarning), findsNothing);
  });

  testWidgets('列表里只显示用户名，密码是圆点', (tester) async {
    final container = await pumpLanAuthView(tester);
    setAuth(container, ['alice:hunter2']);
    await tester.pumpAndSettle();

    expect(find.text('alice'), findsOneWidget);
    // 密码本身绝不能出现在屏幕上。
    expect(find.text('hunter2'), findsNothing);
    expect(find.text('•' * 'hunter2'.length), findsOneWidget);
  });

  testWidgets('密码里带冒号也能正常拆开——内核按第一个冒号切', (tester) async {
    final container = await pumpLanAuthView(tester);
    setAuth(container, ['alice:a:b:c']);
    await tester.pumpAndSettle();

    expect(find.text('alice'), findsOneWidget);
    // 密码是 "a:b:c" 五个字符，不是 "a"。切错的话圆点数量就不对。
    expect(find.text('•' * 5), findsOneWidget);
  });

  testWidgets('添加账号时用户名带冒号会被拦下来', (tester) async {
    final container = await pumpLanAuthView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    // The add button sits behind the capsule bar overlay. Invoke its onPressed
    // callback directly to open the dialog.
    final addButton = tester.widget<IconButton>(find.ancestor(
      of: find.byIcon(Icons.add),
      matching: find.byType(IconButton),
    ).first);
    addButton.onPressed!();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'a:b');
    await tester.pumpAndSettle();
    expect(find.text(l10n.lanAuthUserNameTip), findsOneWidget);

    await tester.tap(find.text(l10n.confirm));
    await tester.pumpAndSettle();

    // 拦下来 = 什么都没写进去。
    expect(container.read(patchClashConfigProvider).authentication, isEmpty);
  });

  testWidgets('正常填写会写进配置，密码框默认遮字符', (tester) async {
    final container = await pumpLanAuthView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    final addButton = tester.widget<IconButton>(find.ancestor(
      of: find.byIcon(Icons.add),
      matching: find.byType(IconButton),
    ).first);
    addButton.onPressed!();
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'alice');
    await tester.enterText(fields.at(1), 'hunter2');
    await tester.pumpAndSettle();

    // 密码框必须是遮住的。这是本页存在的理由之一，不能悄悄退化成明文。
    final password = tester.widget<EditableText>(
      find.descendant(of: fields.at(1), matching: find.byType(EditableText)),
    );
    expect(password.obscureText, isTrue);

    await tester.tap(find.text(l10n.confirm));
    await tester.pumpAndSettle();

    expect(container.read(patchClashConfigProvider).authentication, [
      'alice:hunter2',
    ]);
  });

  // 「基本配置」里那一行入口自己也会变成警告。变异测试抓到过：把入口那一行的
  // 判断改坏，上面所有页面测试依然全绿——两处各写一遍同样的条件，改了一边忘了
  // 另一边不会有任何征兆。现在两处共用 lanAtRisk，这一组盯住入口那一行。
  Future<ProviderContainer> pumpLanAuthItem(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1400, 2400);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: Scaffold(body: ListView(children: const [LanAuthItem()])),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('入口那一行：门开着没锁时变成警告', (tester) async {
    final container = await pumpLanAuthItem(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    expect(find.text(l10n.lanAuthDesc), findsOneWidget);
    expect(find.text(l10n.lanAuthWarning), findsNothing);

    allowLan(container, true);
    await tester.pumpAndSettle();

    expect(find.text(l10n.lanAuthWarning), findsOneWidget);
    expect(find.text(l10n.lanAuthDesc), findsNothing);
  });

  testWidgets('入口那一行：局域网没开就不报警', (tester) async {
    final container = await pumpLanAuthItem(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    setAuth(container, const []);
    await tester.pumpAndSettle();

    expect(find.text(l10n.lanAuthWarning), findsNothing);
  });

  testWidgets('入口那一行：设了密码就不报警', (tester) async {
    final container = await pumpLanAuthItem(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    allowLan(container, true);
    setAuth(container, ['alice:hunter2']);
    await tester.pumpAndSettle();

    expect(find.text(l10n.lanAuthWarning), findsNothing);
    expect(find.text(l10n.lanAuthDesc), findsOneWidget);
  });

  testWidgets('免验证网段默认含本机，界面上找得到', (tester) async {
    final container = await pumpLanAuthView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    // 少了这一段，用户一设密码手机自己的系统代理就断网。
    expect(container.read(patchClashConfigProvider).skipAuthPrefixes, [
      '127.0.0.1/32',
      '::1/128',
    ]);
    expect(find.text(l10n.skipAuthPrefixes), findsOneWidget);
    expect(find.text(l10n.skipAuthPrefixesDesc), findsOneWidget);
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
