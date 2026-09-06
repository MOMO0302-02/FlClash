import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'connection/stream_motion.dart';

class LogsView extends ConsumerStatefulWidget {
  const LogsView({super.key});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView> with PageScrollController {
  /// 正文里取到的滚动控制器，缓存给回调用。
  ///
  /// **必须在正文的 builder 里取**：页面 `State.context` 在 `CommonScaffold`
  /// 外面，那儿取到的要么是 null、要么是外层页面的控制器（后者会让一个控制器被
  /// 两个滚动视图接上，读 `.position` 当场断言）。详见 [PageScrollController]。
  ScrollController? _liveController;

  ScrollController _bindController(BuildContext context) {
    final controller = pageScrollControllerOf(context);
    _liveController = controller;
    return controller;
  }

  ScrollController get _scrollController =>
      _liveController ?? pageScrollControllerOf(context);

  /// 打开就停在最新一条。
  ///
  /// 原来是靠 `ScrollController(initialScrollOffset: double.maxFinite)`。
  /// 协调层的 controller 不归本页所有，设不了初始位置，改成首帧之后跳到底。
  /// `hasClients` 要判——页面还没挂上滚动视图时 jumpTo 会抛。
  void _jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  final _logsStateNotifier = ValueNotifier<LogsState>(const LogsState());

  List<Log> _logs = [];

  @override
  void initState() {
    super.initState();
    _jumpToLatest();
    _logs = ref.read(logsProvider).list;
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(logs: _logs);
    ref.listenManual(logsProvider.select((state) => VM(state.list)), (
      prev,
      next,
    ) {
      if (prev != next) {
        final isEquality = logListEquality.equals(prev?.a, next.a);
        if (!isEquality) {
          _logs = next.a;
          updateLogsThrottler();
        }
      }
    });
  }

  List<Widget> _buildActions() {
    return [
      ValueListenableBuilder(
        valueListenable: _logsStateNotifier,
        builder: (context, state, _) {
          return _AutoScrollAction(
            enabled: state.autoScrollToEnd,
            onPressed: () {
              _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
                autoScrollToEnd: !_logsStateNotifier.value.autoScrollToEnd,
              );
            },
          );
        },
      ),
      IconButton(
        onPressed: () {
          _handleExport();
        },
        icon: const Icon(Icons.save_as_outlined),
      ),
    ];
  }

  void _onSearch(String value) {
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(query: value);
  }

