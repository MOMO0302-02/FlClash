import 'dart:async';
import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/widgets/activate_box.dart';
import 'package:clash_party/widgets/animated_cell_box.dart';
import 'package:clash_party/widgets/card.dart';
import 'package:clash_party/widgets/grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class SuperGrid extends StatefulWidget {
  final List<GridItem> children;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final int crossAxisCount;
  final VoidCallback? onUpdate;

  /// 一行有多高。留空时网格拿列宽当行高。
  final double? mainAxisExtent;

  /// 磁贴能被拖到的最小 / 最大尺寸。拖动时磁贴一比一跟手，但要在这个范围内
  /// 收住，否则手一甩就能把卡片拉到整屏那么大。留空则不跟手。
  final Size? minCellSize;
  final Size? maxCellSize;

  /// 第几块能删。返回 false 的那块不画删除按钮。留空表示都能删。
  final bool Function(int index)? canDelete;

  /// 拖动改尺寸。手柄画在网格自己的编辑层里，不能包在磁贴外面——包一层会改变
  /// child 的类型与布局，把网格的排版打断（实测编辑模式下整片空白）。
  ///
  /// [delta] 是本次拖动相对起点的位移（两个方向都给），[ended] 表示手指抬起。
  final void Function(int index, Offset delta, bool ended)? onResize;

  const SuperGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 1,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.mainAxisExtent,
    this.minCellSize,
    this.maxCellSize,
    this.canDelete,
    this.onUpdate,
    this.onResize,
  });

  @override
  State<SuperGrid> createState() => SuperGridState();
}

class SuperGridState extends State<SuperGrid> with TickerProviderStateMixin {
  static const _reorderDuration = Duration(milliseconds: 420);
  static const _shakeDuration = Duration(milliseconds: 480);
  static const _reorderCurve = Cubic(0.22, 0.72, 0.24, 1.08);

  late final ValueNotifier<List<GridItem>> _childrenNotifier;
  List<GridItem> children = [];
  List<GridItem>? _pendingChildren;

  List<GridItem> get snapshotChildren =>
      List<GridItem>.unmodifiable(_pendingChildren ?? children);

  int get length => _childrenNotifier.value.length;
  List<int> _tempIndexList = [];
  List<BuildContext?> _itemContexts = [];
  Size _containerSize = Size.zero;
  int _targetIndex = -1;
  Offset _targetOffset = Offset.zero;
  List<Size> _sizes = [];
  List<Offset> _offsets = [];
  Offset _parentOffset = Offset.zero;
  EdgeDraggingAutoScroller? _edgeDraggingAutoScroller;

  final ValueNotifier<bool> _animating = ValueNotifier(false);

  final _dragWidgetSizeNotifier = ValueNotifier(Size.zero);

  final _dragIndexNotifier = ValueNotifier(-1);

  late AnimationController _transformController;

  Future<bool> get isTransformCompleter =>
      _transformCompleter?.future ?? Future<bool>.value(true);

  Completer<bool>? _transformCompleter;

  Map<int, Animation<Offset>> _transformAnimationMap = {};

  late AnimationController _fakeDragWidgetController;
  Animation<Offset>? _fakeDragWidgetAnimation;

  late AnimationController _shakeController;
  Rect _dragRect = Rect.zero;
  Scrollable? _scrollable;
  bool _isDragging = false;

  int get crossCount => widget.crossAxisCount;

  void _stopAutoScroll() {
    _edgeDraggingAutoScroller?.stopAutoScroll();
  }

  void _handleChildrenChanged() {
    children = List<GridItem>.of(_childrenNotifier.value);
    _tempIndexList = List.generate(length, (index) => index);
    _itemContexts = List.filled(length, null);
    widget.onUpdate?.call();
  }

  void _preTransformState() {
    _sizes = _itemContexts.map((item) => item!.size!).toList();
    _parentOffset = (context.findRenderObject() as RenderBox).localToGlobal(
      Offset.zero,
    );
    _offsets = _itemContexts
        .map(
          (item) =>
              (item!.findRenderObject() as RenderBox).localToGlobal(
                Offset.zero,
              ) -
              _parentOffset,
        )
        .toList();
    _containerSize = context.size!;
  }

