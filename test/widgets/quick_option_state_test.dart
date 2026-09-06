import 'package:clash_party/models/config.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/views/dashboard/widgets/quick_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';

/// 开关磁贴现在是纯开关三件套：图标、开关、标题，**没有任何状态文字**。
///
/// 来历有两段：
/// 1. 最早这三块磁贴正文写死「选项」两个字——用户来问「仪表盘的选项是什么意思」，
///    于是一度改成写状态（「接管全部流量 / 仅本地端口」）。
/// 2. 但桌面端侧边栏的开关卡片（`components/sider/sysproxy-switcher.tsx` /
///    `tun-switcher.tsx`）压根没有状态文字——只有图标、开关、标题。用户要求和桌面端
///    统一，所以那行状态文字整个删掉。
///
/// 这条测试钉住的就是最终形态：正文里**既不能有「选项」、也不能再有那两句状态文字**，
/// 而开关本身还得能拨、拨了要真的生效。
void main() {
  Future<void> pump(WidgetTester tester, {required bool vpnEnabled}) async {
    final container = ProviderContainer(
      overrides: [
        vpnSettingProvider.overrideWithBuild(
          (_, _) => VpnProps(enable: vpnEnabled),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          // 磁贴高度和文字缩放都走 globalState 里这两个 late 字段，不初始化
          // 会当场抛 LateInitializationError。
          builder: (context, child) {
            globalState.measure = Measure.of(context, 1);
            globalState.theme = CommonTheme.of(context, 1);
            return child!;
          },
          home: const Scaffold(
            body: SizedBox(width: 200, child: VpnButton()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // 卡片里有开关和按压反馈这类带动画/定时器的东西，测试结束前先把树拆掉并把
  // 挂起的零时定时器 pump 掉，否则框架会报「A Timer is still pending」。
  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('磁贴上没有「选项」这种无意义的正文', (tester) async {
    await pump(tester, vpnEnabled: true);
    expect(find.text('选项'), findsNothing);
    await teardown(tester);
  });

  testWidgets('状态文字整个删掉（开着时），和桌面端开关卡片一致', (tester) async {
    await pump(tester, vpnEnabled: true);
    expect(find.text('接管全部流量'), findsNothing);
    expect(find.text('仅本地端口'), findsNothing);
    await teardown(tester);
  });

  testWidgets('状态文字整个删掉（关着时），和桌面端开关卡片一致', (tester) async {
    await pump(tester, vpnEnabled: false);
    expect(find.text('接管全部流量'), findsNothing);
    expect(find.text('仅本地端口'), findsNothing);
    await teardown(tester);
  });

  testWidgets('标题还在，就是「虚拟网卡」', (tester) async {
    await pump(tester, vpnEnabled: false);
    expect(find.text('虚拟网卡'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('开关能拨，拨了当场生效', (tester) async {
    await pump(tester, vpnEnabled: false);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await teardown(tester);
  });
}
