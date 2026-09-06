import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/config/sniffer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 域名嗅探设置页。
///
/// 钉住几件平时看不出来、坏了也没人发现的事：
/// 1. 每一行的标题和说明**真的有译文**——l10n 少补一层的话页面上会是空白行；
/// 2. 总开关关掉时下面整组消失——关掉时应用根本不下发这一段，留在那儿只会让人
///    拨一堆不生效的开关；
/// 3. 协议开关改的是 **`sniff` 表里有没有这个键**，不是某个布尔字段。内核只加载
///    表里出现过的协议键，写成改布尔值的话"关掉 QUIC"会毫无效果，而这件事在界面
///    上完全看不出来；
/// 4. 端口列表为空显示的是"内核默认端口"而不是一片空白——空列表不是"没端口"。
void main() {
  Future<ProviderContainer> pumpSnifferView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: SnifferView()),
      ),
    );
    await tester.pump();
    return container;
  }

  Sniffer snifferOf(ProviderContainer container) =>
      container.read(patchClashConfigProvider).sniffer;

  testWidgets('出厂就是开着的，三个协议都在，且 QUIC 有单独说明', (tester) async {
    final container = await pumpSnifferView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    // 出厂值本身。2026-09-03 按官方推荐配置由关改成开。
    expect(snifferOf(container).enable, isTrue);
    expect(snifferOf(container).sniff.keys, containsAll(['HTTP', 'TLS', 'QUIC']));

    for (final text in ['HTTP', 'TLS', 'QUIC']) {
      expect(find.text(text), findsOneWidget, reason: '页面上找不到协议「$text」');
    }
    // QUIC 单独标注：安卓上 Chrome 默认走它，不嗅探就拿不到域名。
    expect(find.text(l10n.snifferQuicDesc), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('每一行的标题和说明都有译文', (tester) async {
    await pumpSnifferView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    // 「域名嗅探」这一条既是页面标题又是总开关的标题，会出现两次，所以这一组
    // 只查"在不在"，不查出现几次。
    for (final text in [
      l10n.sniffer,
      l10n.snifferDesc,
      l10n.snifferOverrideDest,
      l10n.snifferOverrideDestDesc,
      l10n.snifferForceDnsMapping,
      l10n.snifferForceDnsMappingDesc,
      l10n.snifferParsePureIp,
      l10n.snifferParsePureIpDesc,
      l10n.snifferSkipDomain,
      l10n.snifferSkipDomainDesc,
      l10n.snifferForceDomain,
      l10n.snifferForceDomainDesc,
      l10n.snifferSkipDstAddress,
      l10n.snifferSkipDstAddressDesc,
      l10n.snifferSkipSrcAddress,
      l10n.snifferSkipSrcAddressDesc,
    ]) {
      expect(
        find.text(text),
        findsAtLeastNWidgets(1),
        reason: '页面上找不到「$text」',
      );
    }
    expect(tester.takeException(), null);
  });

  testWidgets('关掉总开关，下面整组消失', (tester) async {
    final container = await pumpSnifferView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));
    expect(find.text(l10n.snifferOverrideDest), findsOneWidget);

    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.sniffer(enable: false));
    // 收起带动画，得让它跑完。
    await tester.pumpAndSettle();

    expect(find.text(l10n.snifferOverrideDest), findsNothing);
    expect(find.text(l10n.snifferSkipDomain), findsNothing);
    expect(find.text('QUIC'), findsNothing);
    // 总开关本身要留着，否则再也开不回来。页面标题也是同一句话，所以是两处。
    expect(find.text(l10n.sniffer), findsNWidgets(2));
    expect(tester.takeException(), null);
  });

  testWidgets('关掉某个协议是把键从 sniff 表里删掉，不是留个空配置', (tester) async {
    final container = await pumpSnifferView(tester);

    await tester.tap(find.text('QUIC'));
    await tester.pumpAndSettle();

    // 关键：内核 parseSniffer 拿 sniff 的**键**去比对 snifferTypes.List，
    // 留一个 SnifferConfig() 在表里等于没关掉。
    expect(snifferOf(container).sniff.containsKey('QUIC'), isFalse);
    expect(snifferOf(container).sniff.keys, containsAll(['HTTP', 'TLS']));
  });

  testWidgets('重新打开一个协议时端口留空——那正是"用内核默认端口"', (tester) async {
    final container = await pumpSnifferView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    await tester.tap(find.text('QUIC'));
    await tester.pumpAndSettle();
    expect(snifferOf(container).sniff.containsKey('QUIC'), isFalse);

    await tester.tap(find.text('QUIC'));
    await tester.pumpAndSettle();

    expect(snifferOf(container).sniff['QUIC']!.ports, isEmpty);
    // 空列表必须在界面上说成"内核默认端口"，否则用户以为自己漏填了。
    expect(find.text(l10n.snifferPortsDefault), findsOneWidget);
  });

  testWidgets('端口那一行显示的是当前端口', (tester) async {
    await pumpSnifferView(tester);
    // HTTP 出厂端口是 80 和 443。
    expect(find.text('80, 443'), findsOneWidget);
  });

  testWidgets('打开全局"用嗅探结果作为目标"时，HTTP 那一条要跟着改', (tester) async {
    final container = await pumpSnifferView(tester);
    final l10n = await AppLocalizations.load(const Locale('zh', 'CN'));

    expect(snifferOf(container).overrideDest, isFalse);
    expect(snifferOf(container).sniff['HTTP']!.overrideDest, isFalse);

    await tester.tap(find.text(l10n.snifferOverrideDest));
    await tester.pumpAndSettle();

    expect(snifferOf(container).overrideDest, isTrue);
    // 内核里协议自己的 override-destination 优先于全局那个。HTTP 这一条我们的
    // 出厂值明写着 false，不跟着改的话用户拨了全局开关 HTTP 依然我行我素。
    expect(snifferOf(container).sniff['HTTP']!.overrideDest, isTrue);
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
