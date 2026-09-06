import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// 手指正在把某块磁贴拖成多大。由编辑层往下传，[AnimatedCellBox] 读它。
///
/// 拖动过程中磁贴要**跟手**——尺寸实时跟着手指走，而不是等越过临界点才跳一下。
/// 但「手指拖到哪」这个信息只有编辑层的手柄知道，真正画尺寸的是下面的
/// [AnimatedCellBox]，中间隔着好几层，用 InheritedWidget 直接递下去最省事。
class CellResize extends InheritedWidget {
  const CellResize({super.key, required this.liveSize, required super.child});

  /// 手指当前拖出来的尺寸。为空表示没有人在拖。
  final Size? liveSize;

  static Size? liveSizeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CellResize>()?.liveSize;
  }

  @override
  bool updateShouldNotify(CellResize oldWidget) =>
      liveSize != oldWidget.liveSize;
}

/// 让网格里的磁贴改尺寸时**跟手 + 弹簧回弹**，而不是瞬间跳过去。
///
/// 网格给子项的是硬约束（tight），子项自己决定不了大小，所以用不了 `AnimatedSize`。
/// 这里的做法是：外壳照旧老老实实占住网格分配的格子（相邻磁贴该怎么排就怎么排），
/// 内部用 [OverflowBox] 把内容按另一个尺寸画出来。那个尺寸有两个来源：
///
/// * 拖动中——直接用手指的尺寸（[CellResize]），一比一跟手，不加任何动画；
/// * 松手后——用弹簧从手指停下的尺寸弹回网格给的格子尺寸，会有轻微过冲。
///
/// 用弹簧而不是缓动曲线：匀速曲线走完就停，观感是「生硬地变了一下」；弹簧有惯性
/// 和回弹，才是 macOS / iOS 小组件那种手感。
///
/// 故意不加 `ClipRect`：收小的那一下内容会短暂越出格子，但那正是「这块正在收回去」
/// 的观感；裁掉的话看起来像被切了一刀。
///
/// **尺寸变化必须在 [LayoutBuilder] 里判断，不能靠 `build` 里挂 post-frame 回调。**
/// 网格改尺寸时子项的 widget 实例没变，Flutter 会跳过它的重建，`build` 根本不会
/// 再跑一次——第一版就是这么写的，结果动画一次都没触发过，看起来就是瞬间跳变。
/// 而 `LayoutBuilder` 的 builder 在约束变化时一定会重跑。
class AnimatedCellBox extends StatefulWidget {
  const AnimatedCellBox({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedCellBox> createState() => _AnimatedCellBoxState();
}

class _AnimatedCellBoxState extends State<AnimatedCellBox>
    with SingleTickerProviderStateMixin {
  /// 弹簧的取值：阻尼比约 0.67，欠阻尼，会有一点点过冲再稳住。
  /// 完全不过冲（阻尼比 1）看起来还是像缓动曲线，过冲太多又会显得廉价。
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 26,
  );

  /// 用 unbounded：弹簧过冲时取值会短暂超过 1，普通控制器会把它夹回去，
  /// 过冲就没了。
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );

  /// 上一次网格给的尺寸。为空表示还没量过——第一帧不做动画，否则每次进页面
  /// 都会看到所有磁贴一起长出来。
  Size? _lastSize;

  /// 本次动画的起点尺寸。
  Size? _fromSize;

  /// 手指最后停在的尺寸，松手后从这里往格子尺寸弹。
  Size? _lastLive;

  /// 上一帧是不是还在拖。
  bool _wasLive = false;

  /// 已经排了「下一帧启动动画」的任务，避免同一次尺寸变化排两遍。
  bool _scheduled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _springFrom(Size from) {
    // 布局过程中不能启动动画（会触发重入的 setState），排到下一帧。
    _fromSize = from;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) {
        return;
      }
      _controller.value = 0;
      _controller.animateWith(SpringSimulation(_spring, 0, 1, 0));
    });
  }

  Widget _sized(Size size, Widget child) {
    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: 0,
      maxWidth: double.infinity,
      minHeight: 0,
      maxHeight: double.infinity,
      child: SizedBox.fromSize(size: size, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 高度没有上界时（网格按内容撑高的那条路径）量不出目标尺寸，不做动画。
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return widget.child;
        }
        final target = constraints.biggest;
        final live = CellResize.liveSizeOf(context);

        if (live != null) {
          // 拖动中：一比一跟手，不插动画。同时把格子尺寸记下来，松手那一帧
          // 才不会因为「约束变了」又触发一次多余的动画。
          _lastLive = live;
          _wasLive = true;
          _lastSize = target;
          _controller.stop();
          return _sized(live, widget.child);
        }

        if (_wasLive) {
          // 刚松手：从手指停下的尺寸弹回格子尺寸。
          _wasLive = false;
          _springFrom(_lastLive ?? target);
        } else if (_lastSize != null && _lastSize != target && !_scheduled) {
          // 没人拖，但格子变了（比如别的磁贴改尺寸挤到了自己）。
          _springFrom(_lastSize!);
        }
        _lastSize = target;

        return AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            final from = _fromSize;
            // _scheduled 期间控制器还停在上一轮的终点，直接读它会先闪一下新尺寸。
            // 这一帧按起点画，下一帧动画才真正开跑。
            if (from == null || (!_scheduled && !_controller.isAnimating)) {
              return child!;
            }
            final t = _scheduled ? 0.0 : _controller.value;
            final size = Size.lerp(from, target, t)!;
            return _sized(size, child!);
          },
          child: widget.child,
        );
      },
    );
  }
}
