import 'dart:math';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/providers/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';

/// 通用对话框。
///
/// Material 默认的 `AlertDialog` 是「带 surfaceTint 染色的底 + 28 圆角 + 阴影」，
/// 在纯黑底上一眼就能看出是 Material。这里改成和主界面卡片同一套：深灰卡片色、
/// 一圈很淡的白色描边（rim）、卡片圆角，并且不让 surfaceTint 往上染色。
/// 里面的输入框与按钮由 [CommonControlTheme] 统一，调用方不用各自传样式。
class CommonDialog extends ConsumerWidget {
  final String title;
  final Widget? child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final bool overrideScroll;
  final Color? backgroundColor;

  const CommonDialog({
    super.key,
    required this.title,
    this.actions,
    this.child,
    this.padding,
    this.overrideScroll = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, ref) {
    final size = ref.watch(viewSizeProvider);
    final tokens = context.styleTokens;
    final colorScheme = context.colorScheme;
    return CommonControlTheme(
      child: AlertDialog(
        title: Text(title),
        actions: actions,
        contentPadding: padding,
        backgroundColor: backgroundColor ?? colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: context.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: BorderSide(color: tokens.rim),
        ),
        content: Container(
          constraints: BoxConstraints(
            maxHeight: min(size.height - 40, 500),
            maxWidth: 300,
          ),
          width: size.width - 40,
          child: !overrideScroll ? SingleChildScrollView(child: child) : child,
        ),
      ),
    );
  }
}

class CommonModal extends ConsumerWidget {
  final Widget? child;

  const CommonModal({super.key, this.child});

  @override
  Widget build(BuildContext context, ref) {
    final size = ref.watch(viewSizeProvider);
    return Center(
      child: Container(
        width: size.width * 0.85,
        height: size.height * 0.85,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(context.styleTokens.cardRadius),
          border: Border.all(color: context.styleTokens.rim),
          boxShadow: context.styleTokens.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
