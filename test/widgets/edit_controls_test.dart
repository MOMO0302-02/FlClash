import 'package:clash_party/common/common.dart';
import 'package:clash_party/widgets/grid.dart';
import 'package:clash_party/widgets/super_grid.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 编辑模式下两个控件不能挤在一起。
///
/// 用户反馈原话：「删除磁贴和大小移动按钮贴的太近了」。原来删除在右上、改尺寸在
/// 右下，**同一条边上下相邻**；一行高的磁贴只有 80 像素，而成年人手指的接触面
/// 直径就有 40 到 45 像素——按哪个全看运气。
///
/// 现在删除在顶部中央、改尺寸在右下角，是这块卡片上能拉得最开的一对位置。
///
/// 这条测试量的是**两个控件中心的实际距离**，不是"代码里写了不同的坐标"。
void main() {
  const cell = Size(160, 80);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeferredPointerHandler(
            child: SizedBox(
              width: cell.width * 2,
              height: cell.height * 2,
              child: SuperGrid(
                crossAxisCount: 2,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
                mainAxisExtent: cell.height,
                // 传了 onResize 才画手柄。
                onResize: (_, _, _) {},
                children: const [
                  GridItem(
                    crossAxisCellCount: 1,
                    mainAxisCellCount: 1,
                    child: SizedBox.expand(key: ValueKey('a')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('改尺寸手柄只有一个', (tester) async {
    await pump(tester);
    final handle = find.byKey(const ValueKey('resize-handle'));
    expect(handle, findsOneWidget, reason: '缺少改尺寸手柄');

    // 用户要「简洁一点」＝手柄只此一个。数的是**实际探出磁贴的控件个数**：
    // 编辑模式下用 DeferPointer 的只有改尺寸手柄和删除按钮，所以正好 2 个。
    // 四角那一版会数到 5。只查 `resize-handle` 这一个 key 是不够的——别人再挂
    // 三个别的 key 的手柄，那种查法照样绿。
    expect(
      find.byType(DeferPointer),
      findsNWidgets(2),
      reason: '磁贴上探出边界的控件不是「一个手柄 + 一个删除」',
    );

  });

  testWidgets('删除按钮离改尺寸手柄够远，不会误触', (tester) async {
    await pump(tester);
    final delete = tester.getCenter(find.byIcon(Icons.close));
    final handle = tester.getCenter(
      find.byKey(const ValueKey('resize-handle')),
    );

    // 用户明确担心过「改大小和删除挨太近会误触」。一根手指的接触面约 45 像素，
    // 两个控件中心至少要拉开 60。
    expect(
      (delete - handle).distance,
      greaterThan(60),
      reason:
          '删除按钮离手柄只有 ${(delete - handle).distance.toStringAsFixed(0)} 像素，会误触',
    );
  });

  testWidgets('删除在左上角、手柄在右下角，成对角', (tester) async {
    await pump(tester);
    final delete = tester.getCenter(find.byIcon(Icons.close));
    final handle = tester.getCenter(
      find.byKey(const ValueKey('resize-handle')),
    );
    final tile = tester.getRect(find.byKey(const ValueKey('a')));

    // 对角是这块卡片上能拉得最开的一对位置。钉住「各自在哪个象限」而不是具体
    // 坐标——排版微调不该让测试变红，但两者跑到同一侧必须红。
    expect(delete.dx, lessThan(tile.center.dx), reason: '删除应在左半边');
    expect(delete.dy, lessThan(tile.center.dy), reason: '删除应在上半边');
    expect(handle.dx, greaterThan(tile.center.dx), reason: '手柄应在右半边');
    expect(handle.dy, greaterThan(tile.center.dy), reason: '手柄应在下半边');
  });

  testWidgets('手柄的弧和磁贴圆角同心、同半径', (tester) async {
    await pump(tester);

    final context = tester.element(find.byType(SuperGrid));
    final radius = context.styleTokens.cardRadius;

    // ① 图形尺寸由圆角半径推出来。改成画直角（半径 0）会让它缩到 12，一测就红。
    //    这里不抄数字，对着源码里同一个算式验——抄数字的话改了臂长两边一起改，
    //    等于没测。
    final glyph = tester.getSize(
      find.descendant(
        of: find.byKey(const ValueKey('resize-handle')),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      glyph.width,
      closeTo(resizeHandleGlyphSize(radius), 0.01),
      reason: '手柄图形没跟着磁贴圆角走，那道弧就贴不上',
    );
    expect(glyph.height, closeTo(glyph.width, 0.01));

    // ② 图形的外角正好落在磁贴的角上——这正是「弧和圆角同心」的几何条件。
    final tile = tester.getRect(find.byKey(const ValueKey('a')));
    final handleBox = tester.getRect(
      find.byKey(const ValueKey('resize-handle')),
    );
    final glyphOuter = Offset(
      handleBox.center.dx + glyph.width / 2 - 2,
      handleBox.center.dy + glyph.height / 2 - 2,
    );
    expect(glyphOuter.dx, closeTo(tile.right, 0.51), reason: '弧没对上磁贴的角');
    expect(glyphOuter.dy, closeTo(tile.bottom, 0.51), reason: '弧没对上磁贴的角');
  });

  testWidgets('手柄的触摸区比画出来的线条大', (tester) async {
    await pump(tester);
    // 括号画出来只有 18 像素，但可按范围是 44×44——细线条也不影响按得中。
    final box = tester.getSize(find.byKey(const ValueKey('resize-handle')));
    expect(box.width, greaterThanOrEqualTo(40));
    expect(box.height, greaterThanOrEqualTo(40));
  });
}
