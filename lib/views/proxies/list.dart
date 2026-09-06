import 'dart:math';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/providers/database.dart';
import 'package:clash_party/providers/state.dart';
import 'package:clash_party/views/profiles/profiles.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';
import 'selection_flight.dart';

typedef GroupNameProxiesMap = Map<String, List<Proxy>>;

class ProxiesListView extends StatefulWidget {
  const ProxiesListView({super.key});

  @override
  State<ProxiesListView> createState() => _ProxiesListViewState();
}

class _ProxiesListViewState extends State<ProxiesListView>
    with PageScrollController {
  /// 正文里取到的滚动控制器，缓存给回调用。
  ///
  /// **必须在正文的 builder 里取**：页面 `State.context` 在 `CommonScaffold`
  /// 外面，那儿取到的要么是 null、要么是外层页面的控制器（后者会让一个控制器被
  /// 两个滚动视图接上，读 `.position` 当场断言）。详见 [PageScrollController]。
  ScrollController? _liveController;

  ScrollController _bindController(BuildContext context) {
    final controller = pageScrollControllerOf(context);
    _liveController = controller;
    return controller;
  }

  ScrollController get _controller =>
      _liveController ?? pageScrollControllerOf(context);

  List<double> _groupOffsets = [];
  // The offsets are built from the search-filtered groups, so a group name can
  // only be resolved to an offset against that same list.
  List<Group> _renderedGroups = [];
  double containerHeight = 0;

  /// 每个组最近一次被**展开**的时刻；收起时清掉。
  ///
  /// 入场动画只该在「刚展开」那一下播，可这是个虚拟化列表——往下滚时早先那些行
  /// 会被回收、滚回来又重建，如果只看「这一行是不是新建的」，滚动就会一路重播
  /// 入场，整屏一直在闪。用时间窗口卡住，滚动时建出来的行不会命中。
  final Map<String, DateTime> _expandedAt = {};

  /// 列表第一次拿到数据的时刻，用来只在首次加载时让组标题逐个落下来。
  DateTime? _firstContentAt;

  // 比「最长一条入场动画」留出富余：错开上限 8 项 × 28ms + 260ms ≈ 484ms。
  // 窗口比它短的话，动画还没播完包装层就被撤掉，会当场跳一下。
  static const _entranceWindow = Duration(milliseconds: 800);

  bool _isWithinEntranceWindow(DateTime? at) =>
      at != null && DateTime.now().difference(at) < _entranceWindow;

  /// 每个组最近一次被**收起**的时刻。
  ///
  /// 收起时那些行不能立刻从树上摘掉——摘掉了就没有"从 1 淡到 0"这件事，也就没有
  /// 动画。先留着、把不透明度动到 0，淡完再移除。
  final Map<String, DateTime> _collapsingAt = {};

  /// 淡出时长。这是"东西没了"的收尾提示，不是入场表演，再长会让收起显得拖。
  static const _collapseWindow = Duration(milliseconds: 180);

  bool _isCollapsing(String groupName) {
    final at = _collapsingAt[groupName];
    return at != null && DateTime.now().difference(at) < _collapseWindow;
  }

  void _handleChange(Set<String> currentUnfoldSet, String groupName) {
    _autoScrollToGroup(groupName);
    final tempUnfoldSet = Set<String>.from(currentUnfoldSet);
    if (tempUnfoldSet.contains(groupName)) {
      tempUnfoldSet.remove(groupName);
      _expandedAt.remove(groupName);
      // 记下收起时刻，行会多留 [_collapseWindow] 这么久用来淡出；到点了再重建
      // 一次把它们真正摘掉。
      _collapsingAt[groupName] = DateTime.now();
      Future.delayed(_collapseWindow, () {
        if (mounted) {
          setState(() {
            _collapsingAt.remove(groupName);
          });
        }
      });
    } else {
      tempUnfoldSet.add(groupName);
      _expandedAt[groupName] = DateTime.now();
    }
    updateCurrentUnfoldSet(tempUnfoldSet);
  }

  List<double> _getGroupOffsets({
    required List<Group> groups,
    required int columns,
    required Set<String> currentUnfoldSet,
    required ProxyCardType cardType,
  }) {
    final offsets = <double>[];
    final rowExtent = getItemHeight(cardType) + 8;
    var currentOffset = 0.0;
    for (final group in groups) {
      offsets.add(currentOffset);
      currentOffset += listHeaderHeight + 8;
      if (currentUnfoldSet.contains(group.name)) {
        final rowCount = (group.all.length + columns - 1) ~/ columns;
        currentOffset += rowCount * rowExtent;
      }
    }
    return offsets;
  }

  Widget _buildProxyRow({
    required Group group,
    required List<Proxy> proxies,
    required int columns,
    required ProxyCardType cardType,
    required int rowIndex,
    required bool animateEntrance,
  }) {
    final groupName = group.name;
    final children = proxies
        .map<Widget>(
          (proxy) => Flexible(
            child: SizedBox(
              height: getItemHeight(cardType),
              child: ProxyCard(
                testUrl: group.testUrl,
                type: cardType,
                groupType: group.type,
                key: ValueKey('$groupName.${proxy.name}'),
                proxy: proxy,
                groupName: groupName,
              ),
            ),
          ),
        )
        .fill(columns, filler: (_) => const Flexible(child: SizedBox()))
        .separated(const SizedBox(width: 8));
    final row = Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Row(children: children.toList()),
    );
    if (!animateEntrance) {
      return row;
    }
    return StaggeredEntrance(index: rowIndex, child: row);
  }

  Widget _buildGroup(
    BuildContext context, {
    required Group group,
    required Set<String> currentUnfoldSet,
    required int columns,
    required ProxyCardType cardType,
    required int groupIndex,
    required bool animateHeader,
  }) {
    final groupName = group.name;
    final isExpand = currentUnfoldSet.contains(groupName);
    // 收起动画还没播完时，行照旧要算出来——不然淡出的是一段空白。
    final isCollapsing = !isExpand && _isCollapsing(groupName);
    final rows = isExpand || isCollapsing
        ? group.all.chunks(columns).toList()
        : const <List<Proxy>>[];
    final animateRows =
        isExpand && _isWithinEntranceWindow(_expandedAt[groupName]);
    Widget header = SizedBox(
      height: listHeaderHeight,
      child: ListHeader(
        enterAnimated: false,
        onScrollToSelected: (groupName) {
          _scrollToGroupSelected(groupName, columns);
        },
        key: ValueKey(groupName),
        isExpand: isExpand,
        group: group,
        onChange: (groupName) {
          _handleChange(currentUnfoldSet, groupName);
        },
      ),
    );
    if (animateHeader) {
      // 只包在 SizedBox 外、ColoredBox 里：背景先到位、内容再落下来。
      // 连背景一起淡入的话，吸顶那一条会短暂透出底下滚过去的卡片。
      header = StaggeredEntrance(index: groupIndex, child: header);
    }
    return SliverMainAxisGroup(
      slivers: [
        PinnedHeaderSliver(
          child: ColoredBox(
            color: context.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: header,
            ),
          ),
        ),
        // 收起之后这一段还要在树上待 [_collapseWindow]，好让不透明度从 1 动到
        // 0；摘掉了就没有动画可播（那正是原来"直接消失"的原因）。
        if (isExpand || isCollapsing)
          SliverAnimatedOpacity(
            opacity: isExpand ? 1 : 0,
            duration: _collapseWindow,
            sliver: SliverFixedExtentList(
              itemExtent: getItemHeight(cardType) + 8,
              delegate: SliverChildBuilderDelegate(
                (_, index) => _buildProxyRow(
                  group: group,
                  proxies: rows[index],
                  columns: columns,
                  cardType: cardType,
                  rowIndex: index,
                  animateEntrance: animateRows,
                ),
                childCount: rows.length,
              ),
            ),
          ),
      ],
    );
  }

  double _getGroupOffset(String groupName) {
    if (!_controller.hasClients ||
        _controller.position.maxScrollExtent == 0 ||
        _groupOffsets.isEmpty) {
      return 0;
    }
    final findIndex = _renderedGroups.indexWhere(
      (item) => item.name == groupName,
    );
    final index = findIndex != -1 ? findIndex : 0;
    if (index >= _groupOffsets.length) {
      return 0;
    }
    return _groupOffsets[index];
  }

  void _scrollToMakeVisibleWithPadding({
    required double containerHeight,
    required double pixels,
    required double start,
    required double end,
    double padding = 24,
  }) {
    final visibleStart = pixels;
    final visibleEnd = pixels + containerHeight;

    final isElementVisible = start >= visibleStart && end <= visibleEnd;
    if (isElementVisible) {
      return;
    }

    double targetScrollOffset;

    if (end <= visibleStart) {
      targetScrollOffset = start;
    } else if (start >= visibleEnd) {
      targetScrollOffset = end - containerHeight + padding;
    } else {
      final visibleTopPart = end - visibleStart;
      final visibleBottomPart = visibleEnd - start;
      if (visibleTopPart.abs() >= visibleBottomPart.abs()) {
        targetScrollOffset = end - containerHeight + padding;
      } else {
        targetScrollOffset = start;
      }
    }

    targetScrollOffset = targetScrollOffset.clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );

    _controller.jumpTo(targetScrollOffset);
  }

  void _autoScrollToGroup(String groupName) {
    final pixels = _controller.position.pixels;
    final offset = _getGroupOffset(groupName);
    _scrollToMakeVisibleWithPadding(
      containerHeight: containerHeight,
      pixels: pixels,
      start: offset,
      end: offset + listHeaderHeight,
    );
  }

  void _scrollToGroupSelected(String groupName, int columns) {
    final currentInitOffset = _getGroupOffset(groupName);
    final proxies = _renderedGroups.getGroup(groupName)?.all;
    _jumpTo(
      currentInitOffset +
          8 +
          getScrollToSelectedOffset(
            groupName: groupName,
            proxies: proxies ?? [],
            columns: columns,
          ),
    );
  }

  void _jumpTo(double offset) {
    if (mounted && _controller.hasClients) {
      _controller.animateTo(
        offset.clamp(
          _controller.position.minScrollExtent,
          _controller.position.maxScrollExtent,
        ),
        // 原来是 easeIn：慢启动、快结束，最后「咣」地停住。滚动要的是
        // 两头都慢的 move 曲线，眼睛才跟得住中途滑过去的内容。
        duration: Motion.slow,
        curve: Motion.move,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    // 飞行层要罩住整块列表区域，所以包在最外面：切换节点时那块蓝色是从一张卡
    // 飞到另一张卡的，中途会跨过好几行。
    return ProxySelectionFlight(
      child: Consumer(
        builder: (_, ref, _) {
          final state = ref.watch(proxiesListStateProvider);
          ref.watch(themeSettingProvider.select((state) => state.textScale));
          final proxiesLayout = ref.watch(
            proxiesStyleSettingProvider.select((state) => state.layout),
          );
          final isEmpty = state.groups.isEmpty;
          // 代理组是内核跑起来之后报上来的，不是从订阅文件直接读的。所以「列表为空」
          // 有两种截然不同的原因，说错了就是界面在骗人：真没有订阅，才该让用户去添加；
          // 订阅明明在、只是内核没起来时，只说「暂无代理」，不给误导性的建议。
          final hasProfile = ref.watch(
            profilesProvider.select((profiles) => profiles.isNotEmpty),
          );
          if (isEmpty) {
            _firstContentAt = null;
          } else {
            // 内核起来、组第一次报上来的那一刻。只在这之后的一小段时间里
            // 让组标题逐个落下来，之后（滚动、搜索过滤）一律不再播。
            _firstContentAt ??= DateTime.now();
          }
          final animateHeaders =
              !isEmpty && _isWithinEntranceWindow(_firstContentAt);
          // 空状态和列表之间原来是硬切：内核一起来，插图当场被整页卡片顶掉。
          // 这不是用户直接点出来的变化，用缓动淡入淡出。
          //
          // 列表**一直挂着**、空状态浮在上面（详见 StreamEmptyOverlay 的注释）：
          // 拿 AnimatedSwitcher 在两者之间切的话，淡出期间会有两个
          // CustomScrollView 同时抢 `_controller`，当场断言失败——搜索框里连着
          // 敲两下就能触发。
          return Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (_, constraints) {
                  final columns = utils.getProxiesColumns(
                    max(constraints.maxWidth - 32, 0),
                    proxiesLayout,
                  );
                  _renderedGroups = state.groups;
                  _groupOffsets = _getGroupOffsets(
                    groups: state.groups,
                    currentUnfoldSet: state.currentUnfoldSet,
                    columns: columns,
                    cardType: state.proxyCardType,
                  );
                  containerHeight = max(constraints.maxHeight - 16, 0);
                  return CommonScrollBar(
                    controller: _bindController(context),
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: Padding(
                      // 顶部要给悬浮胶囊让位（那段高度由
                      // `MediaQuery.padding.top` 发下来）。
                      padding: EdgeInsets.only(
                        top: MediaQuery.paddingOf(context).top + 16,
                      ),
                      child: ScrollConfiguration(
                        behavior: HiddenBarScrollBehavior(),
                        child: CustomScrollView(
                          key: proxiesListStoreKey,
                          controller: _controller,
                          slivers: [
                            for (final (index, group) in state.groups.indexed)
                              _buildGroup(
                                context,
                                group: group,
                                currentUnfoldSet: state.currentUnfoldSet,
                                columns: columns,
                                cardType: state.proxyCardType,
                                groupIndex: index,
                                animateHeader: animateHeaders,
                              ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              IgnorePointer(
                ignoring: !isEmpty,
                child: AnimatedSwitcher(
                  duration: Motion.normal,
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    fit: StackFit.expand,
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: isEmpty
                      ? NullStatus(
                          illustration: const ProxyEmptyIllustration(),
                          label: appLocalizations.nullTip(
                            appLocalizations.proxies,
                          ),
                          description: hasProfile
                              ? null
                              : appLocalizations.nullProfileDesc,
                          action: hasProfile
                              ? null
                              : FilledButton.icon(
                                  onPressed: () {
                                    showExtend(
                                      context,
                                      builder: (_) => const ProfilesView(),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: Text(appLocalizations.addProfile),
                                ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ListHeader extends StatefulWidget {
  final Group group;

  final Function(String groupName) onChange;
  final Function(String groupName) onScrollToSelected;
  final bool isExpand;

  final bool enterAnimated;

  const ListHeader({
    super.key,
    this.enterAnimated = true,
    required this.group,
    required this.onChange,
    required this.onScrollToSelected,
    required this.isExpand,
  });

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader>
    with SingleTickerProviderStateMixin {
  var isLock = false;

  /// 整组测速期间让那个图标一呼一吸。
  ///
  /// 这是本页最刺眼的一处缺口：整组测速要跑几秒到十几秒，原来点下去**没有任何
  /// 表现**——按钮不变、数字要等到内核逐个回报才零星刷出来，看起来就像没点上。
  /// 单张卡片重测时至少还有个转圈的，整组反而什么都没有。
  late final AnimationController _testingController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  String get icon => widget.group.icon;

  String get groupName => widget.group.name;

  String get groupType => widget.group.type.name;

  bool get isExpand => widget.isExpand;

  @override
  void dispose() {
    _testingController.dispose();
    super.dispose();
  }

  Future<void> _delayTest() async {
    if (isLock) return;
    isLock = true;
    _testingController.repeat(reverse: true);
    try {
      await delayTest(widget.group.all, widget.group.testUrl);
    } finally {
      isLock = false;
      // 测速中途切走页面是常事，控制器已经跟着 State 销毁了，再碰它会抛。
      if (mounted) {
        _testingController.stop();
        _testingController.value = 0;
      }
    }
  }

  void _handleChange(String groupName) {
    widget.onChange(groupName);
  }

  Widget _buildIcon() {
    return Consumer(
      builder: (_, ref, child) {
        final iconStyle = ref.watch(
          proxiesStyleSettingProvider.select((state) => state.iconStyle),
        );
        return switch (iconStyle) {
          ProxiesIconStyle.standard => LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(6.ap),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        context.styleTokens.controlRadius,
                      ),
                      // 中性的一层底，不用 secondaryContainer——那是 Material 从种子
                      // 推出来的紫蓝，不在桌面端那套灰阶里。
                      color: context.colorScheme.surfaceContainerHighest,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IconTheme.merge(
                      data: IconThemeData(size: constraints.maxHeight - 12.ap),
                      child: CommonTargetIcon(src: icon),
                    ),
                  ),
                ),
              );
            },
          ),
          ProxiesIconStyle.icon => Container(
            margin: const EdgeInsets.only(right: 16),
            child: LayoutBuilder(
              builder: (_, constraints) {
                return IconTheme.merge(
                  data: IconThemeData(size: constraints.maxHeight - 8.ap),
                  child: CommonTargetIcon(src: icon),
                );
              },
            ),
          ),
          ProxiesIconStyle.none => Container(),
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      enterActionsOnRight: true,
      enterAnimated: widget.enterAnimated,
      key: widget.key,
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  _buildIcon(),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 必须钉成一行。这张卡的高度是写死的 `listHeaderHeight`
                        // （按「一行标题 + 一行副标题」算出来的），而组名来自订阅，
                        // 机场给的组名动辄「🇺🇸 美国节点自动选择（延迟优先 · 故障
                        // 转移）」这么长；不加 maxLines 就会换行，一换行整块当场
                        // 撑爆固定高度——名字越长、屏幕越窄，溢出越多。
                        EmojiText(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          flex: 1,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 桌面端这行是 text-foreground-500 的小灰字，
                              // 用调色板里的 onSurfaceVariant，别用按前景色打折
                              // 算出来的近似值。
                              //
                              // 必须可压缩：这一列剩多少宽度，取决于右边那一坨
                              // （节点数角标 + 定位 / 测速 / 展开三个图标按钮）
                              // 占了多少，而那边是定宽的。320dp 小屏 + 1.4 倍字号
                              // 下这里只剩三十几像素，定宽的组类型文字会直接顶出去。
                              Flexible(
                                child: Text(
                                  groupType,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textTheme.labelMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              Flexible(
                                flex: 1,
                                child: Consumer(
                                  builder: (_, ref, _) {
                                    final proxyName = ref
                                        .watch(
                                          selectedProxyNameProvider(groupName),
                                        )
                                        .takeFirstValid([]);
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        if (proxyName.isNotEmpty) ...[
                                          Flexible(
                                            flex: 1,
                                            child: EmojiText(
                                              overflow: TextOverflow.ellipsis,
                                              ' · $proxyName',
                                              style: context
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _GroupCountBadge('${widget.group.all.length}'),
                const SizedBox(width: 4),
                if (isExpand) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(2),
                    onPressed: () {
                      widget.onScrollToSelected(groupName);
                    },
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    // 和紧邻的「测延迟」按钮同尺寸。原来这里是 19、旁边是
                    // 20，两个按钮并排差一个像素——看得出别扭，又说不上哪儿不对。
                    iconSize: 20,
                    color: colorScheme.onSurfaceVariant,
                    icon: const Icon(Icons.adjust),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(2),
                    onPressed: _delayTest,
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    color: colorScheme.onSurfaceVariant,
                    icon: _TestingPulse(
                      animation: _testingController,
                      child: const Icon(Icons.network_ping),
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else
                  const SizedBox(width: 6),
                // 桌面端的展开指示就是一个会转的箭头，没有底色。原来的
                // filledTonal 会在卡片右侧糊上一块 Material 的圆形色块，
                // 是一眼能认出的 Material 默认样式。
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(2),
                  iconSize: 24,
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  color: colorScheme.onSurfaceVariant,
                  onPressed: () {
                    _handleChange(groupName);
                  },
                  icon: CommonExpandIcon(expand: isExpand),
                ),
              ],
            ),
          ],
        ),
      ),
      onPressed: () {
        _handleChange(groupName);
      },
    );
  }
}

/// 「正在做一件要等一会儿的事」的呼吸。
///
/// 不换成转圈的加载图标：那会把「按钮」变成「状态」，按钮的位置和形状一变，
/// 手指刚抬起来就找不到它了。缩放和透明度都只动一点点，图标始终在原地。
class _TestingPulse extends StatelessWidget {
  const _TestingPulse({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(animation.value);
        return Opacity(
          opacity: 1 - 0.45 * t,
          child: Transform.scale(scale: 1 - 0.18 * t, child: child),
        );
      },
      child: child,
    );
  }
}

/// 节点数量角标。桌面端是 HeroUI 的 bordered Chip：**空心蓝边 + 蓝字**，内部透明。
/// 和仪表盘磁贴上的角标保持同一种形态——同一个概念在两处长得不一样最伤观感。
class _GroupCountBadge extends StatelessWidget {
  const _GroupCountBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = context.styleTokens.accent(context.colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: accent, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: context.textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
