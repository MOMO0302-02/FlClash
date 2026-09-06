import 'package:clash_party/common/common.dart';
import 'package:clash_party/models/models.dart';
import 'package:flutter/material.dart';

/// 订阅用量条。
///
/// 相比原先的「单色进度条 + 一行小字」，这里做了三件事：
/// 1. 流量在左、到期在右分列，各自一眼定位，不用在一串文字里找分隔符；
/// 2. 进度条按用量分档着色——快用完时转黄再转红，不读数字也知道该续了；
/// 3. 补上百分比，绝对值和相对值一起给。
///
/// 没做成「剩余 N 天」是因为那需要新增翻译键，而本项目的 l10n 是生成代码、
/// 源 arb 不在仓库里，手改会被下次生成覆盖。改用颜色和百分比传达紧迫感。
class SubscriptionInfoView extends StatelessWidget {
  final SubscriptionInfo? subscriptionInfo;

  /// 画在「已填充主色」的卡片上的程度，0 到 1。
  ///
  /// 选中的订阅卡片整块是主色，这时进度条再用主色会糊成一片，用深色底又几乎
  /// 看不见，所以填充态下改用白色与半透明白。
  ///
  /// **是 0→1 的进度而不是 bool**：卡片底色是渐变到主色的，用 bool 只能在半路
  /// 某一帧「啪」地翻一次配色，和底色对不上。给个进度就能一起渐变过去。
  final double onFilled;

  const SubscriptionInfoView({
    super.key,
    this.subscriptionInfo,
    this.onFilled = 0,
  });

  @override
  Widget build(BuildContext context) {
    final info = subscriptionInfo;
    if (info == null || info.total == 0) {
      return Container();
    }

    final use = info.upload + info.download;
    final total = info.total;
    final ratio = use / total;
    // 进度条本身要夹在 0~1（画不出比整条还长的长度），但**百分比不能用夹过的
    // 值**：超额时读数会停在 100%，跟旁边「110GB / 100GB」那串数字自相矛盾，
    // 看着像刚好用完，而不是已经超了。
    final progress = ratio.clamp(0.0, 1.0);

    final colorScheme = context.colorScheme;
    final filled = onFilled.clamp(0.0, 1.0);
    // 分档阈值：80% 提醒、95% 告警；以下用常规强调色。
    // 填充态下分档着色没有意义（底已经是主色了），统一用白色保证看得见。
    final normalBarColor = switch (progress) {
      >= 0.95 => colorScheme.error,
      >= 0.8 => AppStyleTokens.warning,
      _ => context.styleTokens.accent(colorScheme),
    };
    final barColor = Color.lerp(
      normalBarColor,
      const Color(0xFFFFFFFF),
      filled,
    )!;

    final expireDate = info.expire != 0
        ? DateTime.fromMillisecondsSinceEpoch(info.expire * 1000)
        : null;
    final expireShow =
        expireDate?.show ?? context.appLocalizations.infiniteTime;
    // 已经过期的订阅原来和正常订阅长得一模一样——一个普通的灰色日期，用户得自己
    // 拿今天的日期去比。流量用完了有红条提醒，到期了却什么信号都没有。这里不新增
    // 文案，只把过期的日期本身转成错误色：日期已经写在那儿了，红了就够说明问题。
    final isExpired = expireDate != null && expireDate.isBefore(DateTime.now());

    final labelStyle = context.textTheme.labelMedium?.copyWith(
      color: Color.lerp(
        colorScheme.onSurfaceVariant,
        const Color(0xCCFFFFFF),
        filled,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          // 进度条长度要长过去，不能直接跳。订阅更新完流量数字是一步到位的，
          // 条子跟着瞬移会让人怀疑是不是读错了数。
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: Motion.slow,
            curve: Motion.move,
            builder: (_, value, _) => LinearProgressIndicator(
              minHeight: 6,
              value: value,
              color: barColor,
              backgroundColor: Color.lerp(
                colorScheme.surfaceContainerHighest,
                const Color(0x33FFFFFF),
                filled,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 用 Wrap 而不是 Row。右边这个「到期」在某些语言里非常长：没有到期日时
        // 显示的是 `infiniteTime`，俄语「Долгосрочное действие」21 个字符、英语
        // 「Long term effective」19 个。它在 Row 里没有 flex，会按自然宽度排，
        // 把左边的用量挤没了还要继续往外顶——320dp 小屏 + 1.4 倍字号下实测溢出。
        //
        // Wrap 给每个子项的宽度上限就是整行，放不下就落到下一行，不可能溢出；
        // 两个都放得下时 spaceBetween 的效果与原来的「左对齐 + 右对齐」完全一致，
        // 常见情况下看不出区别。换成 Flexible 五五开的话，正常长度的用量数字也会
        // 被打上省略号——多占一行比读不到数字划算。
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              '${use.traffic.show} / ${total.traffic.show}'
              '  ·  ${(ratio * 100).toStringAsFixed(0)}%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
            Text(
              expireShow,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 填充态下卡片整块是主色，错误色在上面同样糊；跟进度条一个口径，
              // 一起过渡到白色。
              style: isExpired
                  ? labelStyle?.copyWith(
                      color: Color.lerp(
                        colorScheme.error,
                        const Color(0xFFFFFFFF),
                        filled,
                      ),
                      fontWeight: FontWeight.w600,
                    )
                  : labelStyle,
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