  void _onKeywordsUpdate(List<String> keywords) {
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
      keywords: keywords,
    );
  }

  @override
  void dispose() {
    _logsStateNotifier.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.safeRun<bool>(() async {
      return globalState.container.read(logsProvider.notifier).exportLogs();
    }, title: appLocalizations.exportLogs);
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.exportSuccess),
    );
  }

  void updateLogsThrottler() {
    throttler.call(FunctionTag.logs, () {
      if (!mounted) {
        return;
      }
      final isEquality = logListEquality.equals(
        _logs,
        _logsStateNotifier.value.logs,
      );
      if (isEquality) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
            logs: _logs,
          );
        }
      });
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      actions: _buildActions(),
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      title: appLocalizations.logs,
      body: ValueListenableBuilder<LogsState>(
        valueListenable: _logsStateNotifier,
        builder: (context, state, _) {
          _bindController(context);
          final logs = state.list;
          return StreamEmptyOverlay(
            isEmpty: logs.isEmpty,
            empty: NullStatus(
              illustration: const LogEmptyIllustration(),
              label: appLocalizations.nullTip(appLocalizations.logs),
              description: appLocalizations.logsDesc,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ScrollToEndBox(
                onCancelToEnd: () {
                  _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
                    autoScrollToEnd: false,
                  );
                },
                controller: _scrollController,
                enable: state.autoScrollToEnd,
                dataSource: logs,
                child: CommonScrollBar(
                  controller: _scrollController,
                  // 这里**故意没有**逐条入场动画。日志没有稳定的唯一标识
                  // （`Log` 里那个 id 字段是被注释掉的，只能拿格式化后的
                  // 时间字符串当 key，同一毫秒的两条会撞），而且缓冲写满
                  // 之后每来一条就从头部挤掉一条，全部条目的下标跟着位移。
                  // 两条加在一起，「哪条是真的新来的」根本判不准——判错的
                  // 代价是每秒整屏重播一次入场，比不做动效糟得多。
                  child: SuperListView.builder(
                    physics: const NextClampingScrollPhysics(),
                    reverse: true,
                    shrinkWrap: true,
                    controller: _scrollController,
                    // 顶部要给悬浮胶囊让位（那段高度由 `MediaQuery.padding.top` 发下来）。
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 8,
                      bottom: 8,
                    ),
                    itemCount: logs.length,
                    itemBuilder: (_, index) {
                      final log = logs[index];
                      return LogItem(
                        key: Key(log.dateTime),
                        log: log,
                        onClick: (value) {
                          context.commonScaffoldState?.addKeyword(value);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 一条日志。
///
/// 形态照桌面端的 `components/logs/log-item.tsx`：一条一张圆角卡片，
/// 头部是「级别 + 时间」，正文是可选中的日志内容。原来是通栏平铺 + 整宽分隔线，
/// 那是 Material 的默认样子。
class LogItem extends StatelessWidget {
  final Log log;
  final Function(String)? onClick;

  const LogItem({super.key, required this.log, this.onClick});

  @override
  Widget build(BuildContext context) {
    // info 级在 LogLevelExt 里没有配色（返回 null），桌面端却把它画成 primary。
    // 拿不到级别色时回落到强调色，而不是让它变成一块无色的默认胶囊。
    final levelColor =
        log.logLevel.color(context) ??
        context.styleTokens.accent(context.colorScheme);
    return _LogCard(
      // 不给整行挂 onTap：原来是个空回调，按下去有水波纹却什么都不发生。
      // 真正可点的是级别胶囊（按级别过滤）和可选中的正文。
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 8,
              children: [
                _LogLevelPill(
                  label: log.logLevel.name,
                  color: levelColor,
                  onTap: onClick == null
                      ? null
                      : () => onClick!(log.logLevel.name),
                ),
                // 时间戳要能被挤：窄屏（360dp）上「级别 + 完整时间」放不下，
                // 定宽会当场溢出 7 像素。
                Expanded(
                  child: Text(
                    log.dateTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              log.payload,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「自动滚到最新」开关。
///
/// 桌面端把它放在工具栏（`pages/logs.tsx` 里那个定位图标按钮），开着是实心主色、
/// 关着是一圈描边；这里照搬。原来是右下角一个 Material 悬浮按钮——桌面端整个
/// 应用都没有悬浮按钮，而且它还会压住最新的那条记录。
class _AutoScrollAction extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _AutoScrollAction({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final tokens = context.styleTokens;
    final colorScheme = context.colorScheme;
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: enabled
            ? tokens.accent(colorScheme)
            : Colors.transparent,
        foregroundColor: enabled
            ? tokens.onAccent(colorScheme)
            : colorScheme.onSurfaceVariant,
        side: enabled
            ? BorderSide.none
            : BorderSide(color: colorScheme.onSurfaceVariant.opacity38),
      ),
      icon: const Icon(Icons.vertical_align_bottom),
    );
  }
}

/// 与 `views/connection/item.dart` 的 `StreamItemCard` 是同一个形态。
/// 之所以在这里再写一遍，是因为它该放进 `lib/widgets/`，而那是共享目录。
class _LogCard extends StatelessWidget {
  final Widget child;

  const _LogCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = context.styleTokens;
    final borderRadius = BorderRadius.circular(tokens.cardRadius);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: tokens.cardShadow,
          border: Border.all(color: tokens.rim, width: 1),
        ),
        child: Material(
          clipBehavior: Clip.antiAlias,
          color: context.colorScheme.surfaceContainerLow,
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}

/// 桌面端那种空心胶囊：透明底 + 一圈同色描边，不是灰底实心块。
class _LogLevelPill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _LogLevelPill({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(
      context.styleTokens.controlRadius,
    );
    // 这个胶囊是日志卡片上唯一可点的东西（按级别过滤），可它只有描边没有底色，
    // 深色背景上的水波纹几乎看不见——点下去和没点一个样。用 PressFeedback 而不是
    // PressableScale：它只观察指针、不抢手势，下面 InkWell 的 onTap 照常生效。
    return PressFeedback(
      scale: 0.92,
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: color.opacity60, width: 1),
            ),
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
