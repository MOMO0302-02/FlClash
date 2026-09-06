import 'package:clash_party/widgets/animated_cell_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 钉住「磁贴改尺寸时是平滑长大的，不是瞬间跳过去」。
///
/// 这条测试是有来历的：第一版把「检测尺寸变化」写在 `build` 里挂 post-frame 回调，
/// 而网格改尺寸时子项 widget 实例没变、Flutter 会跳过重建，`build` 根本不会再跑，
/// 于是动画一次都没触发。**界面看起来一切正常，只是少了动画，没有任何报错**，
/// 靠肉眼在真机上才发现。所以这里量的是动画中途的实际尺寸。
void main() {
  const key = ValueKey('cell');

  Widget host(double height) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: height,
            child: const AnimatedCellBox(
              child: ColoredBox(color: Color(0xFF123456), key: key),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('尺寸变大时会经过中间尺寸，而不是一步到位', (tester) async {
    await tester.pumpWidget(host(80));
    expect(tester.getSize(find.byKey(key)).height, 80);

    // 换成两倍高，等价于网格把磁贴从一行变两行。
    await tester.pumpWidget(host(174));
    await tester.pump();
    // 动画刚起步，内容还接近旧尺寸。
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getSize(find.byKey(key)).height;
    expect(
      mid,
      greaterThan(80),
      reason: '中途高度应该已经离开起点，说明动画在跑',
    );
    expect(
      mid,
      lessThan(174),
      reason: '中途高度不该已经到终点，到了就说明是瞬间跳变',
    );

    // 弹簧停下来之后必须严格等于网格给的尺寸，不能停在中间。
    // 不能用固定时长等：弹簧是渐进收敛的，等 400 毫秒还差零点几像素。
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(key)).height, 174);
  });

  testWidgets('尺寸变小时同样是平滑收回', (tester) async {
    await tester.pumpWidget(host(174));
    await tester.pumpWidget(host(80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getSize(find.byKey(key)).height;
    expect(mid, lessThan(174));
    expect(mid, greaterThan(80));

    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(key)).height, 80);
  });

  testWidgets('拖动过程中一比一跟手，不插动画', (tester) async {
    Widget dragging(Size? live) {
      return MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 80,
              child: CellResize(
                liveSize: live,
                child: const AnimatedCellBox(
                  child: ColoredBox(color: Color(0xFF123456), key: key),
                ),
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(dragging(null));
    expect(tester.getSize(find.byKey(key)).height, 80);

    // 手指拖到 120：这一帧就要是 120，不能慢慢过去——跟手不能有延迟。
    await tester.pumpWidget(dragging(const Size(200, 120)));
    expect(tester.getSize(find.byKey(key)).height, 120);

    await tester.pumpWidget(dragging(const Size(200, 150)));
    expect(tester.getSize(find.byKey(key)).height, 150);

    // 松手：从手指停下的 150 弹回格子的 80，中途必须在两者之间。
    await tester.pumpWidget(dragging(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getSize(find.byKey(key)).height;
    expect(mid, lessThan(150));
    expect(mid, greaterThan(80));

    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(key)).height, 80);
  });

  testWidgets('第一次出现不做动画', (tester) async {
    await tester.pumpWidget(host(174));
    // 进页面时所有磁贴一起长出来会很吵，第一帧必须就是最终尺寸。
    expect(tester.getSize(find.byKey(key)).height, 174);
  });
}
