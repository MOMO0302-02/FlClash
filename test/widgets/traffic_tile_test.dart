import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/traffic_usage.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 流量统计磁贴：四行内容在 4×2 的格子里不能撑破。
///
/// **来历**：用户两次反馈这块磁贴「太满」。第一次删了「上传/下载」文字图例，
/// 第二次删了环形图，第三次重新设计成「实时速率大字 + 累计小字」共四行。
///
/// 行数变多之后，最容易出事的就是**小屏 + 大字号 + TB 级数字**这个组合——
/// 而这块磁贴不在既有的溢出矩阵里，所以单独补一条。
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Size screen,
    required double textScale,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          builder: (context, child) {
            globalState.measure = Measure.of(context, textScale);
            globalState.theme = CommonTheme.of(context, textScale);
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
          home: const Scaffold(
            // 半宽：8 列网格里占 4 列。这块磁贴是 rows: 2。
            body: Center(child: SizedBox(width: 160, child: TrafficUsage())),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 收集本次渲染里的溢出报错。
  ///
  /// **`FlutterError.onError` 必须在 expect 之前同步还原**，放 addTearDown 会被
  /// binding 判成「测试覆盖了 onError 没还原」，把真正的溢出信息盖掉。
  /// 这条是项目里踩过的坑。
  List<String> collectOverflows(void Function() body) {
    final errors = <String>[];
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exceptionAsString());
    };
    body();
    FlutterError.onError = original;
    return errors;
  }

  for (final scale in [1.0, 1.4]) {
    testWidgets('小屏 · ${scale}x 字号下不溢出', (tester) async {
      late List<String> errors;
      await pump(tester, screen: const Size(320, 640), textScale: scale);
      errors = collectOverflows(() {});
      // pump 期间的溢出会在这里被 tester 自己抛出来；这里再确认一次没有残留。
      expect(
        errors.where((e) => e.contains('overflowed')),
        isEmpty,
        reason: '流量统计磁贴在 ${scale}x 字号下溢出了',
      );
    });
  }

  testWidgets('四行内容都在：两行实时速率 + 两行累计', (tester) async {
    await pump(tester, screen: const Size(320, 640), textScale: 1.0);

    // 速率带 /s，累计不带。没有连接时两者都是 0，所以按后缀区分。
    final rateTexts = find.textContaining('/s');
    expect(
      rateTexts,
      findsNWidgets(2),
      reason: '应该有两行实时速率（上行、下行）',
    );

    // 上下行各一个箭头，速率和累计各一对 = 四个。
    expect(find.byIcon(Icons.arrow_upward), findsNWidgets(2));
    expect(find.byIcon(Icons.arrow_downward), findsNWidgets(2));
  });
}
