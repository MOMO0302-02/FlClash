import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:flutter/material.dart';

/// 通用胶囊标签。
///
/// Material 默认的 Chip 是「outlineVariant 的实线边框 + 8 圆角」，在纯黑底上那条
/// 边框比周围任何一条线都亮。桌面端的 chip 是深灰底 + 一圈很淡的白色描边，
/// 圆角跟控件走。
class CommonChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ChipType type;
  final Widget? avatar;
  final TextStyle? labelStyle;

  const CommonChip({
    super.key,
    required this.label,
    this.labelStyle,
    this.onPressed,
    this.avatar,
    this.type = ChipType.action,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.styleTokens;
    final colorScheme = context.colorScheme;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(tokens.controlRadius),
      side: BorderSide(color: tokens.rim),
    );
    const labelPadding = EdgeInsets.symmetric(vertical: 0, horizontal: 4);
    if (type == ChipType.delete) {
      return Chip(
        avatar: avatar,
        labelPadding: labelPadding,
        clipBehavior: Clip.antiAlias,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: colorScheme.surfaceContainerHigh,
        side: BorderSide.none,
        shape: shape,
        deleteIconColor: colorScheme.onSurfaceVariant,
        onDeleted: onPressed ?? () {},
        labelStyle: labelStyle,
        label: Text(label),
      );
    }
    return ActionChip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: avatar,
      clipBehavior: Clip.antiAlias,
      labelPadding: labelPadding,
      backgroundColor: colorScheme.surfaceContainerHigh,
      side: BorderSide.none,
      shape: shape,
      onPressed: onPressed ?? () {},
      labelStyle: labelStyle,
      label: Text(label),
    );
  }
}
