import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/views/dashboard/widgets/dashboard_tile.dart';
import 'package:clash_party/views/dashboard/widgets/network_detection_detail.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkDetection extends ConsumerWidget {
  const NetworkDetection({super.key});

  /// 磁贴上那一行：**只有 IP**。
  ///
  /// 原来是「IP · 城市」，但半宽磁贴一行放不下，城市几乎总是被截成
  /// 「43.198.97.166 · Hon…」——半截地名既没信息量又显得像出错了。而地区其实
  /// 已经由左边的国旗表达了，点进详情页还有完整的地理位置、经纬度、运营商。
  ///
  /// 所以磁贴上留最要紧的那一个：出口 IP。
  static String ipLine(IpInfo info) => info.ip;

  static String _countryCodeToEmoji(String countryCode) {
    final String code = countryCode.toUpperCase();
    if (code.length != 2) {
      return countryCode;
    }
    final int firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final networkDetection = ref.watch(networkDetectionProvider);
    final ipInfo = networkDetection.ipInfo;
    final isLoading = networkDetection.isLoading;
    final emojiTextStyle = context.textTheme.titleMedium?.toLight.copyWith(
      fontFamily: FontFamily.twEmoji.value,
    );

    // 检测完成时左上角的图标换成国旗，和右上角那行 IP 是同一件事的两半。
    // 都套 FadeThroughBox 淡入淡出，避免一半动一半跳。
    final leading = FadeThroughBox(
      child: ipInfo != null
          ? Text(_countryCodeToEmoji(ipInfo.countryCode), style: emojiTextStyle)
          : Icon(
              Icons.network_check,
              size: kDashboardTileIconSize,
              color: context.colorScheme.onSurface,
            ),
    );

    final Widget trailing = FadeThroughBox(
      child: ipInfo != null
          ? _IpText(
              ip: NetworkDetection.ipLine(ipInfo),
              style: dashboardTileValueStyle(
                context,
              )!.copyWith(fontFeatures: tabularFigures),
            )
          : isLoading == false && ipInfo == null
          ? Text(
              appLocalizations.timeout,
              style: dashboardTileValueStyle(
                context,
                // 走统一的危险色：Material 那个 red 和项目里其它报错处用的
                // 颜色不是同一个。
              )?.copyWith(color: AppStyleTokens.danger),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : const SizedBox(height: 16, width: 16, child: HeroSpinner()),
    );

    return DashboardTile(
      leading: leading,
      label: appLocalizations.networkDetection,
      // 点进去看完整的判断依据：出口 IP / 地区 / 内网地址 / 当前节点 /
      // 系统代理与虚拟网卡状态。
      onTap: () => showExtend(
        context,
        builder: (_) => const NetworkDetectionDetailView(),
      ),
      // **IP 放右上角那一行，不放磁贴中段。**
      //
      // 曾经把它挪到中段，结果上下都被切掉：一行高的磁贴总共 80 像素，去掉上下
      // 内边距 16、顶部图标行 32、底部标题约 20，中段只剩约 12 像素，装不下 17
      // 号字。右上角那一行有 32 像素高，本来就是给附加信息准备的。
      //
      // 宽度够不够？半宽磁贴给这一格留约 130 像素，`208.8.203.24` 约占 107。
      // 当初「显示不全」是因为那时写的是「IP · 城市」，改成只显示 IP 就够了。
      trailing: trailing,
    );
  }
}

/// 磁贴上的那一行 IP：先按比例缩，缩到下限还塞不下就从中间省略。
///
/// **为什么不是简单的 `FittedBox(scaleDown)`**：那个没有下限。IPv4 最长 15 个
/// 字符，缩一点点就进去了；IPv6 是 39 个字符
/// （`2001:0db8:85a3:0000:0000:8a2e:0370:7334`），同样的宽度要缩到 5 号字左右
/// ——不溢出，但等于看不见。
///
/// **为什么不是简单的省略号**：默认的省略是从尾巴截，`2001:0db8:85a3:00…` 看不出
/// 是哪个地址。IP 的**头和尾**才是能认出来的部分，所以从中间省。
///
/// 宽度是 [LayoutBuilder] 现场给的，字宽用 [TextPainter] 实测——不靠"超过多少个
/// 字符就截断"这种规则：同样 39 个字符，等宽数字和普通字体量出来差得远。
class _IpText extends StatelessWidget {
  const _IpText({required this.ip, required this.style});

  final String ip;
  final TextStyle style;

  /// 最多缩到原字号的多少。再小就该省略而不是继续缩。
  static const _minScale = 0.7;

  double _widthOf(String text, TextStyle textStyle, double textScale) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(textScale),
    )..layout();
    return painter.width;
  }

  /// 把 [text] 从中间挖掉一段，直到宽度塞得下。
  String _middleEllipsis(
    String text,
    TextStyle textStyle,
    double textScale,
    double maxWidth,
  ) {
    // 逐个字符往里收，两头各留一半。字符串最长 39，循环次数微不足道。
    for (var keep = text.length - 1; keep > 4; keep--) {
      final head = (keep + 1) ~/ 2;
      final tail = keep - head;
      final candidate =
          '${text.substring(0, head)}…'
          '${text.substring(text.length - tail)}';
      if (_widthOf(candidate, textStyle, textScale) <= maxWidth) {
        return candidate;
      }
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (_, constraints) {
        final maxWidth = constraints.maxWidth;
        var text = ip;
        var scale = 1.0;
        if (maxWidth.isFinite) {
          final full = _widthOf(ip, style, textScale);
          if (full > maxWidth && full > 0) {
            scale = (maxWidth / full).clamp(_minScale, 1.0);
            final scaled = style.copyWith(
              fontSize: (style.fontSize ?? 14) * scale,
            );
            if (_widthOf(ip, scaled, textScale) > maxWidth) {
              text = _middleEllipsis(ip, scaled, textScale, maxWidth);
            }
          }
        }
        return TooltipText(
          // 完整值仍然能长按看到——省略只发生在显示上。
          text: Text(
            text,
            style: style.copyWith(fontSize: (style.fontSize ?? 14) * scale),
            maxLines: 1,
          ),
        );
      },
    );
  }
}