  void _initState() {
    _transformController.value = 0;
    _sizes = List.generate(length, (index) => Size.zero);
    _offsets = [];
    _transformAnimationMap.clear();
    _containerSize = Size.zero;
    _dragIndexNotifier.value = -1;
    _dragWidgetSizeNotifier.value = Size.zero;
    _targetOffset = Offset.zero;
    _parentOffset = Offset.zero;
    _dragRect = Rect.zero;
    _targetIndex = -1;
  }

  @override
  void initState() {
    super.initState();
    children = List<GridItem>.of(widget.children);
    _childrenNotifier = ValueNotifier(children)
      ..addListener(_handleChildrenChanged);
    _tempIndexList = List.generate(length, (index) => index);
    _itemContexts = List.filled(length, null);

    _fakeDragWidgetController = AnimationController.unbounded(vsync: this);

    _shakeController = AnimationController(
      vsync: this,
      duration: _shakeDuration,
    )..repeat();

    _transformController = AnimationController(
      vsync: this,
      duration: _reorderDuration,
    );
    _initState();
  }

  void handleAdd(GridItem gridItem) {
    _childrenNotifier.value = [..._childrenNotifier.value, gridItem];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final scrollable = context.findAncestorWidgetOfExactType<Scrollable>();
    if (scrollable == null) {
      _stopAutoScroll();
      _scrollable = null;
      _edgeDraggingAutoScroller = null;
      return;
    }
    if (_scrollable == scrollable) {
      return;
    }
    _stopAutoScroll();
    _scrollable = scrollable;
    late final EdgeDraggingAutoScroller autoScroller;
    autoScroller = EdgeDraggingAutoScroller(
      Scrollable.of(context),
      onScrollViewScrolled: () {
        if (!mounted ||
            !_isDragging ||
            !identical(_edgeDraggingAutoScroller, autoScroller)) {
          return;
        }
        autoScroller.startAutoScrollIfNecessary(_dragRect);
      },
      velocityScalar: 40,
    );
    _edgeDraggingAutoScroller = autoScroller;
  }

  Future<bool> _transform() async {
    final List<Offset> layoutOffsets = [Offset(_containerSize.width, 0)];
    final List<Offset> nextOffsets = [];

    for (final index in _tempIndexList) {
      final size = _sizes[index];
      final offset = _getNextOffset(layoutOffsets, size);
      final layoutOffset = Offset(
        min(
          offset.dx + size.width + widget.crossAxisSpacing,
          _containerSize.width,
        ),
        min(
          offset.dy + size.height + widget.mainAxisSpacing,
          _containerSize.height,
        ),
      );
      final startLayoutOffsetX = offset.dx;
      final endLayoutOffsetX = layoutOffset.dx;
      nextOffsets.add(offset);

      final startIndex = layoutOffsets.indexWhere(
        (i) => i.dx >= startLayoutOffsetX,
      );
      final endIndex = layoutOffsets.indexWhere(
        (i) => i.dx >= endLayoutOffsetX,
      );
      final endOffset = layoutOffsets[endIndex];

      if (startIndex != endIndex) {
        final startOffset = layoutOffsets[startIndex];
        if (startOffset.dx != startLayoutOffsetX) {
          layoutOffsets[startIndex] = Offset(
            startLayoutOffsetX,
            startOffset.dy,
          );
        }
      }
      if (endOffset.dx == endLayoutOffsetX) {
        layoutOffsets[endIndex] = layoutOffset;
      } else {
        layoutOffsets.insert(endIndex, layoutOffset);
      }
      layoutOffsets.removeRange(min(startIndex + 1, endIndex), endIndex);
    }

    final transformAnimationMap = <int, Animation<Offset>>{};
    final transformCurve = CurvedAnimation(
      parent: _transformController,
      curve: _reorderCurve,
    );
    for (var nextIndex = 0; nextIndex < _tempIndexList.length; nextIndex++) {
      final index = _tempIndexList[nextIndex];
      transformAnimationMap[index] = Tween<Offset>(
        begin: _transformAnimationMap[index]?.value ?? Offset.zero,
        end: nextOffsets[nextIndex] - _offsets[index],
      ).animate(transformCurve);
    }
    _transformAnimationMap = transformAnimationMap;

    if (_targetIndex != -1) {
      _targetOffset = nextOffsets[_targetIndex];
    }
    try {
      await _transformController.forward(from: 0).orCancel;
      return true;
    } on TickerCanceled {
      return false;
    }
  }

