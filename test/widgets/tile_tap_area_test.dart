import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/dashboard_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 整块磁贴都要能点，不能只有文字和数字能点。
///
/// **来历**：用户反馈「开始页只有点数字才能进入二级菜单，没用过的根本找不到」。
///
/// 根因是卡片底层用的是 Material 的 `OutlinedButton`——它的点击区只覆盖「内容」，
/// 而磁贴内容是「图标一行 + Spacer + 标题」，中间那个 `Spacer` 是纯空白、
/// **不参与命中测试**。于是磁贴中间那一大片点了没反应。
///
/// 这类问题坏了也不会报错，只会让人觉得「这 App 怎么点不动」，所以必须有测试
/// 钉住。
void main() {
  Future<void> pump(WidgetTester tester, VoidCallback onTap) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          globalState.theme = CommonTheme.of(context, 1);
          return child!;
        },
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: DashboardTile(
                key: const ValueKey('tile'),
                icon: Icons.settings,
                label: '设置',
                onTap: onTap,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('磁贴正中间的空白也能点', (tester) async {
    var taps = 0;
    await pump(tester, () => taps++);

    // 正中间是 Spacer 所在的那片空白——原来正是这里点不动。
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('tile'))));
    await tester.pump();

    expect(
      taps,
      1,
      reason: '磁贴中间的空白区域点不动。用户会以为这块磁贴不能点。',
    );
  });

  testWidgets('磁贴四个方向的边缘区域都能点', (tester) async {
    var taps = 0;
    await pump(tester, () => taps++);
    final rect = tester.getRect(find.byKey(const ValueKey('tile')));

    // 沿着磁贴内部靠边的位置各点一次：左上、右上、左下、右下。
    // 内缩 12 像素避开边界本身，仍在磁贴范围内。
    const inset = 12.0;
    final points = <String, Offset>{
      '左上': rect.topLeft + const Offset(inset, inset),
      '右上': rect.topRight + const Offset(-inset, inset),
      '左下': rect.bottomLeft + const Offset(inset, -inset),
      '右下': rect.bottomRight + const Offset(-inset, -inset),
    };

    for (final entry in points.entries) {
      final before = taps;
      await tester.tapAt(entry.value);
      await tester.pump();
      expect(
        taps,
        before + 1,
        reason: '磁贴的${entry.key}区域点不动',
      );
    }
  });
}
