import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clash_party/common/constant.dart';
import 'package:clash_party/widgets/speed_sparkline.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 波动线是纯视觉的东西，唯一能验的手段就是**把它画出来数像素**。
///
/// 对照物是 clash-party 桌面端 `components/sider/conn-card.tsx` 那张 Chart.js
/// 折线图，这里逐条钉住它最容易被人「顺手改回去」的四个特征：
/// 1. 只有渐变填充、**没有描边**（`borderColor: 'transparent'` / `borderWidth: 0`）；
/// 2. 渐变是**上浓下透**（顶部 0.8 → 底部 0）；
/// 3. 固定 **10** 个点，多余的采样只取末尾、不足的在左边补 0；
/// 4. 数据一到**按采样节拍插值过去**，不是硬切。
///
///    这一条**故意偏离桌面端**：桌面端 `conn-card.tsx:124-126` 写的是
///    `animation: { duration: 0 }`，最初照抄了，也用测试钉过"不做补间"。
///    但用户实际看下来的反馈是「直接跳」，明确要求做顺。用户的要求优先于
///    "照抄桌面端"这条默认规则，所以这里改成插值——**别看到这段就以为是回退。**
void main() {
  const boundaryKey = ValueKey('sparkline');
  // 取整好算：宽 90 时 10 个点的间距正好是 10 像素，峰值落在整像素上。
  const size = Size(90, 100);

  /// 把一条波动线画出来，返回一个「取某个像素」的函数。
  ///
  /// 底色铺纯黑、线用纯白，这样某点的灰度值就直接等于「那里盖了多少不透明度」，
  /// 省掉一层混色换算。
  Future<int Function(int x, int y)> shoot(
    WidgetTester tester,
    List<double> values, {
    Color color = const Color(0xFFFFFFFF),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: ColoredBox(
            color: const Color(0xFF000000),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: SpeedSparkline(values: values, color: color),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary =
        tester.renderObject(find.byKey(boundaryKey)) as RenderRepaintBoundary;
    late ByteData data;
    // toImage / toByteData 由引擎线程完成，必须放进 runAsync，
    // 否则测试的假异步时钟等不到结果。
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      image.dispose();
    });

    final width = size.width.round();
    return (int x, int y) {
      final offset = (y * width + x) * 4;
      // 纯白线画在纯黑底上，三个通道相同，取一个就够。
      return data.getUint8(offset);
    };
  }

  /// 某一列里最上面那个「亮起来」的像素的 y。没有就返回 [size.height]。
  int topOf(int Function(int, int) pixel, int x) {
    for (var y = 0; y < size.height; y++) {
      if (pixel(x, y) > 8) {
        return y;
      }
    }
    return size.height.round();
  }

  testWidgets('只有渐变填充，没有描边', (tester) async {
    // 中间挖一个到半高的谷：曲线在那里正好穿过画布中线。
    // 有描边的话，那条 2 像素的实色线会比它下面的填充亮出一大截。
    final pixel = await shoot(tester, const [
      1, 1, 1, 1, 0.5, 1, 1, 1, 1, 1,
    ]);

    const x = 40; // 第 4 个点（谷底），间距 10。
    final edge = topOf(pixel, x);
    // 谷底 = 0.5 的值 × 70% 封顶 = 距底 35% → y≈65。
    //
    // 这里写死 65 而不是引用代码里的封顶常量：引用常量的话，把封顶改成别的值
    // 两边一起变，这条断言就永远是绿的（本项目已经栽过一次「拿模型比模型」）。
    expect(edge, inInclusiveRange(60, 70));

    // 判据一：**沿着这一列往下走，亮度只能一路变暗**。
    //
    // 纯渐变填充天然满足：越往下 alpha 越小。描边则会在曲线上压一条实色带，
    // 于是「边缘 → 描边中心」这一段是**变亮**的。
    //
    // 起点跳过边缘那两格：那两格是抗锯齿的过渡，本来就在爬坡。
    //
    // 这一条是被变异测试逼出来的：最早写的是「取边缘下一格和再下四格比差值」，
    // 加上 2px 描边之后这两个采样点正好**一个在描边上沿、一个在描边下沿**
    // （实测 47:99 / 51:99），差值 0，测试照绿——典型的「看着在守、其实不红」。
    for (var y = edge + 3; y < size.height; y++) {
      expect(
        pixel(x, y),
        lessThanOrEqualTo(pixel(x, y - 1) + 2),
        reason: 'y=$y 比上一格还亮（${pixel(x, y)} > ${pixel(x, y - 1)}），说明画了描边',
      );
    }

    // 判据二：整张图里最亮的一点也不能超过渐变顶端的 0.8（≈204）。
    // 描边是按基色原样画的（255），一定会捅破这条线。
    var brightest = 0;
    for (var px = 0; px < size.width; px++) {
      for (var py = 0; py < size.height; py++) {
        if (pixel(px, py) > brightest) {
          brightest = pixel(px, py);
        }
      }
    }
    expect(brightest, lessThan(215), reason: '出现了比 0.8 不透明度更实的像素：$brightest');
  });

  testWidgets('渐变上浓下透', (tester) async {
    // 全部相等 → 归一化后是一条平线。**它不在顶边而在 y≈30**：山顶封在
    // 70% 高度，所以满值那条线距顶 30%。取样点必须落在这条线**下面**，
    // 落在上面量到的是空白。
    final pixel = await shoot(tester, List<double>.filled(10, 5));

    final top = pixel(45, 32);
    final middle = pixel(45, 60);
    final bottom = pixel(45, 97);

    // **渐变铺的是整张画布，不是曲线到底边那一段**（和桌面端一致：它的
    // `createLinearGradient` 也是按图表区域算，不按曲线算）。所以透明度在
    // y 上是线性的 `0.8 × (1 - y/高)`，而不是「曲线正下方就是 0.8」。
    //
    // 山顶封在 70% 之后，画布最上面 30% 是空的，**0.8 那个最浓的点已经量不到了**。
    // 这里改成验算那条线性斜坡本身：y=32 处应为 0.8×(1-0.32)×255 ≈ 139。
    expect(top, inInclusiveRange(125, 155), reason: '渐变斜坡对不上：$top');
    expect(middle, lessThan(top));
    expect(bottom, lessThan(middle));
    expect(bottom, lessThan(20), reason: '底端没有透到底');
  });

  testWidgets('固定十个点：只画一个尖峰时，峰顶落在第 5/9 处', (tester) async {
    final values = List<double>.filled(10, 0);
    values[5] = 1;
    final pixel = await shoot(tester, values);

    var peakX = 0;
    var peakY = size.height.round();
    for (var x = 0; x < size.width; x++) {
      final y = topOf(pixel, x);
      if (y < peakY) {
        peakY = y;
        peakX = x;
      }
    }

    // 10 个点均分 90 像素 → 间距 10，第 5 个点在 x=50。
    // 换成 8 个点会跑到 x≈64，换成 12 个点会跑到 x≈41，差得一眼可见。
    expect(peakX, inInclusiveRange(48, 52), reason: '峰顶在 x=$peakX，不是十等分');
    // **山顶封在 70% 高度**，所以峰顶落在距顶 30% 处，而不是顶边。
    // 用户原话是山顶顶到卡片上边缘、从电源按钮背后穿过去，太吵。
    expect(
      peakY,
      inInclusiveRange(25, 35),
      reason: '峰顶在 y=$peakY，不在 70% 封顶该有的位置',
    );
  });

  testWidgets('多于十个采样时只取末尾十个', (tester) async {
    // 前面四个是天文数字。如果它们参与了归一化，后面那个尖峰会被压成一条平线。
    final values = <double>[1e9, 1e9, 1e9, 1e9, ...List<double>.filled(10, 0)];
    values[4 + 5] = 1;
    final pixel = await shoot(tester, values);

    var peakY = size.height.round();
    var peakX = 0;
    for (var x = 0; x < size.width; x++) {
      final y = topOf(pixel, x);
      if (y < peakY) {
        peakY = y;
        peakX = x;
      }
    }

    expect(
      peakY,
      inInclusiveRange(25, 35),
      reason: '尖峰被更早的采样压平了，说明窗口没截到十个',
    );
    expect(peakX, inInclusiveRange(48, 52));
  });

  test('不足十个采样时在左边补零', () {
    // 桌面端是 shift + push，新数据永远在右端。
    expect(sparklineWindow([1, 2, 3]), [0, 0, 0, 0, 0, 0, 0, 1, 2, 3]);
    expect(sparklineWindow(const []), List<double>.filled(10, 0));
    expect(
      sparklineWindow(List<double>.generate(14, (i) => i.toDouble())),
      [4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    );
  });

  testWidgets('全零时什么都不画', (tester) async {
    final pixel = await shoot(tester, List<double>.filled(10, 0));
    for (var x = 0; x < size.width; x += 9) {
      expect(topOf(pixel, x), size.height.round(), reason: 'x=$x 处画了东西');
    }
  });

  group('新数据按采样节拍插值过去，不是硬切', () {
    final before = List<double>.filled(10, 0)..[1] = 1;
    final after = List<double>.filled(10, 0)..[8] = 1;

    Widget build(List<double> values) => MaterialApp(
      home: SizedBox(
        width: size.width,
        height: size.height,
        child: SpeedSparkline(values: values, color: const Color(0xFFFFFFFF)),
      ),
    );

    List<double> paintedValues(WidgetTester tester) {
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(SpeedSparkline),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter
              as SpeedSparklinePainter;
      return painter.values;
    }

    Future<void> setUpView(WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('刚换数据的那一帧画的还是旧形状', (tester) async {
      await setUpView(tester);
      await tester.pumpWidget(build(before));
      await tester.pump();
      await tester.pumpWidget(build(after));

      // **不补 pump**：硬切的实现在这一帧就已经是新形状了，一测就分得开。
      expect(
        paintedValues(tester),
        sparklineWindow(before),
        reason: '数据一换就直接画成新形状，那就是"直接跳"',
      );
    });

    testWidgets('一个采样间隔之后到达新形状', (tester) async {
      await setUpView(tester);
      await tester.pumpWidget(build(before));
      await tester.pump();
      await tester.pumpWidget(build(after));
      await tester.pump(kTrafficSampleInterval);

      // 时长正好等于内核推数据的间隔（`hub/route/server.go:384` 一秒一发），
      // 所以一段动画正好接上下一段，中间没有停顿。
      expect(paintedValues(tester), sparklineWindow(after));
    });

    testWidgets('中途来了新数据，从当前形状接着走，不弹回去', (tester) async {
      await setUpView(tester);
      await tester.pumpWidget(build(before));
      await tester.pump();
      await tester.pumpWidget(build(after));
      // 走到一半。
      await tester.pump(kTrafficSampleInterval ~/ 2);
      final midway = List<double>.from(paintedValues(tester));

      // 半路又来一份新数据。
      final third = List<double>.filled(10, 0)..[4] = 1;
      await tester.pumpWidget(build(third));

      expect(
        paintedValues(tester),
        midway,
        reason: '新采样一到就弹回上一段的终点，线会抖一下',
      );
    });
  });
}
