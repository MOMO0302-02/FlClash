import 'package:flutter/material.dart';

/// 横向排开的一排可选卡片（主题模式、界面风格这类"几选一"用它）。
///
/// **别把它改回「`Container(height: 56)` 直接套 `ListView`」。** 那样滚动视口
/// 正好只有卡片那么高，卡片的外阴影会被视口在上下**齐刷刷切断**：深色底上黑阴影
/// 本来就看不见，白底上就变成一条上下沿笔直、横在按钮下面的灰带子——用户报的
/// 「主题切换页按钮下是灰色条」就是它。
///
/// 实测证据（`temp/shots/theme_light.png`，2 倍缩放）：灰带从 y=543 到 y=655
/// 恰好是视口的 112 物理像素，中间一律 243/255，边界处一个像素之内直接跳回纯白
/// ——正是硬裁的特征，不是阴影该有的渐变。
///
/// 修法是让视口比卡片高出 [shadowGutter]，阴影有地方糊完再消失。左右内边距也
/// 必须放在 `ListView.padding` 上而不是外层 `Container` 上：留在外层的话视口两侧
/// 同样是硬边，第一张和最后一张卡片的侧向阴影照样被切。
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// 卡片本身的高度。整排的高度是它加上上下两条 [shadowGutter]。
  static const double chipHeight = 56;

  /// 留给阴影的上下余量。
  ///
  /// `desktop_parity_test` 实测 shadow-medium 到边缘外 20 像素处已经基本回到底色
  /// （127/128），16 足够把可见的那一段放完，再大只是白占地方。
  static const double shadowGutter = 16;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: chipHeight + shadowGutter * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: shadowGutter,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
      ),
    );
  }
}
