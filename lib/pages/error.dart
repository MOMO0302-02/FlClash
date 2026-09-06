import 'dart:io';

import 'package:clash_party/application.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/hero_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 启动失败时唯一能看到的界面。
///
/// 两条硬性约束，改这个文件时别破坏：
///
/// 1. **不能依赖任何已初始化的全局状态**。它出现的时机正是 `globalState.init`
///    抛异常之后：`globalState.theme` / `globalState.measure` 还没赋值，
///    `AppLocalizations.current` 会直接断言失败。所以这里不用 `CommonCard`、
///    `ListItem` 这类组件（它们读 `globalState`），文案也一律写死英文。
/// 2. **堆栈必须能选中、能复制**。用户就是靠把这段贴给我们才说得清发生了什么。
///
/// 观感自己撑起来：`main.dart` 用的是裸 `MaterialApp`，拿到的是 Material 默认的
/// 浅色紫主题，和应用本体完全不是一路。所以这里自己按 Clash Party 的取值
/// 造一份深色主题挂上去，下面的子树才能照常用 `context.colorScheme`。
class InitErrorScreen extends StatefulWidget {
  final Object error;
  final StackTrace stack;

  const InitErrorScreen({super.key, required this.error, required this.stack});

  @override
  State<InitErrorScreen> createState() => _InitErrorScreenState();
}

class _InitErrorScreenState extends State<InitErrorScreen> {
  late Object _error = widget.error;
  late StackTrace _stack = widget.stack;
  bool _retrying = false;

  String get _details =>
      '=== ERROR ===\n$_error\n\n=== STACK TRACE ===\n$_stack';

  /// 再走一遍启动流程。启动失败常常是一次性的（文件被占用、数据库正忙），
  /// 让用户能自己重试一次，比只能杀进程重开强。
  ///
  /// 故意不重复 `main.dart` 里的 `RustLib.init()`：那是桌面端的一次性初始化，
  /// 重复调用只会再抛一次；安卓端根本不走那条路。
  Future<void> _handleRetry() async {
    setState(() {
      _retrying = true;
    });
    try {
      final version = await system.init();
      final container = await globalState.init(version);
      // 和 main.dart 保持一致：这行是在 init 成功之后才执行的，
      // 走到崩溃页说明它从没跑过，重试时必须补上，否则整个应用的
      // HTTP 请求都不走自己那套配置。
      HttpOverrides.global = ClashPartyHttpOverrides();
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const Application(),
        ),
      );
    } catch (e, s) {
      if (!mounted) {
        return;
      }
      // 重试又炸了就把新的错误换上去——继续显示上一次的错误会误导排查。
      setState(() {
        _error = e;
        _stack = s;
        _retrying = false;
      });
    }
  }

  // 必须用 Theme 里面那层 context：State 自己的 context 在 Theme 之上，
  // 取到的还是 Material 默认的浅色配色。
  void _handleCopy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _details));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.colorScheme.surfaceContainerHigh,
      ),
    );
  }

  ThemeData _buildTheme() {
    final tokens = context.styleTokens;
    final scheme = ColorScheme.fromSeed(
      seedColor: tokens.seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: tokens.schemeVariant,
    );
    return ThemeData(
      colorScheme: tokens.darkSurfaces?.applyTo(scheme) ?? scheme,
      extensions: [tokens],
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _buildTheme(),
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildSection(
                    context: context,
                    label: 'ERROR',
                    child: SelectableText(
                      _error.toString(),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context: context,
                    label: 'STACK TRACE',
                    child: SelectableText(
                      _stack.toString(),
                      style: TextStyle(
                        fontFamily: FontFamily.jetBrainsMono.value,
                        fontSize: 12,
                        height: 1.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = context.colorScheme;
    final tokens = context.styleTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: ShapeDecoration(
            color: colorScheme.errorContainer,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(tokens.controlRadius),
            ),
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.onErrorContainer,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Startup failed',
                style: context.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The app could not finish starting up. '
                'Retry below, or copy the details and report them.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 「一行小灰字标题 + 圆角卡片」，和设置页的 `generateSection` 同一个形状。
  /// 这里手写而不复用，是因为那套组件会读还没初始化好的 `globalState`。
  Widget _buildSection({
    required BuildContext context,
    required String label,
    required Widget child,
  }) {
    final colorScheme = context.colorScheme;
    final tokens = context.styleTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.cardRadius),
            boxShadow: tokens.cardShadow,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: ShapeDecoration(
              color: colorScheme.surfaceContainerLow,
              shape: RoundedSuperellipseBorder(
                side: BorderSide(color: tokens.rim),
                borderRadius: BorderRadius.circular(tokens.cardRadius),
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final colorScheme = context.colorScheme;
    final tokens = context.styleTokens;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(tokens.controlRadius),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _handleCopy(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: shape,
                foregroundColor: colorScheme.onSurface,
                backgroundColor: colorScheme.surfaceContainerLow,
                side: BorderSide(color: tokens.rim),
              ),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
            ),
          ),
          Expanded(
            child: FilledButton.icon(
              onPressed: _retrying ? null : _handleRetry,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: shape,
                backgroundColor: tokens.accent(colorScheme),
                foregroundColor: tokens.onAccent(colorScheme),
              ),
              icon: _retrying
                  ? SizedBox.square(
                      dimension: 18,
                      child: HeroSpinner(
                        strokeWidth: 2,
                        color: tokens.onAccent(colorScheme),
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
