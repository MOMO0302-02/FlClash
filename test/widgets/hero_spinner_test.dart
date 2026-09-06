import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clash_party/widgets/hero_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测延迟时那个转圈，必须和桌面端（HeroUI Spinner）一致。
///
/// 用户原话：「那个延迟加载的动画还是用的 FlClash 一样的，需要改为和桌面端加载
/// 一致」。安卓端原来用的是 `CommonCircleLoading`——一个 Material 3 Expressive
/// 的多边形变形加载器，形状每 650 毫秒就变一次，和桌面端那两道细弧完全不像。
///
/// 桌面端规格（`node_modules/@heroui/theme`）：两个同心圆环，只画**底部四分之一
/// 圆弧**，外圈实线、内圈点线且透明度 0.75，两圈周期都是 0.8 秒但缓动不同
/// （ease / linear）。
void main() {
  const boundaryKey = ValueKey('spinner');
  const size = 60.0;

  /// 把转圈画出来，返回 (像素, 宽, 高)。
  ///
  /// **`toImage` / `toByteData` 必须放进 `runAsync`**：它们由引擎线程完成，
  /// 直接 await 会永远等不到结果——测试会挂到超时，而不是报错。第一版就是这么
  /// 写的，白跑了十分钟。
  Future<(ByteData, int, int)> shoot(WidgetTester tester) async {
    final boundary =
        tester.renderObject(find.byKey(boundaryKey)) as RenderRepaintBoundary;
    late ByteData data;
    late int width;
    late int height;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      width = image.width;
      height = image.height;
      image.dispose();
    });
    return (data, width, height);
  }

  /// 某个像素的亮度（0~255）。画布是纯黑底 + 纯白弧，所以亮度≈覆盖程度。
  int lum(ByteData data, int width, int x, int y) {
    return data.getUint8((y * width + x) * 4);
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF000000),
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: size,
                height: size,
                // 纯白画在纯黑底上，像素亮度就直接是覆盖程度。
                child: HeroSpinner(color: Color(0xFFFFFFFF)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('只画底部那一段弧，上半圈是空的', (tester) async {
    await pump(tester);
    final (data, w, h) = await shoot(tester);
    // 沿圆周采样：底部（90° 附近）必须有东西，正上方（270° 附近）必须是空的。
    // 这是和 FlClash 那个加载器最本质的区别——那个是整圈的多边形。
    final radius = (math.min(w, h) - w * 2 / 20) / 2;
    int atAngle(double degrees) {
      final rad = degrees * math.pi / 180;
      return lum(
        data,
        w,
        (w / 2 + radius * math.cos(rad)).round().clamp(0, w - 1),
        (h / 2 + radius * math.sin(rad)).round().clamp(0, h - 1),
      );
    }

    // 起始那一帧两圈都还没转，弧都在底部。
    expect(atAngle(90), greaterThan(80), reason: '底部应该有弧');
    expect(atAngle(270), lessThan(20), reason: '顶部应该是空的');
    expect(atAngle(0), lessThan(20), reason: '右侧应该是空的');
    expect(atAngle(180), lessThan(20), reason: '左侧应该是空的');
  });

  testWidgets('是一道描边的弧，不是填出来的一块', (tester) async {
    await pump(tester);
    final (data, w, h) = await shoot(tester);
    final radius = (math.min(w, h) - w * 2 / 20) / 2;

    // 只看正中心是不够的：变异测试当场证明了这一点。把 `PaintingStyle.stroke`
    // 改成 `fill` 之后，`drawArc(useCenter: false)` 填的是弧与弦之间那块，
    // **正中心照样是空的**，测试照绿。
    //
    // 真正能分辨的是「从弧往圆心走一小段，必须立刻变暗」——描边只有两像素厚，
    // 填充则会一路亮到弦上。
    final cx = w ~/ 2;
    final onArc = lum(data, w, cx, (h / 2 + radius).round().clamp(0, h - 1));
    final justInside = lum(
      data,
      w,
      cx,
      (h / 2 + radius * 0.75).round().clamp(0, h - 1),
    );

    expect(onArc, greaterThan(80), reason: '弧上应该是亮的');
    expect(justInside, lessThan(20), reason: '弧往里一点必须马上暗下来，否则就是填充不是描边');
    expect(lum(data, w, cx, h ~/ 2), lessThan(20), reason: '正中心必须是空的');
  });

  testWidgets('会转起来：等半个周期后弧不在原来的位置', (tester) async {
    await pump(tester);
    final (before, w0, h0) = await shoot(tester);
    final baseline = lum(before, w0, w0 ~/ 2, h0 - 3);

    // 周期 0.8 秒，走 0.4 秒正好半圈，底部那段弧应该转到顶上去。
    await tester.pump(const Duration(milliseconds: 400));
    final (after, w1, h1) = await shoot(tester);
    final now = lum(after, w1, w1 ~/ 2, h1 - 3);

    expect(
      (now - baseline).abs(),
      greaterThan(40),
      reason: '半个周期后底部的亮度该有明显变化，说明它真的在转',
    );
  });

  testWidgets('两圈缓动不同——转到中途时它们不在同一个角度', (tester) async {
    await pump(tester);
    // 取一个 ease 和 linear 差得最开的时刻。cubic-bezier(.25,.1,.25,1) 在
    // t=0.25 时约为 0.41，两者差约 0.16 圈 ≈ 58°，足够拉开。
    await tester.pump(const Duration(milliseconds: 200));
    final (data, w, h) = await shoot(tester);

    // 沿整圈数一下有多少个方向上是亮的。两圈锁死时只会有一段连续的弧；
    // 错开时会出现两段。这里数「亮→暗」的跳变次数。
    final radius = (math.min(w, h) - w * 2 / 20) / 2;
    var runs = 0;
    var wasLit = false;
    for (var deg = 0; deg < 360; deg++) {
      final rad = deg * math.pi / 180;
      final v = lum(
        data,
        w,
        (w / 2 + radius * math.cos(rad)).round().clamp(0, w - 1),
        (h / 2 + radius * math.sin(rad)).round().clamp(0, h - 1),
      );
      final lit = v > 60;
      if (lit && !wasLit) {
        runs++;
      }
      wasLit = lit;
    }
    expect(
      runs,
      greaterThanOrEqualTo(2),
      reason:
          '转到中途应该看得到两段弧。只有一段说明两圈用了同一条缓动曲线——'
          '那样它们会锁死成一个整体，桌面端「两道弧互相追」的观感就没了',
    );
  });
}