  void _handleDragStarted(int index) {
    _initState();
    _preTransformState();
    _isDragging = true;
    _dragIndexNotifier.value = index;
    _dragWidgetSizeNotifier.value = _sizes[index];
    _targetIndex = index;
    _targetOffset = _offsets[index];
    _dragRect = Rect.fromLTWH(
      _targetOffset.dx + _parentOffset.dx,
      _targetOffset.dy + _parentOffset.dy,
      _sizes[index].width,
      _sizes[index].height,
    );
  }

  Future<void> _handleDragEnd(DraggableDetails details) async {
    _isDragging = false;
    _stopAutoScroll();
    debouncer.cancel(FunctionTag.handleWill);
    final dragIndex = _dragIndexNotifier.value;
    if (_targetIndex < 0 ||
        _targetIndex >= length ||
        dragIndex < 0 ||
        dragIndex >= length) {
      _initState();
      return;
    }

    final nextChildren = List<GridItem>.of(_childrenNotifier.value);
    nextChildren.insert(_targetIndex, nextChildren.removeAt(dragIndex));
    children = nextChildren;

    const tolerance = Tolerance(distance: 0.001, velocity: 0.01);
    const spring = SpringDescription(mass: 1, stiffness: 180, damping: 18);
    final simulation = SpringSimulation(spring, 0, 1, 0, tolerance: tolerance);
    _fakeDragWidgetAnimation = Tween<Offset>(
      begin: details.offset - _parentOffset,
      end: _targetOffset,
    ).animate(_fakeDragWidgetController);
    _animating.value = true;

    final completer = Completer<bool>();
    _transformCompleter = completer;
    try {
      await _fakeDragWidgetController.animateWith(simulation).orCancel;
      if (!mounted) {
        return;
      }
      _animating.value = false;
      _fakeDragWidgetAnimation = null;
      _transformAnimationMap.clear();
      _childrenNotifier.value = nextChildren;
      _initState();
      completer.complete(true);
    } on TickerCanceled {
      if (mounted) {
        _animating.value = false;
        _fakeDragWidgetAnimation = null;
        _initState();
      }
    } finally {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      if (identical(_transformCompleter, completer)) {
        _transformCompleter = null;
      }
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) {
      return;
    }
    _dragRect = _dragRect.translate(0, details.delta.dy);
    _edgeDraggingAutoScroller?.startAutoScrollIfNecessary(_dragRect);
  }

  Future<void> _handleWill(int index) async {
    final dragIndex = _dragIndexNotifier.value;
    if (dragIndex < 0 || dragIndex >= _offsets.length) {
      return;
    }
    final targetIndex = _tempIndexList.indexWhere((i) => i == index);
    if (_targetIndex == targetIndex) {
      return;
    }
    _tempIndexList = List.generate(length, (i) {
      if (i == targetIndex) return _dragIndexNotifier.value;
      if (_targetIndex > targetIndex && i > targetIndex && i <= _targetIndex) {
        return _tempIndexList[i - 1];
      } else if (_targetIndex < targetIndex &&
          i >= _targetIndex &&
          i < targetIndex) {
        return _tempIndexList[i + 1];
      }
      return _tempIndexList[i];
    }).toList();

    _targetIndex = targetIndex;

    await _transform();
  }

