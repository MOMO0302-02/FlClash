import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/core/core.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/core_status_button.dart';

typedef _IsEditWidgetBuilder = Widget Function(bool isEdit);

/// 磁贴形态：跨几列 × 跨几行。
typedef _Shape = ({int cols, int rows});

const _maxCrossAxisCount = 16;
const _maxGridWidth = 280.0 * _maxCrossAxisCount / 4;

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final key = GlobalKey<SuperGridState>();
  final _isEditNotifier = ValueNotifier<bool>(false);
  final _addedWidgetsNotifier = ValueNotifier<List<GridItem>>([]);

  /// 每块磁贴开始拖动时的行列数。不记住起点的话，拖动过程中尺寸一变，
  /// 下一帧的换算基准就跟着变，手指没动尺寸也会自己抖。
  final Map<String, ({int cols, int rows})> _dragStartShape = {};

  /// 磁贴逐个入场是否已经放过了。
  ///
  /// 这套动画只该在**第一次进首页**时放一次。首页每秒都在刷新（时长、流量、网速），
  /// 每刷新一次就重播一遍等于整屏每秒抖一下；编辑模式进出会把整棵网格拆了重建，
  /// 重播同样只是噪音。所以放完第一帧就把这个开关关掉，之后建出来的磁贴直接是终态。
  ///
  /// 故意不用 `setState`：这个值只影响「新建的磁贴要不要动」，改它不需要重建界面，
  /// 真去 setState 反而会把正在播的入场动画打断。
  bool _entranceDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceDone = true;
    });
  }

  @override
  void dispose() {
    _isEditNotifier.dispose();
    _addedWidgetsNotifier.dispose();
    super.dispose();
  }

  Widget _buildIsEdit(_IsEditWidgetBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _isEditNotifier,
      builder: (_, isEdit, _) {
        return builder(isEdit);
      },
    );
  }

  List<Widget> _buildActions(bool isEdit) {
    return [
      if (!isEdit && coreLib == null) const CoreStatusButton(),
      if (isEdit)
        ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, addedChildren, child) {
            if (addedChildren.isEmpty) {
              return Container();
            }
            return child!;
          },
          child: IconButton(
            onPressed: () {
              _showAddWidgetsModal();
            },
            icon: const Icon(Icons.add_circle),
          ),
        ),
      if (isEdit)
        IconButton(
          tooltip: context.appLocalizations.reset,
          onPressed: _handleRestoreDefaults,
          icon: const Icon(Icons.settings_backup_restore),
        ),
      FadeRotationScaleBox(
        child: isEdit
            ? IconButton(
                key: const ValueKey(true),
                icon: const Icon(Icons.save, key: ValueKey('save-icon')),
                onPressed: _handleSaveAndExit,
              )
            : IconButton(
                key: const ValueKey(false),
                icon: const Icon(Icons.edit, key: ValueKey('edit-icon')),
                onPressed: _handleEnterEdit,
              ),
      ),
    ];
  }

  void _showAddWidgetsModal() {
    showSheet(
      builder: (_) {
        return ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, value, _) {
            return AdaptiveSheetScaffold(
              body: _AddDashboardWidgetModal(
                items: value,
                onAdd: (gridItem) {
                  key.currentState?.handleAdd(gridItem);
                },
              ),
              title: context.appLocalizations.add,
            );
          },
        );
      },
      context: context,
    );
  }

  /// 把首页恢复成出厂布局：磁贴清单、每块的宽高全部还原。
  ///
  /// 磁贴可以删、可以拖、可以改尺寸，改乱了想还原只能一块块加回来——所以需要
  /// 一个兜底出口。会二次确认，因为它会覆盖用户排了半天的布局。
  Future<void> _handleRestoreDefaults() async {
    final confirmed = await globalState.showMessage(
      title: context.appLocalizations.reset,
      message: TextSpan(text: context.appLocalizations.resetTip),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    ref
        .read(appSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            dashboardWidgets: defaultDashboardWidgets,
            dashboardWidgetSpans: const {},
            dashboardWidgetRows: const {},
          ),
        );
    _dragStartShape.clear();
    // 网格在 initState 里把 children 复制进自己的 state，之后不跟随外部变化，
    // 所以换 key 强制重建一次，否则界面还是老布局。
    _isEditNotifier.value = false;
  }

  void _handleEnterEdit() {
    if (_isEditNotifier.value) {
      return;
    }
    // 进出编辑模式是整页换了一种玩法，但屏幕上除了右上角图标换了个样子之外没有
    // 别的提示。给一下震动——和改磁贴尺寸时那一下是同一套语言，用户不用盯着看
    // 也知道「模式变了」。
    HapticFeedback.mediumImpact();
    _isEditNotifier.value = true;
  }

  void _handleExitEdit() {
    if (!_isEditNotifier.value) {
      return;
    }
    final dashboardWidgets = _getDashboardWidgets(key.currentState);
    if (dashboardWidgets != null) {
      _saveDashboardWidgets(dashboardWidgets);
    }
    HapticFeedback.mediumImpact();
    _isEditNotifier.value = false;
  }

  Future<void> _handleSaveAndExit() async {
    if (!_isEditNotifier.value) {
      return;
    }
    await _handleSave();
    if (mounted) {
      HapticFeedback.mediumImpact();
      _isEditNotifier.value = false;
    }
  }

  Future<void> _handleSave() async {
    final currentState = key.currentState;
    if (currentState == null) {
      return;
    }
    if (!mounted || currentState.snapshotChildren.isEmpty) {
      return;
    }
    final transformCompleted = await currentState.isTransformCompleter;
    if (!transformCompleted ||
        !mounted ||
        !currentState.mounted ||
        !identical(key.currentState, currentState)) {
      return;
    }
    final dashboardWidgets = _getDashboardWidgets(currentState);
    if (dashboardWidgets == null) {
      return;
    }
    _saveDashboardWidgets(dashboardWidgets);
  }

  List<DashboardWidget>? _getDashboardWidgets(SuperGridState? currentState) {
    if (currentState == null) {
      return null;
    }
    final children = currentState.snapshotChildren;
    if (children.isEmpty) {
      return null;
    }
    // 按 child 的类型反查。磁贴宽度可调，界面会用新的 crossAxisCellCount 重新
    // 构造 GridItem，所以不能按 GridItem 本身相等来找。
    return children.map(DashboardWidget.getDashboardWidget).toList();
  }

  /// 记住某块磁贴的形态（跨几列 × 几行）。
  void _setShape(DashboardWidget item, int cols, int rows) {
    ref.read(appSettingProvider.notifier).update((state) {
      final spans = Map<String, int>.of(state.dashboardWidgetSpans);
      final rowMap = Map<String, int>.of(state.dashboardWidgetRows);
      spans[item.name] = cols;
      rowMap[item.name] = rows;
      return state.copyWith(
        dashboardWidgetSpans: spans,
        dashboardWidgetRows: rowMap,
      );
    });
  }

  /// 取某块磁贴当前的形态：用户调过就用用户的，没调过用枚举里的默认值。
  _Shape _shapeOf(
    DashboardWidget item,
    Map<String, int> spans,
    Map<String, int> rows,
  ) {
    return (
      cols: spans[item.name] ?? item.widget.crossAxisCellCount,
      rows: rows[item.name] ?? item.widget.mainAxisCellCount?.round() ?? 1,
    );
  }

  /// 把拖出来的像素尺寸吸附成四种形态之一。
  ///
  /// 只留四种是刻意的：格子太自由的话，稍微差一列就会排不满、留下豁口。
  /// 宽度非半即整，高度非一行即两行，怎么摆都能拼齐。
  _Shape _snapShape({
    required double width,
    required double height,
    required double stride,
    required double rowUnit,
    required double spacing,
    required int columns,
    required int minRows,
  }) {
    final narrow = columns ~/ 2;
    // 取两档之间的中点当分界：过了一半就跳到下一档。
    final widthMid =
        (stride * narrow - spacing + stride * columns - spacing) / 2;
    final heightMid = (rowUnit - spacing + rowUnit * 2 - spacing) / 2;
    return (
      cols: width >= widthMid ? columns : narrow,
      // 本来就两行高的磁贴（出站模式的三个单选、网速图、流量环）压不进一行，
      // 硬压就是内容溢出，所以只让它们长高不让它们变矮。
      rows: max(height >= heightMid ? 2 : 1, minRows),
    );
  }

  void _saveDashboardWidgets(List<DashboardWidget> dashboardWidgets) {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(dashboardWidgets: dashboardWidgets));
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardStateProvider);
    final spans = ref.watch(
      appSettingProvider.select((state) => state.dashboardWidgetSpans),
    );
    final rows = ref.watch(
      appSettingProvider.select((state) => state.dashboardWidgetRows),
    );
    final spacing = 14.mAp;
    // 行高交给网格统一算，磁贴自己写的 SizedBox 会被网格的硬约束顶掉。
    // 这个式子和 getWidgetHeight 一致：n 行 = n * 单元高 - 一个间距。
    final rowUnit = 80.ap + spacing;
    return _buildIsEdit((isEdit) {
      // 磁贴宽度可调：用户设过就用用户的，没设过用枚举里的默认值。
      // 尺寸按钮画在 SuperGrid 自己的编辑层里（挨着删除按钮），不能包在磁贴
      // 外面——包一层会改变 child 的类型与布局，把网格的排版打断，实测编辑
      // 模式下整片空白。
      // 网格拿到的是过滤后的列表，onResize 回调里的下标要对这个列表取，
      // 不能对未过滤的 dashboardWidgets 取——桌面专属磁贴会让下标错位。
      final visible = dashboardState.dashboardWidgets
          .where(
            (item) => item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .toList();
      // 编辑模式和浏览模式各自一份子项列表，不共用。
      //
      // 编辑模式那份**必须和以前逐字一样**：SuperGrid 会把删除按钮、尺寸手柄画在
      // 自己的编辑层里，往磁贴外面再包一层曾经把它的排版整个打断过（实测编辑模式
      // 下整片空白）。入场动画只在浏览模式下有意义，所以干脆不碰编辑那条路径。
      List<GridItem> buildChildren({required bool staggered}) {
        final items = <GridItem>[];
        for (final (index, item) in visible.indexed) {
          final shape = _shapeOf(item, spans, rows);
          // 包一层尺寸动画壳，换形态时才不是瞬间跳过去。壳上带枚举名做 key，因为
          // 包完之后所有 child 的类型都一样了，反查磁贴只能靠它。再往外包入场动画
          // 时，key 要跟着挪到最外层——反查读的是 `gridItem.child.key`。
          final cell = AnimatedCellBox(
            key: staggered ? null : ValueKey(item.name),
            child: item.widget.child,
          );
          items.add(
            GridItem(
              crossAxisCellCount: shape.cols,
              mainAxisCellCount: shape.rows,
              child: staggered
                  ? StaggeredEntrance(
                      key: ValueKey(item.name),
                      index: index,
                      animate: !_entranceDone,
                      child: cell,
                    )
                  : cell,
            ),
          );
        }
        return items;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 「已经在首页了」直接按枚举名判断。原来比的是 child 的类型，但磁贴现在
        // 包了一层尺寸动画壳，类型全都一样，重复永远判不出来，于是添加面板把所有
        // 磁贴都列了一遍——包括首页已经有的那些。
        final onBoard = visible.map((item) => item.name).toSet();
        _addedWidgetsNotifier.value = DashboardWidget.values
            .where(
              (item) =>
                  !onBoard.contains(item.name) &&
                  item.platforms.contains(SupportPlatform.currentPlatform),
            )
            .map((item) => item.widget)
            .toList();
      });
      return CommonScaffold(
        title: context.appLocalizations.dashboard,
        actions: _buildActions(isEdit),
        // 不要悬浮的开始按钮：状态总览那块磁贴点一下就是启停，两个入口重复，
        // 而且悬浮按钮会盖住右下角的磁贴。
        body: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16).copyWith(bottom: 88),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxGridWidth),
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final columns = min(
                        max(4 * ((constraints.maxWidth / 280).ceil()), 8),
                        _maxCrossAxisCount,
                      );
                      // 一列占多宽：总宽加一个间距，再按列数均分。
                      final stride = (constraints.maxWidth + spacing) / columns;
                      return isEdit
                          ? BackLayerScope(
                              onBack: _handleExitEdit,
                              child: SuperGrid(
                                key: key,
                                crossAxisCount: columns,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                mainAxisExtent: rowUnit,
                                // 基础磁贴不给删：手机端没有常驻导航栏，磁贴就是
                                // 唯一入口，删掉「设置」就再也进不去设置页了。
                                canDelete: (index) =>
                                    index < 0 ||
                                    index >= visible.length ||
                                    !visible[index].essential,
                                // 拖动时磁贴一比一跟手，但收在最小 / 最大形态之间。
                                minCellSize: Size(
                                  stride * (columns ~/ 2) - spacing,
                                  rowUnit - spacing,
                                ),
                                maxCellSize: Size(
                                  stride * columns - spacing,
                                  rowUnit * 2 - spacing,
                                ),
                                children: buildChildren(staggered: false),
                                onUpdate: () {
                                  _handleSave();
                                },
                                onResize: (index, delta, ended) {
                                  if (index < 0 || index >= visible.length) {
                                    return;
                                  }
                                  final item = visible[index];
                                  if (ended) {
                                    // 手指抬起就忘掉起点，下一次拖动重新计。
                                    _dragStartShape.remove(item.name);
                                    return;
                                  }
                                  final start =
                                      _dragStartShape[item.name] ??
                                      _shapeOf(item, spans, rows);
                                  _dragStartShape[item.name] = start;
                                  final next = _snapShape(
                                    width:
                                        stride * start.cols -
                                        spacing +
                                        delta.dx,
                                    height:
                                        rowUnit * start.rows -
                                        spacing +
                                        delta.dy,
                                    stride: stride,
                                    rowUnit: rowUnit,
                                    spacing: spacing,
                                    columns: columns,
                                    minRows:
                                        item.widget.mainAxisCellCount
                                            ?.round() ??
                                        1,
                                  );
                                  final current = _shapeOf(item, spans, rows);
                                  if (next == current) return;
                                  // 换形态给一下震动。macOS / iOS 的小组件就是靠
                                  // 这一下让人知道「已经吸附到下一档了」，没有它
                                  // 光靠眼睛看会觉得反馈很虚。
                                  HapticFeedback.selectionClick();
                                  // 先让网格就地重排（它不跟随外部变化），
                                  // 再把新形态存下来。
                                  key.currentState?.handleResize(
                                    index,
                                    next.cols,
                                    next.rows,
                                  );
                                  _setShape(item, next.cols, next.rows);
                                },
                              ),
                            )
                          : Grid(
                              crossAxisCount: columns,
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              mainAxisExtent: rowUnit,
                              children: buildChildren(staggered: true),
                            );
                    },
                  ),
                ),
              ),
            ),
          ),
      );
    });
  }
}
class _AddDashboardWidgetModal extends StatelessWidget {
  final List<GridItem> items;
  final Function(GridItem item) onAdd;

  const _AddDashboardWidgetModal({required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return DeferredPointerHandler(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Grid(
          crossAxisCount: 8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          // 磁贴现在自带行数，这里也得给行高，不然网格拿列宽当行高、卡片全被压扁。
          mainAxisExtent: 80.ap + 16,
          children: items
              .map(
                (item) => item.wrap(
                  builder: (child) {
                    return _AddedContainer(
                      onAdd: () {
                        onAdd(item);
                      },
                      child: child,
                    );
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _AddedContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onAdd;

  const _AddedContainer({required this.child, required this.onAdd});

  @override
  State<_AddedContainer> createState() => _AddedContainerState();
}

class _AddedContainerState extends State<_AddedContainer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_AddedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {}
  }

  Future<void> _handleAdd() async {
    widget.onAdd();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      // 同 _DeletableContainer：默认的 loose 会让磁贴退回自己写死的高度。
      fit: StackFit.passthrough,
      children: [
        ActivateBox(child: widget.child),
        Positioned(
          top: -8,
          right: -8,
          child: DeferPointer(
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton.filled(
                iconSize: 20,
                padding: const EdgeInsets.all(2),
                onPressed: _handleAdd,
                icon: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
