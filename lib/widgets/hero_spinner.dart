import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

/// 桌面端那个转圈，逐项照抄。
///
/// 桌面端测延迟时用的是 HeroUI `<Button isLoading>`，它会把按钮内容换成
/// `<Spinner>`。安卓端原来用的是 FlClash 自带的 `CommonCircleLoading`——一个
/// Material 3 Expressive 的多边形变形加载器，和桌面端完全是两种东西。
///
/// HeroUI Spinner 的规格（从 `node_modules/@heroui/theme` 里读出来的，不是猜的）：
///
/// | 项 | 值 | 出处 |
/// |---|---|---|
/// | sm 档尺寸 | 20×20，边框 2px | `chunk-TRZPE5UW.mjs:26-32` |
/// | 外圈 | 实线，**只画下边框**，其余三边透明 | `:50`、`:119-125` |
/// | 内圈 | **点线**，透明度 0.75，其余同上 | `:51`、`:126-133` |
/// | 外圈动画 | `spinner-spin 0.8s ease infinite` | `chunk-KXPLHLA6.mjs:6` |
/// | 内圈动画 | `spinner-spin 0.8s linear infinite` | `chunk-KXPLHLA6.mjs:7` |
/// | 颜色 | `border-b-current`，即跟随当前文字色 | `:50-51` |
///
/// **两圈用同一个时长但不同的缓动**，这是它「两道弧互相追」那个观感的来源：
/// 一圈匀速转，另一圈忽快忽慢，于是相对位置一直在变。两圈都匀速的话它们会锁死
/// 成一个整体，看起来就只是一道弧在转。
///
/// CSS 里「圆角 50% 的方块只上色下边框」画出来正好是底部四分之一圆弧，所以这里
/// 用的是从 45° 扫到 135°（Flutter 画布 0° 在右、顺时针为正，底部是 90°）。
class HeroSpinner extends StatefulWidget {
  const HeroSpinner({super.key, this.size, this.strokeWidth, this.color});

  /// 父约束无界时用的尺寸。取值与被它替换掉的 `CommonCircleLoading` 一致，
  /// 这样那些靠默认尺寸撑起来的调用点换过来时观感不变。
  static const double defaultDimension = 48;

  /// 直径。不给就撑满父约束。
  final double? size;

  /// 描边粗细。不给就按桌面端 sm 档的比例（20 : 2）随直径缩放。
  final double? strokeWidth;

  /// 不给就取当前文字色，对应桌面端的 `border-b-current`。
  final Color? color;

  @override
  State<HeroSpinner> createState() => _HeroSpinnerState();
}

class _HeroSpinnerState extends State<HeroSpinner>
    with SingleTickerProviderStateMixin {
  /// 桌面端两圈的周期都是 0.8s，只是缓动不同。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ??
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
    final spinner = AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return CustomPaint(
          painter: _HeroSpinnerPainter(
            // CSS 的 `ease` 就是 cubic-bezier(0.25, 0.1, 0.25, 1)，
            // Flutter 里同名的 Curves.ease 是同一条曲线。
            easeTurns: Curves.ease.transform(_controller.value),
            linearTurns: _controller.value,
            color: color,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
    final size = widget.size;
    if (size != null) {
      return SizedBox(width: size, height: size, child: spinner);
    }
    // 没给尺寸时撑满父约束；父约束是无界的（比如直接放进 Center）就退回默认值。
    //
    // **这一步不能省**：`CustomPaint` 不带 child 又拿到无界约束时，尺寸会退化成
    // 零——画出来什么都没有。被替换掉的 `CommonCircleLoading` 自带 48 的默认
    // 尺寸，好几个调用点（如 `views/access.dart` 的 `Center(child: ...)`）正是
    // 靠它撑起来的，不补这一层换过去就会整个消失。
    return LayoutBuilder(
      builder: (_, constraints) {
        return SizedBox(
          width: constraints.hasBoundedWidth
              ? constraints.maxWidth
              : HeroSpinner.defaultDimension,
          height: constraints.hasBoundedHeight
              ? constraints.maxHeight
              : HeroSpinner.defaultDimension,
          child: spinner,
        );
      },
    );
  }
}

class _HeroSpinnerPainter extends CustomPainter {
  const _HeroSpinnerPainter({
    required this.easeTurns,
    required this.linearTurns,
    required this.color,
    this.strokeWidth,
  });

  /// 外圈转过的圈数（0~1），走 ease。
  final double easeTurns;

  /// 内圈转过的圈数（0~1），走匀速。
  final double linearTurns;

  final Color color;
  final double? strokeWidth;

  /// 桌面端 sm 档是 20 的直径配 2 的边框。
  static const _strokeRatio = 2 / 20;

  /// 底部四分之一圆弧：从 45° 到 135°。
  static const _startAngle = math.pi / 4;
  static const _sweepAngle = math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    if (diameter <= 0) {
      return;
    }
    final stroke = strokeWidth ?? diameter * _strokeRatio;
    // 描边是画在半径上居中的，所以半径要往里收半个描边，否则会溢出边界。
    final radius = (diameter - stroke) / 2;
    if (radius <= 0) {
      return;
    }
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── 外圈：实线 ──────────────────────────────────────────────────
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(easeTurns * 2 * math.pi);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      rect,
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color,
    );
    canvas.restore();

    // ── 内圈：点线 + 0.75 透明度 ────────────────────────────────────
    //
    // CSS 的 `border-dotted` 在 2px 边框下是「直径 2px 的圆点、间隔 2px」。
    // 这里按同一比例沿弧线摆圆点：点距 = 2 × 描边宽。
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(linearTurns * 2 * math.pi);
    canvas.translate(-center.dx, -center.dy);
    final dotPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: color.a * 0.75);
    final arcLength = radius * _sweepAngle;
    final pitch = stroke * 2;
    final count = math.max(2, (arcLength / pitch).round());
    final points = <Offset>[
      for (var i = 0; i <= count; i++)
        Offset(
          center.dx + radius * math.cos(_startAngle + _sweepAngle * i / count),
          center.dy + radius * math.sin(_startAngle + _sweepAngle * i / count),
        ),
    ];
    // 零长度的线段配圆头 = 一个圆点，这是画一串等距圆点最省的画法。
    canvas.drawPoints(PointMode.points, points, dotPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroSpinnerPainter oldDelegate) =>
      oldDelegate.easeTurns != easeTurns ||
      oldDelegate.linearTurns != linearTurns ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
