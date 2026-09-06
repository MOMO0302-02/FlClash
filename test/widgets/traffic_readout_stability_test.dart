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

/// 「上传下载数字跳动」这件事要能被机器判定，不能只靠肉眼。
///
/// **宿主换过一次**：这些行为原本钉在状态总览上。2026-09-04 用户发现状态总览和
/// 流量统计显示的是同一份数据，数字统一收进流量统计，于是这里跟着改钉流量统计。
/// 行为要求一条没变。
///
/// **改之前用本文件实测到的三个数字**（探针就是这些用例，跑在改动前的代码上）：
/// * 一次速率更新（9 KB/s → 123 MB/s）之内，屏幕上依次画出 **12 个不同的数字**：
///   `9KB → 1.6MB → 5.4MB → 12.3MB → 24.7MB → 45.4MB → 74.8MB → 97.7MB →
///   110.8MB → 118.1MB → 121.7MB → 123MB`。来源是 `AnimatedCount` 的补间。
///   速率每秒刷新一次，所以这个滚动永不停歇。**这是主因。**
/// * 同一次更新之内，速率那一格的**宽度变了 4 次**（89 → 113.8 → 126.2 → 138.6），
///   于是旁边那行大字（出口 IP）的可用宽度也跟着变 4 次。来源是那一格原本给的是
///   `maxWidth` 而不是写死的宽度。
/// * 箭头图标本身**没动**（逐帧只量到 1 个矩形）——原来的
///   `Column(crossAxisAlignment: end)` 已经把它钉在右边缘了。这条**不是**根因，
///   但下面照样钉住，防止以后改排版时把它弄丢。
void main() {
  late ProviderContainer container;

  Future<void> pumpTile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        trafficsProvider.overrideWithBuild((_, _) => FixedList(30)),
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
          home: const Scaffold(
            // 半宽磁贴在 8 列网格里占 4 列。
            body: Center(child: SizedBox(width: 160, child: TrafficUsage())),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 当前画在屏幕上的上行速率文本。
  String? speedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((item) => item.data)
      .whereType<String>()
      .where((item) => item.endsWith('/s'))
      .firstOrNull;

  /// 推一个新采样进去，然后**逐帧**把上行那行的文本收集起来（相邻重复的不记）。
  ///
  /// 62 帧 ≈ 1 秒，比任何补间都长，跑不完的话这里会看得见。
  Future<List<String>> feedAndCollect(
    WidgetTester tester,
    Traffic value,
  ) async {
    container.read(trafficsProvider.notifier).addTraffic(value);
    final seen = <String>[];
    for (var i = 0; i < 62; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final text = speedText(tester);
      if (text != null && (seen.isEmpty || seen.last != text)) {
        seen.add(text);
      }
    }
    return seen;
  }

  /// 实时上行那一行里的箭头。**必须按 key 限定在这一行之内**：磁贴上有两个向上
  /// 的箭头（实时一个、累计一个），不限定的话量到的是哪个全看渲染顺序。
  Rect arrowRect(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byKey(const ValueKey('rate-up')),
      matching: find.byIcon(Icons.arrow_upward),
    ),
  );

  Rect readoutRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('rate-up')));

  /// 一串位数刻意各不相同的速率：1 位 / 2 位 / 3 位 / 4 位，外加跨单位。
  const samples = <Traffic>[
    Traffic(up: 0, down: 0),
    Traffic(up: 9 * 1024, down: 9 * 1024),
    Traffic(up: 99 * 1024, down: 99 * 1024),
    Traffic(up: 999 * 1024, down: 999 * 1024),
    Traffic(up: 1023 * 1024, down: 1023 * 1024),
    Traffic(up: 5 * 1024 * 1024, down: 5 * 1024 * 1024),
    Traffic(up: 123 * 1024 * 1024, down: 123 * 1024 * 1024),
  ];

  testWidgets('一次数据更新只换一次数字，不做补间', (tester) async {
    await pumpTile(tester);
    // 先垫一个非零值，免得第一次更新是「从空白到有内容」。
    await feedAndCollect(tester, samples[1]);

    final seen = await feedAndCollect(
      tester,
      const Traffic(up: 123 * 1024 * 1024, down: 123 * 1024 * 1024),
    );

    // 桌面端 conn-card.tsx 没有任何补间，数字来一个换一个。改动前这里是 12。
    expect(
      seen.length,
      1,
      reason: '一次更新之内屏幕上换了 ${seen.length} 次数字：$seen',
    );
    expect(seen.single, '123.0 MB/s');
  });

  testWidgets('速率那一格的尺寸恒定，不随数字位数变', (tester) async {
    await pumpTile(tester);

    final rects = <Rect>[];
    for (final sample in samples) {
      await feedAndCollect(tester, sample);
      rects.add(readoutRect(tester));
    }

    // 这一行的尺寸不许随数字位数变——变了就会把下面三行一起推动。
    // （在状态总览上时这条还兼管「别挤到旁边那行大字」，那个邻居已经不存在了，
    // 但「自己别变高变宽」这一半仍然成立。）
    for (final rect in rects) {
      expect(rect, rects.first, reason: '实时上行那一行的尺寸变了：$rects');
    }
  });

  testWidgets('数字位数变化时箭头一动不动', (tester) async {
    await pumpTile(tester);

    final rects = <Rect>[];
    for (final sample in samples) {
      await feedAndCollect(tester, sample);
      rects.add(arrowRect(tester));
    }

    for (final rect in rects) {
      expect(rect, rects.first, reason: '箭头位置随数字位数变了：$rects');
    }
  });

  testWidgets('速率文字用等宽数字', (tester) async {
    await pumpTile(tester);
    await feedAndCollect(tester, samples[6]);

    // 上下行同值，所以这个文本会命中两个 Text，取第一个即可。
    final text = tester.widgetList<Text>(find.text('123.0 MB/s')).first;
    // 位数不变时连字形宽度都不许变：比例字体里 `1` 比 `8` 窄，右对齐只能保住
    // 整串的右边缘，保不住串内部数字的位置。
    expect(
      text.style?.fontFeatures?.map((item) => item.feature),
      contains('tnum'),
    );
  });
}
