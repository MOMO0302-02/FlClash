/// 流式列表（连接、请求、日志）专用的动效零件。
///
/// 这三个页面和别处最大的不同是**整份数据每秒重来一遍**，条目可能上千。普通列表
/// 那套「建出来就播入场」在这里会变成每秒整屏重播，比不做还糟。所以这里的东西
/// 都围着同一个问题打转：**怎么只对「真的是新来的」那几条做动效。**
///
/// 放在 `views/connection/` 下、日志页也从这里引：这本该是 `lib/widgets/` 里的
/// 共享件，但那是别人的目录。
library;

import 'package:clash_party/common/common.dart';
import 'package:flutter/material.dart';

/// 只在**这一条第一次出现**时播一次入场。
///
/// 关键在 [_animate] 是 `late final`：它只在建这条的时候看一眼 [animate]。
/// 下一秒刷新时调用方会把 [animate] 翻成 false（这条已经不新了），如果跟着变，
/// 动画就会被反复重启。
///
/// 同样重要的是**这个包装层必须一直在**——不能写成「新条目才套一层」。
/// 套与不套会让这条的 Widget 类型变来变去，Flutter 会把整棵子树拆了重建，
/// 连接卡片里那个异步取应用图标的 FutureBuilder 会跟着重来一遍，图标当场闪没。
class StreamItemEntrance extends StatefulWidget {
  const StreamItemEntrance({
    super.key,
    required this.child,
    required this.animate,
    this.index = 0,
  });

  final Widget child;

  /// 这一条是不是本次刷新里新出现的。只在第一次建这条时被读。
  final bool animate;

  /// 逐项错开的序号。只有首屏那一批传真实下标，之后新来的一律传 0——
  /// 一秒后飘进来一条还要排队等前面 8 条，只会显得卡。
  final int index;

  @override
  State<StreamItemEntrance> createState() => _StreamItemEntranceState();
}

class _StreamItemEntranceState extends State<StreamItemEntrance> {
  late final bool _animate = widget.animate;
  late final int _index = widget.index;

  @override
  Widget build(BuildContext context) {
    if (!_animate) {
      return widget.child;
    }
    return StaggeredEntrance(index: _index, child: widget.child);
  }
}

/// 追踪「哪些条目是这一批新出现的」。
///
/// 只存 id 集合，不存时间戳：判断依据是「上一批里有没有它」，天然随数据收缩，
/// 不需要额外清理，也不会因为数据卡住而越积越多。
class StreamFreshTracker {
  Set<String> _known = const {};
  Set<String> _fresh = const {};
  var _isFirstBatch = false;

  /// 首屏那一批（此前一条都没有）才逐项错开，之后新来的直接淡入。
  bool get isFirstBatch => _isFirstBatch;

  bool isFresh(String id) => _fresh.contains(id);

  /// 每次拿到新一批数据时调一次，**必须在把数据交给界面之前**。
  void update(Iterable<String> ids) {
    final next = ids.toSet();
    _isFirstBatch = _known.isEmpty;
    _fresh = next.difference(_known);
    _known = next;
  }
}

/// 「一条都没有」和「有内容」之间淡入淡出，而不是硬切。
///
/// **列表一直挂在树上，空状态只是浮在它上面。** 直觉的写法是拿 [AnimatedSwitcher]
/// 在「列表」和「空状态」之间切，但那会出人命：交叉淡出期间旧列表还在树上，
/// 新列表已经建出来了，两个 ScrollView 同时抢同一个 ScrollController，当场断言
/// 失败。而在搜索框里连着敲两下（先敲成没有匹配、再退回有匹配）就能让空 ↔ 非空
/// 在 260 毫秒内翻两次——这不是极端情况。
///
/// 列表在没有数据时本来就什么都不画，一直留着不花什么代价。
class StreamEmptyOverlay extends StatelessWidget {
  const StreamEmptyOverlay({
    super.key,
    required this.isEmpty,
    required this.empty,
    required this.child,
  });

  final bool isEmpty;

  /// 空状态。有内容时连建都不建，省掉里面那张 SVG 插图的加载。
  final Widget empty;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        // 淡出期间空状态还罩在上面，不挡住点击。
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
            child: isEmpty ? empty : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
