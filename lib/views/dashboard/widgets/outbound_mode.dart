import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OutboundModeV2 extends StatelessWidget {
  const OutboundModeV2({super.key});

  void _handleChangeMode(Mode mode) {
    globalState.container.read(setupActionProvider.notifier).changeMode(mode);
  }

  /// 卡片高度：桌面端那条 Tabs 约 40 高，加上卡片自己的上下内边距 8+8。
  static const _cardHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    // **卡片按内容高度，不撑满一整行格子。**
    //
    // 这是一条控制条，不是一张有内容的卡片：桌面端那边是 HeroUI 的 `Tabs`
    // （`sider/outbound-mode-switcher.tsx`），tabList 内边距 4、每个 tab 高 32，
    // 连边一起约 40 高。手机端原来把它撑到整整一行（80），三个按钮撑在里面显得
    // 特别空——用户原话是「磁贴太大了」。
    //
    // 网格给的是硬约束，所以外面必须包 [Center]，否则 SizedBox 会被拉回一行高。
    // 上下多出来的空白就是格子里的留白，视觉上这块卡片明显矮了一截。
    return Center(
      child: SizedBox(
        height: _cardHeight,
        child: CommonCard(
          child: Consumer(
            builder: (_, ref, _) {
              final mode = ref.watch(
                patchClashConfigProvider.select((state) => state.mode),
              );
              return Padding(
                padding: const EdgeInsets.all(8),
                child: ModeSegments(mode: mode, onChanged: _handleChangeMode),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 出站模式的分段控件：一条底槽 + 一块会滑动的蓝色高亮方块。
///
/// 照桌面端来——那边用的是 HeroUI 的 `Tabs color="primary"`，底槽是 content1，
/// 选中项后面是一块实心蓝的圆角方块，切换时方块滑过去。之前手机端做成了三个
/// 单选圆点的列表，和桌面端完全是两个东西。
///
/// 竖排还是横排跟着可用空间走：桌面端自己也是这么干的（窄的时候 `flex-col`）。
class ModeSegments extends StatefulWidget {
  const ModeSegments({super.key, required this.mode, required this.onChanged});

  final Mode mode;
  final ValueChanged<Mode> onChanged;

  @override
  State<ModeSegments> createState() => _ModeSegmentsState();
}

class _ModeSegmentsState extends State<ModeSegments>
    with SingleTickerProviderStateMixin {
  static const _modes = Mode.values;

  /// 高亮方块当前停在第几格（可以是小数，也可以短暂越过两端）。
  ///
  /// 用 unbounded：弹簧过冲时取值会超出 [0, 格数-1]，普通控制器会把它夹回去，
  /// 过冲就没了。真正夹取值的地方在 [build] 里，只夹「画到哪」不夹物理量——
  /// 夹在物理量上会让弹簧提前失去动能，回弹变形。
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: _modes.indexOf(widget.mode).toDouble(),
  );

  @override
  void didUpdateWidget(covariant ModeSegments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode == widget.mode) {
      return;
    }
    // 切换模式是用户点出来的、立刻就发生的变化，所以用弹簧而不是缓动：缓动走完
    // 就停，观感是「被程序挪了一下」；弹簧带惯性和一点点回弹，才像把方块推过去。
    //
    // 起始速度取当前速度而不是 0：连着点两下时不把上一次的动量丢掉，方块会顺势
    // 加速过去，而不是在半路先刹停再重新起步。
    _controller.animateWith(
      SpringSimulation(
        Motion.spring,
        _controller.value,
        _modes.indexOf(widget.mode).toDouble(),
        _controller.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.styleTokens;
    final colorScheme = context.colorScheme;
    final accent = tokens.accent(colorScheme);
    final onAccent = tokens.onAccent(colorScheme);

    return LayoutBuilder(
      builder: (_, constraints) {
        // 高度够摆下三行就竖排，否则横排。
        final vertical =
            constraints.maxHeight >= 40.0 * _modes.length &&
            constraints.maxHeight > constraints.maxWidth / 2;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            // 桌面端分段控件外框就是中号圆角，不是"比控件再大一点"。
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          child: Padding(
            // 桌面端容器内边距 4px。
            padding: const EdgeInsets.all(4),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // 只在「画到哪」这一步夹住：Stack 默认会裁掉越界的子项，方块要是
                // 真滑出去，两端的过冲不会表现为回弹，而是被切掉一块。夹住之后，
                // 过冲只在中间那一格看得见（滑过头再荡回来），到两端就是「顶到墙」。
                final position = _controller.value.clamp(
                  0.0,
                  (_modes.length - 1).toDouble(),
                );
                final fraction = -1 + 2 * position / (_modes.length - 1);
                final align = vertical
                    ? Alignment(0, fraction)
                    : Alignment(fraction, 0);

                final labels = [
                  for (final (index, item) in _modes.indexed)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onChanged(item),
                        child: Center(
                          child: Builder(
                            builder: (context) {
                              // 文字颜色跟着方块走，不跟着选中状态跳：方块还在半路
                              // 时就把字翻成「主色上的白」，那半秒里字是浮在深色底上
                              // 的，看着像渲染错了。这样写字是被方块「照亮」的。
                              final lit =
                                  1 - (position - index).abs().clamp(0.0, 1.0);
                              return Text(
                                Intl.message(item.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: Color.lerp(
                                    colorScheme.onSurface,
                                    onAccent,
                                    lit,
                                  ),
                                  // 字重不做插值：插值会让文字每帧重新排版、宽度
                                  // 抖动。改成方块越过中线时一次性翻过去，视觉上
                                  // 恰好和「这一格被选中了」同时发生。
                                  fontWeight: lit >= 0.5
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ];

                return Stack(
                  children: [
                    Align(
                      alignment: align,
                      child: FractionallySizedBox(
                        widthFactor: vertical ? 1 : 1 / _modes.length,
                        heightFactor: vertical ? 1 / _modes.length : 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: accent,
                            // 选中胶囊套在外框里面，用小一档的圆角，
                            // 否则两条弧线贴在一起会显得胶囊"顶"着外框。
                            borderRadius: BorderRadius.circular(
                              tokens.controlRadiusSmall,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (vertical)
                      Column(children: labels)
                    else
                      Row(children: labels),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
