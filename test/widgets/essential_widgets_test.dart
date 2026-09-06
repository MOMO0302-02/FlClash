import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/config.dart';
import 'package:clash_party/widgets/grid.dart';
import 'package:clash_party/widgets/super_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 钉住「基础磁贴删不掉，而且删掉过也能自己补回来」。
///
/// 手机端没有常驻导航栏，磁贴**就是唯一入口**：把「设置」删掉之后再也进不去设置页，
/// 主题、网络配置、备份全都够不着，只能重装。这是个能把用户锁在门外的坑，
/// 所以两道防线都要有——界面上不给删，读档时缺了还要补回来。
void main() {
  test('入口型磁贴都标了基础', () {
    const expected = {
      DashboardWidget.statusHero,
      DashboardWidget.profileTile,
      DashboardWidget.proxyGroupTile,
      DashboardWidget.settingTile,
    };
    final actual = DashboardWidget.values
        .where((item) => item.essential)
        .toSet();
    expect(actual, expected);
  });

  test('存档里缺了基础磁贴会补回来', () {
    // 模拟老版本存下来的、已经把「设置」和「配置」删掉的布局。
    final saved = dashboardWidgetsSafeFormJson([
      DashboardWidget.statusHero.name,
      DashboardWidget.logTile.name,
      DashboardWidget.proxyGroupTile.name,
    ]);
    expect(saved, contains(DashboardWidget.settingTile));
    expect(saved, contains(DashboardWidget.profileTile));
    // 原有的顺序和内容不能被打乱，只是在后面补。
    expect(saved.take(3), [
      DashboardWidget.statusHero,
      DashboardWidget.logTile,
      DashboardWidget.proxyGroupTile,
    ]);
  });

  test('没缺就原样返回，不会凭空多出磁贴', () {
    final input = [
      DashboardWidget.statusHero.name,
      DashboardWidget.profileTile.name,
      DashboardWidget.proxyGroupTile.name,
      DashboardWidget.settingTile.name,
    ];
    expect(dashboardWidgetsSafeFormJson(input).length, input.length);
  });

  testWidgets('不给删的磁贴不画删除按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperGrid(
            crossAxisCount: 8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 60,
            // 第 0 块当作基础磁贴：不给删。
            canDelete: (index) => index != 0,
            children: const [
              GridItem(
                crossAxisCellCount: 4,
                mainAxisCellCount: 1,
                child: SizedBox.expand(key: ValueKey('locked')),
              ),
              GridItem(
                crossAxisCellCount: 4,
                mainAxisCellCount: 1,
                child: SizedBox.expand(key: ValueKey('free')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // 两块磁贴都在，但只有一个删除按钮。
    expect(find.byKey(const ValueKey('locked')), findsOneWidget);
    expect(find.byKey(const ValueKey('free')), findsOneWidget);
    expect(
      find.byIcon(Icons.close),
      findsOneWidget,
      reason: '基础磁贴不该有删除按钮',
    );
  });
}