  // Takes the item rather than a position: the delete animation outlives list
  // changes, so by the time it finishes the captured slot may show a
  // different card.
  /// 就地把某一项的尺寸换成 [crossAxisCellCount] 列 × [mainAxisCellCount] 行并重排。
  ///
  /// 网格在 initState 里把 children 复制进 state，之后不跟随外部变化，
  /// 所以改尺寸必须走这里，不能指望父组件重建。
  void handleResize(int index, int crossAxisCellCount, int mainAxisCellCount) {
    final current = _childrenNotifier.value;
    if (index < 0 || index >= current.length) return;
    final old = current[index];
    if (old.crossAxisCellCount == crossAxisCellCount &&
        old.mainAxisCellCount == mainAxisCellCount) {
      return;
    }
    final next = List<GridItem>.of(current);
    next[index] = GridItem(
      crossAxisCellCount: crossAxisCellCount,
      mainAxisCellCount: mainAxisCellCount,
      child: old.child,
    );
    children = next;
    _childrenNotifier.value = next;
    widget.onUpdate?.call();
  }

  Future<void> _handleDelete(GridItem target) async {
    final index = _childrenNotifier.value.indexOf(target);
    if (index == -1) {
      return;
    }
    _preTransformState();
    final indexWhere = _tempIndexList.indexWhere((i) => i == index);
    if (indexWhere == -1) {
      return;
    }
    _tempIndexList.removeAt(indexWhere);
    final nextChildren = List<GridItem>.from(_childrenNotifier.value)
      ..removeAt(index);
    _pendingChildren = nextChildren;
    final completed = await _transform();
    if (!completed || !mounted) {
      _pendingChildren = null;
      return;
    }
    _childrenNotifier.value = nextChildren;
    _pendingChildren = null;
    _initState();
  }

  Widget _buildTransform(Widget rawChild, int index) {
    return ValueListenableBuilder(
      valueListenable: _animating,
      builder: (_, animating, child) {
        if (animating && _dragIndexNotifier.value == index) {
          return _buildSizeBox(const SizedBox.shrink());
        }
        return child!;
      },
      child: AnimatedBuilder(
        builder: (_, child) {
          return Transform.translate(
            offset: _transformAnimationMap[index]?.value ?? Offset.zero,
            child: child,
          );
        },
        animation: _transformController.view,
        child: rawChild,
      ),
    );
  }

  Offset _getNextOffset(List<Offset> offsets, Size size) {
    final length = offsets.length;
    Offset nextOffset = const Offset(0, double.infinity);
    for (int i = 0; i < length; i++) {
      final offset = offsets[i];
      if (offset.dy.moreOrEqual(nextOffset.dy)) {
        continue;
      }
      double offsetX = 0;
      double span = 0;
      for (
        int j = 0;
        span < size.width &&
            j < length &&
            _containerSize.width.moreOrEqual(offsetX + size.width);
        j++
      ) {
        final tempOffset = offsets[j];
        if (offset.dy.moreOrEqual(tempOffset.dy)) {
          span = tempOffset.dx - offsetX;
          if (span.moreOrEqual(size.width)) {
            nextOffset = Offset(offsetX, offset.dy);
          }
        } else {
          offsetX = tempOffset.dx;
          span = 0;
        }
      }
    }
    return nextOffset;
  }

  Widget _buildSizeBox(Widget child) {
    return ValueListenableBuilder(
      valueListenable: _dragWidgetSizeNotifier,
      builder: (_, size, child) {
        return SizedBox.fromSize(size: size, child: child!);
      },
      child: child,
    );
  }

  Widget _buildInactivate(Widget child) {
    return ValueListenableBuilder(
      valueListenable: _animating,
      builder: (_, animating, child) {
        return animating ? ActivateBox(child: child!) : child!;
      },
      child: child,
    );
  }

