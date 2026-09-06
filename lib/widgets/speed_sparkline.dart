import 'dart:math' as math;

import 'package:clash_party/common/constant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 桌面端「连接」卡片背后那条波动线的移植。
///
/// 参照物是 clash-party 桌面端的 `components/sider/conn-card.tsx`，那是一张
/// Chart.js 的 `<Line>`。移植时逐项对齐了它的取值，理由都写在各自的常量上——
/// 这条线的观感几乎全部由这几个数决定，随手改一个就不是那个东西了。
///
/// **它是背景，不是图表。** 没有坐标轴、没有圆点、没有描边、不响应指针，
/// 唯一的作用是让「现在有没有在跑流量」在余光里也能看见。

/// 画几个点。桌面端 `conn-card.tsx:57` 是 `Array(10).fill(0)`，每来一次流量
/// 事件 `shift()` 掉最老的、`push` 新的——所以永远是最近 10 秒的窗口。
///
/// 点数直接决定观感：点太多会变成一片毛刺，太少又看不出趋势。
const int sparklinePointCount = 10;

/// 曲线张力。桌面端 `conn-card.tsx:94` `tension: 0.4`。
///
/// Chart.js 的 tension 不是「圆角半径」那种东西，它是三次贝塞尔控制点相对
/// 相邻两点连线的比例，见下面 [_splineCurve] 的注释。
const double sparklineTension = 0.4;

/// 纵向渐变顶端的不透明度。桌面端 `conn-card.tsx:74-90`：
/// 顶部 `rgba(base, 0.8)`、底部 `rgba(base, 0)`。
const double sparklineTopOpacity = 0.8;

/// 取最近 [sparklinePointCount] 个采样；不足时**在左边补 0**。
///
/// 左补而不是右补：桌面端是 `shift()` + `push()`，新数据永远在右端。刚启动只有
/// 三个采样时，应该是「左边一片空、右边刚冒出三个点」，而不是三个点铺满整条。
List<double> sparklineWindow(List<double> values) {
  final window = List<double>.filled(sparklinePointCount, 0);
  final take = math.min(sparklinePointCount, values.length);
  for (var i = 0; i < take; i++) {
    window[sparklinePointCount - take + i] = values[values.length - take + i];
  }
  return window;
}

