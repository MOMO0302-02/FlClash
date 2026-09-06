import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// 全应用统一的动效取值。
///
/// **为什么要集中定义**：动效散在各处自己写时长和曲线，做出来的东西会互相打架——
/// 这里 200 毫秒线性、那里 350 毫秒弹簧，观感就是「东一榔头西一棒子」。一套值管
/// 全场，才谈得上「这个 app 的手感」。
///
/// 取值向 macOS / iOS 看齐，两条原则：
/// * **由用户操作直接引起的变化用弹簧**（点、拖、切换）——有惯性和回弹才像在动
///   实物；缓动曲线走完就停，观感是「被程序改了一下」。
/// * **不是用户直接引起的变化用缓动**（数据刷新、页面切换），弹簧会显得聒噪。
class Motion {
  const Motion._();

  // ── 时长 ────────────────────────────────────────────────────────
  /// 按下 / 松开这类即时反馈。再长就会觉得「按下去黏手」。
  static const press = Duration(milliseconds: 120);

  /// 颜色、透明度这类属性变化。
  static const quick = Duration(milliseconds: 180);

  /// 常规的出现 / 消失。
  static const normal = Duration(milliseconds: 260);

  /// 页面级、大块内容的变化。
  static const slow = Duration(milliseconds: 380);

  /// 列表逐项入场时，相邻两项之间的间隔。
  ///
  /// 太长会让长列表看起来「一条条慢慢爬」，太短就等于没有错开。
  static const stagger = Duration(milliseconds: 28);

  /// 逐项入场最多错开几项。
  ///
  /// 不设上限的话，第 50 项要等 1.4 秒才出现——用户只会觉得卡。
  static const maxStaggerCount = 8;

  // ── 曲线 ────────────────────────────────────────────────────────
  /// 出现：先快后慢，东西「落」到位。
  static const enter = Curves.easeOutCubic;

  /// 消失：先慢后快，东西「抽」走。
  static const exit = Curves.easeInCubic;

  /// 位置和尺寸的过渡。
  static const move = Curves.easeInOutCubic;

  // ── 弹簧 ────────────────────────────────────────────────────────
  /// 标准弹簧：阻尼比约 0.67，会有一点点过冲再稳住。
  ///
  /// 完全不过冲（阻尼比 1）看起来还是像缓动曲线；过冲太多显得廉价。
  static const spring = SpringDescription(mass: 1, stiffness: 380, damping: 26);

  /// 更紧的弹簧，给小尺寸元素用（按钮、图标）。大元素用这个会显得急躁。
  static const tightSpring = SpringDescription(
    mass: 1,
    stiffness: 600,
    damping: 32,
  );

  /// 按弹簧跑一个 0 → 1 的模拟。
  static SpringSimulation simulate({
    SpringDescription description = spring,
    double velocity = 0,
  }) {
    return SpringSimulation(description, 0, 1, velocity);
  }
}