  Widget _buildShake(Widget child, int index) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (_, child) {
        final phase = index * pi / 2;
        final angle = sin(_shakeController.value * 2 * pi + phase) * 0.01;
        return Transform.rotate(angle: angle, child: child!);
      },
      child: child,
    );
  }

  Widget _buildDraggable({
    required Widget childWhenDragging,
    required Widget feedback,
    required Widget item,
    required int index,
  }) {
    // Bound to this slot's item at build time: the delete animation outlives
    // list changes, and by the time it finishes this slot may show another
    // item.
    final gridItem = _childrenNotifier.value[index];
    final target = DragTarget<int>(
      builder: (_, _, _) {
        return AbsorbPointer(child: item);
      },
      onWillAcceptWithDetails: (_) {
        debouncer.call(
          FunctionTag.handleWill,
          _handleWill,
          args: [index],
          duration: commonDuration,
        );
        return false;
      },
    );
    final shakeTarget = ValueListenableBuilder(
      valueListenable: _animating,
      builder: (_, animating, child) {
        if (animating) {
          return target;
        } else {
          return child!;
        }
      },
      child: ValueListenableBuilder(
        valueListenable: _dragIndexNotifier,
        builder: (_, dragIndex, child) {
          if (dragIndex == index) {
            return child!;
          }
          return _buildShake(
            _DeletableContainer(
              deletable: widget.canDelete?.call(index) ?? true,
              onDelete: () {
                _handleDelete(gridItem);
              },
              minCellSize: widget.minCellSize,
              maxCellSize: widget.maxCellSize,
              onResize: widget.onResize == null
                  ? null
                  : (delta, ended) => widget.onResize!(index, delta, ended),
              child: child!,
            ),
            index,
          );
        },
        child: target,
      ),
    );
    void onDragStarted() {
      _handleDragStarted(index);
    }

    void onDragUpdate(DragUpdateDetails details) {
      _handleDragUpdate(details);
    }

    void onDragEnd(DraggableDetails details) {
      _handleDragEnd(details);
    }

    final draggableChild = system.isDesktop
        ? Draggable(
            childWhenDragging: childWhenDragging,
            data: index,
            feedback: feedback,
            onDragStarted: onDragStarted,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
            child: shakeTarget,
          )
        : LongPressDraggable(
            childWhenDragging: childWhenDragging,
            data: index,
            feedback: feedback,
            onDragStarted: onDragStarted,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
            child: shakeTarget,
          );
    return draggableChild;
  }

  Widget _builderItem(int index) {
    final gridItem = _childrenNotifier.value[index];
    final child = gridItem.child;
    return GridItem(
      mainAxisCellCount: gridItem.mainAxisCellCount,
      crossAxisCellCount: gridItem.crossAxisCellCount,
      child: Builder(
        builder: (context) {
          _itemContexts[index] = context;
          final childWhenDragging = ActivateBox(
            child: Opacity(
              opacity: 0.6,
              child: _buildSizeBox(CommonCard(child: child)),
            ),
          );
          final feedback = ActivateBox(
            child: _buildSizeBox(
              CommonCard(child: Material(elevation: 6, child: child)),
            ),
          );
          return _buildTransform(
            _buildDraggable(
              childWhenDragging: childWhenDragging,
              feedback: feedback,
              item: child,
              index: index,
            ),
            index,
          );
        },
      ),
    );
  }

  Widget _buildFakeTransformWidget() {
    return ValueListenableBuilder<bool>(
      valueListenable: _animating,
      builder: (_, animating, _) {
        final index = _dragIndexNotifier.value;
        if (!animating || _fakeDragWidgetAnimation == null || index == -1) {
          return const SizedBox.shrink();
        }
        return _buildSizeBox(
          AnimatedBuilder(
            animation: _fakeDragWidgetAnimation!,
            builder: (_, child) {
              return Transform.translate(
                offset: _fakeDragWidgetAnimation!.value,
                child: child!,
              );
            },
            child: ActivateBox(child: _childrenNotifier.value[index].child),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _isDragging = false;
    _stopAutoScroll();
    _edgeDraggingAutoScroller = null;
    _scrollable = null;
    debouncer.cancel(FunctionTag.handleWill);
    final completer = _transformCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
    _transformCompleter = null;
    _childrenNotifier.removeListener(_handleChildrenChanged);
    _childrenNotifier.value = const [];
    children = const [];
    _pendingChildren = null;
    _itemContexts = [];
    _sizes = [];
    _offsets = [];
    _transformAnimationMap.clear();
    _fakeDragWidgetAnimation = null;
    _fakeDragWidgetController.dispose();
    _shakeController.dispose();
    _transformController.dispose();
    _dragWidgetSizeNotifier.dispose();
    _dragIndexNotifier.dispose();
    _animating.dispose();
    _childrenNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeferredPointerHandler(
      child: Stack(
        children: [
          _buildInactivate(
            ValueListenableBuilder(
              valueListenable: _childrenNotifier,
              builder: (_, children, _) {
                return Grid(
                  axisDirection: AxisDirection.down,
                  crossAxisCount: crossCount,
                  crossAxisSpacing: widget.crossAxisSpacing,
                  mainAxisSpacing: widget.mainAxisSpacing,
                  mainAxisExtent: widget.mainAxisExtent,
                  children: [
                    for (int i = 0; i < children.length; i++) _builderItem(i),
                  ],
                );
              },
            ),
          ),
          _buildFakeTransformWidget(),
        ],
      ),
    );
  }
}

class _DeletableContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  /// 拖动改尺寸。为空时不画手柄。
  /// [delta] 是相对拖动起点的位移，ended 表示手指已抬起。
  final void Function(Offset delta, bool ended)? onResize;

  /// 跟手时的尺寸限位。
  final Size? minCellSize;
  final Size? maxCellSize;

  /// 这块能不能删。基础磁贴不给删——手机端没有导航栏，删掉就再也进不去了。
  final bool deletable;

  const _DeletableContainer({
    required this.child,
    required this.onDelete,
    this.onResize,
    this.minCellSize,
    this.maxCellSize,
    this.deletable = true,
  });

  @override
  State<_DeletableContainer> createState() => _DeletableContainerState();
}

class _DeletableContainerState extends State<_DeletableContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _deleteButtonVisible = true;

  /// 本次拖动累计的位移。手柄按下时清零。
  Offset _dragDelta = Offset.zero;
  bool _deleting = false;

  /// 网格当前分配给这块磁贴的尺寸（每帧从约束里量）。
  Size _cellSize = Size.zero;

  /// 按下手柄那一刻的格子尺寸，跟手的换算以它为基准。
  Size? _dragBaseSize;

  /// 手指当前拖出来的尺寸。为空表示没在拖。
  Size? _liveSize;

  /// 正在拖手柄。只用来把那道弧画粗一点，给"抓住了"的反馈。
  bool _dragging = false;

  /// 手指拖出来的尺寸，限制在上下限之间。
  Size _clampLive(Size base, Offset delta) {
    final min = widget.minCellSize ?? const Size(1, 1);
    final max = widget.maxCellSize ?? base;
    return Size(
      (base.width + delta.dx).clamp(min.width, max.width),
      (base.height + delta.dy).clamp(min.height, max.height),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: commonDuration);
    _scaleAnimation = Tween(
      begin: 1.0,
      end: 0.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _fadeAnimation = Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void didUpdateWidget(_DeletableContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resetting the controller mid-delete cancels the ticker future below,
    // so onDelete would never fire for this card.
    if (!_deleting && oldWidget.child != widget.child) {
      setState(() {
        _controller.value = 0;
        _deleteButtonVisible = true;
      });
    }
  }

  Future<void> _handleDel() async {
    if (_deleting) {
      return;
    }
    _deleting = true;
    // Captured now: this state can be rebound to another item while the
    // animation runs, and widget.onDelete would then target that item.
    final onDelete = widget.onDelete;
    setState(() {
      _deleteButtonVisible = false;
    });
    await _controller.forward(from: 0);
    onDelete();
    _deleting = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        // 每帧记下网格分配的格子尺寸，按下手柄时拿它当跟手的基准。
        if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
          _cellSize = constraints.biggest;
        }
        return CellResize(liveSize: _liveSize, child: _buildStack(context));
      },
    );
  }

  Widget _buildStack(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      // passthrough：把网格给的硬约束原样传给磁贴。默认的 loose 会让磁贴退回用
      // 自己写死的高度，于是格子变高了、卡片还是矮的，下半格空着。
      fit: StackFit.passthrough,
      children: [
        AnimatedBuilder(
          animation: _controller.view,
          builder: (_, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(opacity: _fadeAnimation.value, child: child!),
            );
          },
          child: widget.child,
        ),
        // 右下角一个改尺寸手柄。
        //
        // 手柄演变史（都实测过）：① 卡片内角一个 16px 细线图标——手指按不中；
        // ② 右下角 26px 实心圆——按得中，但和右上角的删除挤在同一条边；③ 右下角
        // 一道弧；④ 四角圆点——躲开了删除按钮，但一屏十几块磁贴就是几十个亮点。
        //
        // 这一版收回到**右下角一个**。删除按钮已经在顶部中央，右下角是离它最远
        // 的位置，当初铺满四个角是为了躲删除，那个理由不成立了。
        if (_deleteButtonVisible && widget.onResize != null)
          _buildResizeHandle(),
        // 删除按钮：**左上角**。
        //
        // 和右下角的改尺寸手柄成对角，是这块卡片上能拉得最开的一对位置——半宽
        // 一行高的磁贴对角线也有 179 像素，一根手指的接触面约 45，够开了。
        // （曾经放顶部中央，那是四角都被尺寸圆点占着时的权宜之计。）
        if (_deleteButtonVisible && widget.deletable)
          Positioned(
            top: -10,
            left: -10,
            child: Align(
              alignment: Alignment.topLeft,
              child: DeferPointer(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: IconButton.filled(
                    iconSize: 20,
                    padding: const EdgeInsets.all(2),
                    onPressed: _handleDel,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 右下角的尺寸手柄。
  ///
  /// 触摸区 44×44（贴在角上、有一半探到磁贴外，靠 DeferPointer 仍可点），画出来
  /// 的只有**沿着磁贴圆角的一小段弧**加两条短臂。按住时线条加粗，给「抓住了」
  /// 的反馈。
  ///
  /// 位置和尺寸都由圆角半径推出来，让这道弧和磁贴的圆角**同心**（推导见
  /// [_ResizeHandlePainter]），所以换主题（圆角 8/12/14/20 各不同）也一样贴合。
  Widget _buildResizeHandle() {
    final tokens = context.styleTokens;
    final accent = tokens.accent(context.colorScheme);
    final radius = tokens.cardRadius;
    final glyph = resizeHandleGlyphSize(radius);
    final offset = resizeHandleOffset(radius);
    return Positioned(
      right: -offset,
      bottom: -offset,
      child: DeferPointer(
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            _HandleDragRecognizer:
                GestureRecognizerFactoryWithHandlers<_HandleDragRecognizer>(
                  _HandleDragRecognizer.new,
                  (recognizer) {
                    recognizer
                      // 必须写成块体：箭头函数后跟 .. 会被解析成对返回值的级联。
                      ..onStart = (_) {
                        _dragDelta = Offset.zero;
                        setState(() {
                          _dragBaseSize = _cellSize;
                          _liveSize = _cellSize;
                          _dragging = true;
                        });
                      }
                      ..onUpdate = (details) {
                        // 右下角「往外」就是右下，位移原样累加即可（正 = 变大）。
                        _dragDelta += details.delta;
                        final base = _dragBaseSize;
                        if (base != null) {
                          setState(() {
                            _liveSize = _clampLive(base, _dragDelta);
                          });
                        }
                        widget.onResize!(_dragDelta, false);
                      }
                      ..onEnd = (_) {
                        setState(() {
                          _liveSize = null;
                          _dragBaseSize = null;
                          _dragging = false;
                        });
                        widget.onResize!(_dragDelta, true);
                      }
                      ..onCancel = () {
                        setState(() {
                          _liveSize = null;
                          _dragBaseSize = null;
                          _dragging = false;
                        });
                        widget.onResize!(_dragDelta, true);
                      };
                  },
                ),
          },
          child: SizedBox(
            // 44×44 触摸区，画出来只有中间那段弧。key 供测试定位。
            key: const ValueKey('resize-handle'),
            width: kResizeHandleTouchSize,
            height: kResizeHandleTouchSize,
            child: Center(
              child: CustomPaint(
                size: Size(glyph, glyph),
                painter: _ResizeHandlePainter(
                  color: accent,
                  pressed: _dragging,
                  radius: radius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 触摸区边长。远大于画出来的图形——线条细不代表按不中。
const double kResizeHandleTouchSize = 44;

/// 弧两端各伸出多长的直臂。
const double _kHandleArm = 8;

/// 描边不贴着图形边缘，留一点余量免得被裁掉。
const double _kHandleInset = 2;

/// 手柄图形的边长：一段半径 [cardRadius] 的弧，两端各接一条 [_kHandleArm] 的臂，
/// 外加描边余量。
///
/// 提成公开函数是为了**让测试对着同一个算式验**，而不是在测试里抄一遍数字——
/// 抄一遍的话改了臂长两边一起改，等于没测。
double resizeHandleGlyphSize(double cardRadius) =>
    cardRadius + _kHandleArm + _kHandleInset * 2;

/// 手柄相对磁贴右下角往外挪多少。
///
/// 算出来的结果是：图形的外角正好落在磁贴的角上，于是那段弧和磁贴圆角**同心**。
/// 推导见 [_ResizeHandlePainter]。
double resizeHandleOffset(double cardRadius) =>
    kResizeHandleTouchSize / 2 -
    resizeHandleGlyphSize(cardRadius) / 2 +
    _kHandleInset;

/// 沿着磁贴右下角圆角画一段弧，两端各接一条短臂。
///
/// **为什么是弧不是直角**：磁贴本身是圆角卡片，一个尖角的括号贴在圆角边上是两种
/// 形状硬碰硬。用同半径的弧，手柄看上去就是卡片边缘被加粗的一小段。
///
/// **怎么做到同心**：调用方按 `p = 触摸区/2 − 图形/2 + 描边余量` 定位（图形边长
/// 是 `半径 + 臂长 + 2×余量`），算下来图形的外角正好落在磁贴的角上，于是这段弧的
/// 圆心和磁贴圆角的圆心重合。半径取主题的 `cardRadius`，换风格自动跟着变。
///
/// 上色是**先描一道半透明黑的粗底、再描主题色的细线**：浅色卡片和深色卡片上都
/// 看得见。圆点那一版靠「白描边 + 投影」凑对比，线条上那么做会糊成一团。
class _ResizeHandlePainter extends CustomPainter {
  const _ResizeHandlePainter({
    required this.color,
    required this.pressed,
    required this.radius,
  });

  final Color color;

  /// 按住时线条加粗，代替圆点那一版的「变大」反馈。
  final bool pressed;

  /// 磁贴的圆角半径。
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = _kHandleInset;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final path = Path()
      ..moveTo(inset, bottom)
      ..lineTo(right - radius, bottom)
      // 从「圆心正下方」转到「圆心正右方」，也就是沿着圆角往上收。y 轴朝下，
      // 这个方向是逆时针。
      ..arcToPoint(
        Offset(right, bottom - radius),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(right, inset);

    final stroke = pressed ? 3.0 : 2.4;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke + 2.4
        ..color = const Color(0x59000000),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ResizeHandlePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.pressed != pressed ||
      oldDelegate.radius != radius;
}

/// 尺寸手柄专用的拖拽识别器：手指一按下就把手势抢过来。
///
/// 普通的 PanGestureRecognizer 要等移动超过阈值才去竞争，而外层滚动视图的阈值更低，
/// 往下拖时永远是滚动视图赢——实测手柄向下拖只会把页面滚一段，磁贴纹丝不动。
/// 手柄是块 40×40 的专用区域，按在上面就只可能是要改尺寸，直接抢下来没有歧义。
class _HandleDragRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
