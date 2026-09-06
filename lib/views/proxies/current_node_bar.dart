import 'package:clash_party/common/common.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 代理页顶部常驻的「当前实际走的是谁」。
///
/// 设计意图：Smart 组是内核自动选路，用户点进来最想知道的就是「它到底给我选了
/// 哪个节点」。原本要展开组才看得到，现在提到页面顶部常驻一行。
class CurrentNodeBar extends ConsumerWidget {
  const CurrentNodeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.styleTokens;
    final colorScheme = context.colorScheme;

    final groupName = ref.watch(
      currentProfileProvider.select((state) => state?.currentGroupName),
    );
    if (groupName == null) return const SizedBox.shrink();

    // 必须读 Group.now（内核报上来的实际选中项），不能读 selectedMap——那只记录
    // 用户手动点过的组。Smart / url-test 这类自动选路的组不在里面，会显示成「未知」。
    final groups = ref.watch(currentGroupsStateProvider).value;
    final node = groups.getGroup(groupName)?.now;
    // 内核没启动时拿不到实际选中项，这条就没有信息量——整条隐藏，
    // 别留一行空白在那儿。
    if (node == null || node.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          // 这一条也是一张卡，就得有卡片的那圈白色高光边和两层淡阴影，
          // 否则在纯黑底上是一块贴上去的色块，跟旁边的卡片不是一路货。
          border: Border.all(color: tokens.rim),
          boxShadow: tokens.cardShadow,
        ),
        child: Row(
          children: [
            // 图标用前景白：强调色只留给「选中」这一种状态，
            // 到处用蓝会让真正的选中态失去分量。
            Icon(Icons.bolt, size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // Smart 组会自己换节点，换的那一下原来是文字凭空替换，
                  // 眼角余光只会看到「闪了一下」，读不出换成了谁。交叉淡入
                  // 让新旧两个名字有一瞬间同时在场，才看得出是「换了」。
                  //
                  // 不是用户点出来的变化，用缓动不用弹簧。
                  AnimatedSwitcher(
                    duration: Motion.normal,
                    switchInCurve: Motion.enter,
                    switchOutCurve: Motion.exit,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previousChildren, ?currentChild],
                    ),
                    child: Text(
                      node,
                      // key 认名字：名字没变就不该重播，否则每次
                      // currentGroupsStateProvider 刷新都会闪一次。
                      key: ValueKey(node),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