/// 按下时轻微缩小的包装。
///
/// 这是**整个 app 里性价比最高的一处动效**：几乎每个可点的东西都会经过它，而
/// 「按下去有回应」是「这东西是活的」最直接的证据。Material 的水波纹在深色底上
/// 几乎看不见，所以原来点什么都像没反应。
///
/// 缩放幅度刻意很小（默认 3%）：大了会像玩具，小到「说不清哪里变了但感觉跟手」
/// 才是对的。
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.press,
    reverseDuration: Motion.normal,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (!widget.enabled) {
      return;
    }
    // 松手用弹簧弹回去，按下用短促的缓动——按下要跟手，回弹才需要惯性。
    if (pressed) {
      _controller.forward();
    } else {
      _controller.animateWith(
        SpringSimulation(Motion.tightSpring, _controller.value, 0, 0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) {
          return Transform.scale(
            scale: 1 - (1 - widget.scale) * _controller.value.clamp(0.0, 1.0),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 只「观察」按压来做缩放反馈，**不接管点击**。
///
/// 和 [PressableScale] 的区别：那个用 `GestureDetector` 自己处理点击，适合本来
/// 就没有点击逻辑的东西；这个用 `Listener`，指针事件照常往下传，所以卡片自己的
/// 点击、长按，以及卡片**里面**的开关和图标按钮全都不受影响。
///
/// 给 `CommonCard` 用的就是这一个——卡片里经常还装着别的可点控件，用
/// `GestureDetector` 或 `IgnorePointer` 会把它们一起废掉。
class PressFeedback extends StatefulWidget {
  const PressFeedback({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.press,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _release() {
    if (!widget.enabled) {
      return;
    }
    // 松手用弹簧弹回去，按下用短促的缓动——按下要跟手，回弹才需要惯性。
    _controller.animateWith(
      SpringSimulation(Motion.tightSpring, _controller.value, 0, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (widget.enabled) {
          _controller.forward();
        }
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) {
          return Transform.scale(
            scale: 1 - (1 - widget.scale) * _controller.value.clamp(0.0, 1.0),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 数字变化时滚动过去，而不是直接跳。
///
/// 流量、延迟、连接数这些数字每秒都在变。直接换数字时整块会「闪」一下，眼睛会
/// 被迫去追；滚动过去反而不抢注意力。
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.builder,
    this.duration = Motion.normal,
  });

  final num value;
  final Duration duration;

  /// 拿到中间值自己决定怎么画（要不要格式化成流量单位、要不要带符号）。
  final Widget Function(BuildContext context, num value) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      curve: Motion.move,
      builder: (context, value, _) => builder(context, value),
    );
  }
}

/// 列表逐项入场：淡入 + 从下方微微上移。
///
/// [index] 决定错开多久。**必须传真实的下标**，否则所有项同时出现，等于没做。
/// 超过 [Motion.maxStaggerCount] 之后不再继续错开——长列表里第 50 项要是还等着
/// 排队，用户只会觉得卡。
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.offset = 12,
    this.animate = true,
  });

  final int index;
  final Widget child;

  /// 入场时从下方多远处上来。
  final double offset;

  /// 这一次要不要播。
  ///
  /// 给「只在首次加载时逐项入场」用：列表每次刷新都重播会闪成一片。
  ///
  /// **只在第一次挂载时读一次，之后翻转不生效**——播到一半开关一翻会当场跳一下，
  /// 比不做还糟。所以调用方不必担心传进来的值每帧在变。
  final bool animate;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.normal,
  );

  /// 只在第一次挂载时读一次，见 [StaggeredEntrance.animate] 的说明。
  late final bool _animate = widget.animate;

  /// 错开的那段时间在曲线里占的比例。
  late final double _delayFraction = _computeDelayFraction();

  double _computeDelayFraction() {
    final steps = widget.index.clamp(0, Motion.maxStaggerCount);
    final delay = Motion.stagger * steps;
    final total = delay + Motion.normal;
    return delay.inMicroseconds / total.inMicroseconds;
  }

  @override
  void initState() {
    super.initState();
    if (!_animate) {
      return;
    }
    // **用曲线里的 Interval 做延迟，不用 `Future.delayed`。**
    //
    // 定时器有两个毛病：组件在延迟期间被销毁时，那个 Future 还挂着（要靠
    // mounted 兜）；更要命的是**测试里会留下未清理的定时器直接判失败**——
    // 第一版就是这么写的，一次性把好几个页面的冒烟测试搞红了。
    // 把总时长拉长成「延迟 + 动画」，前半段曲线值恒为 0，效果一样且没有副作用。
    final steps = widget.index.clamp(0, Motion.maxStaggerCount);
    _controller.duration = Motion.stagger * steps + Motion.normal;
    _controller.forward();
  }

  /// **必须是字段，不能在 `build` 里现建。**
  ///
  /// `CurvedAnimation` 会往父动画上挂一个状态监听器，每建一个就多一个、且不会
  /// 自己摘掉。列表每秒刷新一次的话，每个可见条目的监听器会一路累积到条目销毁。
  /// Flutter 官方文档对这个类专门写了这条警告。
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: Interval(_delayFraction, 1, curve: Motion.enter),
  );

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) {
      return widget.child;
    }
    final curved = _curved;
    return AnimatedBuilder(
      animation: curved,
      builder: (_, child) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - curved.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
