import 'package:clash_party/common/common.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// 首页磁贴的统一版式。
///
/// 桌面版侧边栏的每张卡片都长一个样（`components/sider/*.tsx`）：
///
/// * **图标在左上角**（`CardBody` 里那个透明的 `isIconOnly` 按钮，`text-[24px]`）；
/// * **附加信息在右上角**——由卡片自己决定是什么：开关（系统代理 / 虚拟网卡）、
///   计数徽标（代理组 / 规则）、内存、速率……都摆在 `CardBody` 那一行的右端；
/// * **标题在左下角**（`CardFooter` 里的 `h3`，`text-md font-bold`）。
///
/// 安卓端原来各磁贴各写各的：入口磁贴（[EntryTile]）是这套「图标左上 / 计数右上 /
/// 标题左下」；而开关、Smart、内存、内网 IP、网络检测那几块走的是 `CommonCard`
/// 自带的 `info` 版式——那套是「内容在上、图标+标题挤在底部一行」，和桌面端正好
/// 相反，图标大小（18 vs 20）、标题字号字重（14/w600 vs 16/w700）也都对不上。
/// 一屏摆在一起就是用户说的「文字和图标位置不统一」。
///
/// 这个组件把那套桌面版式收成一处，所有磁贴共用。**不走 `CommonCard.info`**——
/// 那个版式把图标钉在底部，改不动（`widgets/card.dart` 不归本次改动管），所以这里
/// 只用 `CommonCard` 的外壳（圆角、阴影、按压反馈、选中底色），版式自己排。
///
/// 固定高度是 `getWidgetHeight(rows)`，和网格的行高换算一致（见 `dashboard.dart`）。
/// 一行高的磁贴（80 逻辑像素，字号放大到 1.4 倍时 96）余量很小，所以：
/// * 顶部一行放「图标 + 附加信息」，附加信息用 [trailing]；
/// * 底部放标题；
/// * 中间那点空隙留给 [body]（只有两行高的流量环那种才用得上）。
class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    this.trailing,
    this.body,
    this.onTap,
    this.rows = 1,
  }) : assert(
         icon != null || leading != null,
         '至少要有一个图标：传 icon（IconData）或 leading（自定义 widget）',
       );

  /// 左上角的图标。和 [leading] 二选一。
  final IconData? icon;

  /// 左上角的自定义前导 widget（如网络检测里检测完成后换成的国旗）。传了它就不看
  /// [icon]。
  final Widget? leading;

  /// 左下角的标题。
  final String label;

  /// 右上角的附加信息：开关、计数徽标、内存 / IP 文本……由调用方决定。
  final Widget? trailing;

  /// 图标行和标题之间的正文。只有两行高的磁贴（流量环）需要；一行高的留空，
  /// 中间自然是一小段间距。
  final Widget? body;

  final VoidCallback? onTap;

  /// 跨几行。一行高 = 80 逻辑像素（见 [getWidgetHeight]）。
  final int rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final leadingWidget =
        leading ??
        Icon(icon, size: kDashboardTileIconSize, color: colorScheme.onSurface);
    return SizedBox(
      height: getWidgetHeight(rows),
      child: CommonCard(
        onPressed: onTap,
        // **整块磁贴都要能点，不能只有文字和数字能点。**
        //
        // 卡片底层是 Material 的 OutlinedButton，它的点击区只覆盖「内容」；而磁贴
        // 内容是「图标一行 + Spacer + 标题」，中间那个 Spacer 是纯空白、**不参与
        // 命中测试**。结果就是用户反馈的：只有点到数字或标题才进得去，中间大片
        // 空白点了没反应——没用过的人根本找不到入口。
        //
        // 用 ColoredBox(transparent) 把内容整个铺成一块可命中的区域：透明不改变
        // 外观，但让整块参与命中测试。
        child: ColoredBox(
          color: const Color(0x00000000),
          child: Padding(
            padding: kDashboardTilePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部一行高度写死，图标的纵向位置就不再随 trailing 的高低（开关高、
                // 徽标矮）上下漂——所有磁贴的图标落在同一条水平线上。trailing 里的
                // 内容在这一行内纵向居中；太高的（开关）由 [dashboardTileSwitch]
                // 缩到这个高度以内。
                SizedBox(
                  height: kDashboardTileHeaderHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      leadingWidget,
                      // 附加信息一律靠右，占满图标右边剩下的宽度：文本类（IP）好在
                      // 这里截断，开关 / 徽标则靠 Align 停在右端。
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: trailing ?? const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
                if (body != null) Expanded(child: body!) else const Spacer(),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashboardTileTitleStyle(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 开关磁贴右上角的开关。
///
/// Material 3 的 Switch 收紧点击区后仍有约 40 逻辑像素高，直接摆进一行高的磁贴
/// （80 像素）里，加上标题就会溢出。这里把它锁进 [kDashboardTileHeaderHeight] 高的
/// 盒子并用 FittedBox 等比缩放，既不溢出，各开关磁贴的开关也一样大。
Widget dashboardTileSwitch({
  required bool value,
  required ValueChanged<bool>? onChanged,
}) {
  return SizedBox(
    height: kDashboardTileHeaderHeight,
    child: FittedBox(
      fit: BoxFit.contain,
      child: Switch(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        value: value,
        onChanged: onChanged,
      ),
    ),
  );
}

/// 磁贴图标尺寸。桌面端是 24（`text-[24px]`），但那是配鼠标的侧边栏；这里沿用
/// 入口磁贴一直在用的 20，手指点得准、一行高的磁贴里也塞得下。全项目磁贴统一这个值。
// 桌面端卡片图标是 24（`sider/proxy-card.tsx:81`、`conn-card.tsx:235` 的
// `text-[24px]`），侧边栏那个 20 的是「收起态」的小图标，不是这里的。
// 原来取了 20，配 16/700 的标题显得头轻脚重。
const double kDashboardTileIconSize = 24;

/// 顶部「图标 + 附加信息」那一行的固定高度。写死它，图标的纵向位置才不会随
/// trailing 高矮变化，各磁贴对齐在同一条线上。开关会被缩到这个高度以内。
const double kDashboardTileHeaderHeight = 32;

/// 磁贴内边距。左右 16 和入口磁贴一致；上下收到 8——固定高的顶部行加标题要在一行高
/// 的卡片（80 像素）里放下并留出余量，12 会溢出。
final EdgeInsets kDashboardTilePadding = EdgeInsets.fromLTRB(
  16.mAp,
  8.mAp,
  16.mAp,
  8.mAp,
);

/// 磁贴标题样式：16 号、700 字重。对齐桌面端 `text-md font-bold`（原入口磁贴已是
/// 这个值，其余磁贴以前是 14/w600，一并统一过来）。
TextStyle? dashboardTileTitleStyle(BuildContext context) =>
    context.textTheme.labelLarge?.copyWith(
      // **不照搬桌面端的 16/700。** 桌面端 `text-md font-bold` 确实是 16/700，
      // 但那是西文界面——拉丁字母笔画少，700 看着是「有力」。同样的 700 落到
      // 中文上，密集的笔画会糊成一团黑，手机小屏尤其明显（用户原话：字体和
      // 字号「不好看」）。中文界面降一档到 600 就够拉开层次，又不发死。
      //
      // **第二轮再往下收：15/600 → 14/500。** 用户两次反馈「太粗太大」。
      // 标题是配角，只回答"这块是什么"，不需要抢戏；数值那边保住 600，靠分量差
      // 拉开层次——两行都降到 500 的话磁贴会变成一团均匀的灰，反而更难读。
      //
      // 这属于「照抄桌面端的层级关系，但不照抄针对西文调过的数值」。
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.3,
    );

/// 附加信息里的数值文本样式（内存、内网 IP、网络检测的出口 IP 等）。
///
/// **数值是磁贴上的主角，不是配角。** 桌面端把它排成 24 号加粗
/// （`sider/conn-card.tsx:279` 的 `text-[24px] font-bold`）——用户看这张卡就是
/// 为了看这个数。原来这里走的是 `bodyMedium` 的淡色，比 16/700 的标题还轻，
/// 于是「图标小、标题重、数字虚」，三样各说各话，看着就散。
///
/// 手机上磁贴比桌面卡片窄，24 号放不下长 IP。**这个值往下调过两轮**（18 → 17 →
/// 16），用户两次说「太粗太大」；字重保住 600，靠它和标题（14/500）拉开层次。
/// 颜色用正文色而不是淡色。
TextStyle? dashboardTileValueStyle(BuildContext context) =>
    context.textTheme.bodyMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: context.colorScheme.onSurface,
      // 数值多是数字和 IP（西文），用等宽数字——位数变化时不会左右抖。
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// 右上角的计数徽标。
///
/// 照桌面端来（`components/sider/proxy-card.tsx`）：`variant="bordered"` 的 Chip，
/// 强调色描边 + 强调色数字、内部透明。
class DashboardCountBadge extends StatelessWidget {
  const DashboardCountBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = context.styleTokens.accent(context.colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        // 桌面端这圈边是 2px（HeroUI `Chip` 的 `border-medium`）。
        border: Border.all(color: accent, width: 2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: context.textTheme.labelSmall?.copyWith(
          fontSize: 12,
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