/// 速率波动线。[values] 传原始采样（长度随意），内部按 [sparklineWindow] 取窗口。
///
/// [color] 是渐变的基色，它自身的 alpha 会和 [sparklineTopOpacity] 相乘——
/// 传一个不透明的颜色就得到和桌面端逐字节相同的 0.8 → 0；传一个半透明的颜色
/// 就整体压暗，用于把这条线压到内容后面去。
class SpeedSparkline extends StatefulWidget {
  const SpeedSparkline({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  State<SpeedSparkline> createState() => _SpeedSparklineState();
}

class _SpeedSparklineState extends State<SpeedSparkline>
    with SingleTickerProviderStateMixin {
  /// 上一段的形状与这一段的形状，按 [_controller] 的进度在两者之间插值。
  late List<double> _from = sparklineWindow(widget.values);
  late List<double> _to = _from;

  /// **时长取采样间隔本身，而且线性推进。**
  ///
  /// 原来这个组件根本不动，数据一换就硬切，用户看到的是"直接跳"。而详情页那两条
  /// 用的是 260 毫秒——跑完之后干等 740 毫秒，变成"抖一下停一下"。
  ///
  /// 内核是 `hub/route/server.go:384` 的 `time.NewTicker(time.Second)`，一秒一发。
  /// 时长正好等于间隔，一段动画接上下一段，中间没有停顿，看上去就是持续在流动。
  ///
  /// 不加缓动：缓动是给"一次性的、有起止的"变化用的；这是连续数据流，每段都
  /// ease-in-out 的话每秒能看到一次起步和刹车，反而更颠。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kTrafficSampleInterval,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant SpeedSparkline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = sparklineWindow(widget.values);
    if (listEquals(next, _to)) {
      return;
    }
    // 从**当前插值出来的形状**接着走，不是从上一段的终点。新采样在上一段还没跑完
    // 时到达时，线不会先弹回去再重新出发。
    _from = _lerpWindow(_controller.value);
    _to = next;
    _controller.forward(from: 0);
  }

  List<double> _lerpWindow(double t) {
    return [
      for (var i = 0; i < sparklinePointCount; i++)
        _from[i] + (_to[i] - _from[i]) * t,
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 数据每秒来一次，而它外面那张卡片（大字、时长、按钮）一秒钟都不用重画。
    // 不隔开的话每秒会把整块状态总览一起重绘一遍。
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller.view,
        builder: (_, _) {
          return CustomPaint(
            painter: SpeedSparklinePainter(
              values: _lerpWindow(_controller.value),
              color: widget.color,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class SpeedSparklinePainter extends CustomPainter {
  SpeedSparklinePainter({required this.values, required this.color});

  /// 长度恒为 [sparklinePointCount]，由 [sparklineWindow] 保证。
  final List<double> values;
  final Color color;

  /// 山顶最高只到卡片高度的这个比例。
  ///
  /// 归一化是按窗口内峰值来的，所以**只要有流量就必然有一座满高的山**。画到 1.0
  /// 时山顶会顶到卡片上边缘、从那个电源圆按钮背后穿过去——按钮不透明所以不挡
  /// 信息，但看着吵。留出三成余量之后波形退回「背景装饰」的位置。
  static const _peakHeight = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }

    // 以 0 为基线、按窗口内峰值归一化。
    //
    // 这里**没有**照抄 Chart.js 的默认刻度（它的 y 轴下界取的是数据最小值，
    // 于是「稳定 5MB/s」会被画成一条贴在中间的平线，而「全 0」会因为 min==max
    // 被撑成 [-1, 1] 变成半张卡的实心色块）。背景装饰要的是「有流量就有山、
    // 没流量就干净」，所以基线钉死在 0。
    var peak = 0.0;
    for (final value in values) {
      if (value > peak) {
        peak = value;
      }
    }
    if (peak <= 0) {
      // 全 0：曲线就贴在底边上，填充高度为零，画了也看不见。直接不画。
      return;
    }

    final step = size.width / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          i * step,
          size.height * (1 - (values[i] / peak).clamp(0.0, 1.0) * _peakHeight),
        ),
    ];

    final path = _curve(points, size);

    // 收口到底边，形成一块可填充的封闭区域。桌面端是 `fill: true`（默认填到
    // 刻度原点），我们的原点就在底边，等价。
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: color.a * sparklineTopOpacity),
            color.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );

    // **到此为止，不描边。**
    // 桌面端 `borderColor: 'transparent'` + `borderWidth: 0`（`:91`、`:118`），
    // 看到的只有渐变的上沿。加一条 2px 的实色描边就会立刻变成「一张图表」，
    // 抢走大字的注意力——用户抱怨的正是这个。
  }

  /// 按 Chart.js 的 `splineCurve` 逐点算控制点，再连成三次贝塞尔。
  ///
  /// 之所以不用 Catmull-Rom：两者形状接近但不相同（均匀 Catmull-Rom 的控制点
  /// 偏移是 1/6 ≈ 0.167，而 tension 0.4 是 0.2），既然要求「学桌面端那条线」，
  /// 就直接照它的算法算，免得再去论证「差不多」。
  Path _curve(List<Offset> points, Size size) {
    final length = points.length;
    // cpIn[i]：进入第 i 个点的控制点；cpOut[i]：离开第 i 个点的控制点。
    final cpIn = List<Offset>.filled(length, Offset.zero);
    final cpOut = List<Offset>.filled(length, Offset.zero);

    // 首点的「上一个点」取它自己，末点的「下一个点」取它自己——这就是 Chart.js
    // `_updateBezierControlPoints` 里 `prev = points[0]` 与
    // `points[Math.min(i + 1, ilen - 1)]` 的效果：端点只有一侧有邻居，
    // 另一侧的控制点自然塌回端点本身，曲线不会在两头甩出去。
    var previous = points.first;
    for (var i = 0; i < length; i++) {
      final current = points[i];
      final next = points[math.min(i + 1, length - 1)];
      final (cp1, cp2) = _splineCurve(previous, current, next);
      cpIn[i] = _cap(cp1, size);
      cpOut[i] = _cap(cp2, size);
      previous = current;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < length - 1; i++) {
      path.cubicTo(
        cpOut[i].dx,
        cpOut[i].dy,
        cpIn[i + 1].dx,
        cpIn[i + 1].dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }
    return path;
  }

  /// Chart.js `helpers.curve.js` 的 `splineCurve`。
  ///
  /// 控制点方向取「前一个点到后一个点」这条弦，长度按两段的距离比分配，
  /// 再乘以张力：
  ///
  /// ```
  /// s01 = d01 / (d01 + d12)      s12 = d12 / (d01 + d12)
  /// 进 = 当前 - tension * s01 * (后 - 前)
  /// 出 = 当前 + tension * s12 * (后 - 前)
  /// ```
  (Offset, Offset) _splineCurve(Offset previous, Offset current, Offset next) {
    final d01 = (current - previous).distance;
    final d12 = (next - current).distance;
    final total = d01 + d12;
    if (total == 0) {
      return (current, current);
    }
    final chord = next - previous;
    return (
      current - chord * (sparklineTension * (d01 / total)),
      current + chord * (sparklineTension * (d12 / total)),
    );
  }

  /// 把控制点夹回画布内。
  ///
  /// 对应 Chart.js 的 `capBezierPoints`：山谷挨着山峰时算出来的控制点会冲出
  /// 上下边界，导致曲线在边缘鼓一个包出去，填充跟着溢出。
  Offset _cap(Offset point, Size size) {
    return Offset(
      point.dx.clamp(0.0, size.width),
      point.dy.clamp(0.0, size.height),
    );
  }

  @override
  bool shouldRepaint(covariant SpeedSparklinePainter oldDelegate) {
    return oldDelegate.color != color ||
        !listEquals(oldDelegate.values, values);
  }
}
