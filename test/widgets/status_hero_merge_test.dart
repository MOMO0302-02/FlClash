import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/widgets.dart';
import 'package:clash_party/widgets/speed_sparkline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「网络速度」磁贴并进「状态总览」之后要守住的东西。
///
/// 合并本身是排版，肉眼看得出来；这里钉的是**肉眼看不出来、坏了也没人发现**的
/// 几件事：曲线画的到底是哪个数、卡片上会不会又冒出和流量统计重复的数字、老存档
/// 会不会因为少了一个枚举值就被打回默认布局。
void main() {
  Future<void> pumpHero(
    WidgetTester tester, {
    required List<Traffic> traffics,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        trafficsProvider.overrideWithBuild(
          (_, _) => FixedList(30, list: traffics),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(400, 900));

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
    // AnimatedCount 从 0 滚到目标值，得等它跑完再读文字。
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('曲线画的是上行 + 下行之和，而且只取最近十个采样', (tester) async {
    // 12 个采样：前两个是巨大的干扰值，只有后 10 个该进窗口。
    final traffics = <Traffic>[
      const Traffic(up: 1e9, down: 1e9),
      const Traffic(up: 1e9, down: 1e9),
      for (var i = 0; i < 10; i++) Traffic(up: i * 10, down: i * 100),
    ];
    await pumpHero(tester, traffics: traffics);

    final sparkline = tester.widget<SpeedSparkline>(
      find.byType(SpeedSparkline),
    );
    // 合成一条线，不是上下行两条：桌面端 conn-card.tsx:139 是 `info.up + info.down`。
    expect(sparkline.values, [
      for (var i = 0; i < 10; i++) i * 110.0,
    ]);
  });

  testWidgets('状态总览不显示速率，也不显示累计流量', (tester) async {
    await pumpHero(
      tester,
      traffics: const [Traffic(up: 1024, down: 2 * 1024 * 1024)],
    );

    // **来历**：流量统计磁贴重做之后画的就是「实时速率 + 累计」，和这块卡片
    // 原来右侧的速率、底部的累计完全重复——用户在添加磁贴面板里一眼看出两块
    // 磁贴显示同一份数据。数字统一归流量统计，这块卡片只管状态本身。
    //
    // 钉的是**屏幕上有没有这些数字**，不是「代码里删没删某个组件」——换个写法
    // 把数字加回来照样得报红。
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((item) => item.data)
        .whereType<String>()
        .toList();

    expect(
      texts.where((item) => item.contains('/s')),
      isEmpty,
      reason: '状态总览又出现速率了：$texts',
    );
    expect(
      texts.where((item) => item.contains('KB') || item.contains('MB')),
      isEmpty,
      reason: '状态总览又出现流量数字了：$texts',
    );
  });

  testWidgets('背景曲线保留：它是卡片背景，不是重复的读数', (tester) async {
    await pumpHero(
      tester,
      traffics: const [Traffic(up: 1024, down: 2 * 1024 * 1024)],
    );
    // 去重复时容易顺手把曲线也一起删掉。桌面端 `conn-card.tsx` 正是「曲线作
    // 背景 + 状态作主角」，曲线不构成重复，得留着。
    expect(find.byType(SpeedSparkline), findsOneWidget);
  });

  test('老存档里遗留的 networkSpeed 只被跳过，不会把整份布局打回默认', () {
    final restored = dashboardWidgetsSafeFormJson([
      'statusHero',
      'networkSpeed',
      'outboundModeV2',
    ]);

    expect(restored.contains(DashboardWidget.statusHero), isTrue);
    expect(restored.contains(DashboardWidget.outboundModeV2), isTrue);
    // 打回默认的话会多出 vpnButton / settingTile 这一大串。
    expect(
      restored.where((item) => !item.essential).toList(),
      [DashboardWidget.outboundModeV2],
    );
  });

  test('状态总览仍然是整宽两行', () {
    final item = DashboardWidget.statusHero.widget;
    expect(item.crossAxisCellCount, 8);
    expect(item.mainAxisCellCount, 2);
  });
}
