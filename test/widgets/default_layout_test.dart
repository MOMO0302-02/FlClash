import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/config.dart';
import 'package:clash_party/widgets/grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 钉住首页的默认布局。
///
/// 网格是按顺序往第一个放得下的空位塞的，所以**磁贴的先后顺序就是排版**。
/// 顺序一改就可能多出一行半空的，而这种事光看代码看不出来——必须把它摆出来量。
///
/// 2026-09-03 起默认**全部磁贴都显示**。原来那条「默认只放六块、观测类一块都不放」
/// 的口径连同那张"这些不该出现在默认布局里"的名单一起作废——那张名单现在整条都不
/// 成立，留着就是一条永远为真的空断言。
void main() {
  const columns = 8;
  const spacing = 14.0;
  const rowUnit = 80.0 + spacing;
  const width = 360.0;

  /// 一块磁贴在 n 行 / m 列时该占多高多宽。
  double heightOf(num rows) => rowUnit * rows - spacing;
  double widthOf(int cols) => (width + spacing) / columns * cols - spacing;

  List<DashboardWidget> visibleOn(List<SupportPlatform> platforms) =>
      defaultDashboardWidgets
          .where((item) => item.platforms.any(platforms.contains))
          .toList();

  Future<Map<String, Rect>> layout(
    WidgetTester tester,
    List<SupportPlatform> platforms,
  ) async {
    final visible = visibleOn(platforms);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: Grid(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: rowUnit,
              children: [
                for (final item in visible)
                  GridItem(
                    crossAxisCellCount: item.widget.crossAxisCellCount,
                    mainAxisCellCount: item.widget.mainAxisCellCount,
                    child: SizedBox.expand(key: ValueKey(item.name)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return {
      for (final item in visible)
        item.name: tester.getRect(find.byKey(ValueKey(item.name))),
    };
  }

  test('默认布局收录了每一块磁贴，一块都不落下', () {
    // 用户要的就是"全都显示"。少一块这条就红——包括以后往枚举里加了新磁贴却忘了
    // 补进默认列表的情况。
    expect(
      defaultDashboardWidgets.toSet(),
      DashboardWidget.values.toSet(),
      reason: '默认布局必须包含 DashboardWidget 的全部枚举值',
    );
    // 顺便挡住"同一块列了两次"——重复会在页面上真的画出两块。
    expect(
      defaultDashboardWidgets.length,
      DashboardWidget.values.length,
      reason: '默认布局里有重复的磁贴',
    );
  });

  test('顺序是"常用在上、观测在下"', () {
    // 顺序就是排版，所以顺序本身要钉住。这里钉的是分组边界，不逐个钉位置——
    // 逐个钉的话组内换一下先后就红，太脆。
    int at(DashboardWidget item) => defaultDashboardWidgets.indexOf(item);

    // 进首页第一眼要看到的是"现在通不通"和"走哪种模式"。
    expect(defaultDashboardWidgets.first, DashboardWidget.statusHero);
    expect(defaultDashboardWidgets[1], DashboardWidget.outboundModeV2);

    // 会真的改变"流量怎么走"的开关排在常用入口前面。
    for (final switcher in [
      DashboardWidget.vpnButton,
      DashboardWidget.tunButton,
      DashboardWidget.systemProxyButton,
      DashboardWidget.smartRoutingButton,
    ]) {
      expect(
        at(switcher),
        lessThan(at(DashboardWidget.proxyGroupTile)),
        reason: '${switcher.name} 是开关，该排在常用入口前面',
      );
    }

    // 观测类全部排在常用入口后面。
    for (final observer in [
      DashboardWidget.trafficUsage,
      DashboardWidget.networkDetection,
      DashboardWidget.intranetIp,
      DashboardWidget.connectionTile,
      DashboardWidget.requestTile,
      DashboardWidget.logTile,
      DashboardWidget.resourceTile,
      DashboardWidget.memoryInfo,
    ]) {
      expect(
        at(observer),
        greaterThan(at(DashboardWidget.settingTile)),
        reason: '${observer.name} 是观测类，该排在常用入口后面',
      );
    }
  });

  testWidgets('安卓默认布局：除了最后一行，每一行都排满', (tester) async {
    tester.view.physicalSize = const Size(360, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rects = await layout(tester, [SupportPlatform.Android]);

    // 平台过滤要真的在起作用：桌面专用的两块不该出现，安卓专用的那块要在。
    expect(rects.containsKey('tunButton'), isFalse);
    expect(rects.containsKey('systemProxyButton'), isFalse);
    expect(rects.containsKey('vpnButton'), isTrue);
    expect(rects.length, visibleOn([SupportPlatform.Android]).length);

    final full = widthOf(columns);

    // 整宽的两块必须真的是整宽。
    for (final name in ['statusHero', 'outboundModeV2']) {
      expect(rects[name]!.width, closeTo(full, 0.5), reason: name);
    }
    // 跨两行的两块必须真的跨两行。
    for (final name in ['statusHero', 'trafficUsage']) {
      expect(rects[name]!.height, closeTo(heightOf(2), 0.5), reason: name);
    }

    // 按行统计占了多少列：行号用顶边除以行高算，跨两行的按它压住的每一行各记一次。
    // 这样"有没有豁口"就变成"每一行的列数够不够 8"，比数总高度稳——总高度只能
    // 看出多没多出一行，看不出豁口在哪。
    final top = rects.values
        .map((rect) => rect.top)
        .reduce((a, b) => a < b ? a : b);
    final bottom = rects.values
        .map((rect) => rect.bottom)
        .reduce((a, b) => a > b ? a : b);
    final rowCount = ((bottom - top + spacing) / rowUnit).round();
    final filled = List<int>.filled(rowCount, 0);
    for (final rect in rects.values) {
      final firstRow = ((rect.top - top) / rowUnit).round();
      final spanRows = ((rect.height + spacing) / rowUnit).round();
      final spanCols = ((rect.width + spacing) / ((width + spacing) / columns))
          .round();
      for (var row = firstRow; row < firstRow + spanRows; row++) {
        filled[row] += spanCols;
      }
    }

    // 除了最后一行，每一行都必须正好占满 8 列。中间留豁口说明顺序排错了。
    for (var row = 0; row < rowCount - 1; row++) {
      expect(filled[row], columns, reason: '第 ${row + 1} 行没排满（有豁口）');
    }
    // 最后一行允许半空：磁贴总数是奇数，凑不满。**不为了凑满去删磁贴、也不改磁贴
    // 尺寸**——尺寸是那块磁贴自己的排版需要，不该被这里的凑数需求绑架。
    expect(
      filled[rowCount - 1],
      anyOf(columns, columns ~/ 2),
      reason: '最后一行应该是排满或正好半格',
    );
  });
}
