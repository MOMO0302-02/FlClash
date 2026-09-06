import 'package:clash_party/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 详情页里的一行「名称 —— 数值」。
///
/// 磁贴详情页全是这种形状：左边一个图标加名称，右边一个值。值可能很长（IP、
/// 主机名、代理链），所以宽度封在屏幕的 45% 里再省略号截断，否则会把名称挤没。
class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.copyable = false,
    this.subtitle,
  });

  final IconData? icon;
  final String label;
  final String value;
  final String? subtitle;

  /// 点一下把 [value] 复制走。只给真的值得复制的行开（地址、主机名）。
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon == null
          ? null
          : Icon(icon, size: 20, color: context.colorScheme.onSurface),
      title: Text(label),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.45,
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      onTap: !copyable
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                context.showNotifier(context.appLocalizations.copySuccess);
              }
            },
    );
  }
}
