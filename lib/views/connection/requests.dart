import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'item.dart';
import 'stream_motion.dart';

/// 「自动滚到最新」开关，放在顶栏里。
///
/// 桌面端 `pages/logs.tsx` 就是工具栏上的一个图标按钮：开着实心主色、关着一圈
/// 描边。原来是右下角的 Material 悬浮按钮——桌面端全局都没有悬浮按钮，而且它会
/// 压住最新的那条记录。
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

class RequestsView extends ConsumerStatefulWidget {
  const RequestsView({super.key});

  @override
  ConsumerState<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends ConsumerState<RequestsView>
    with PageScrollController {
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

  final _requestsStateNotifier = ValueNotifier<TrackerInfosState>(
    const TrackerInfosState(),
  );
  List<TrackerInfo> _requests = [];

  /// 认「这一批里新冒出来的请求」，只有它们才淡入。
  final _fresh = StreamFreshTracker();

  void _onSearch(String value) {
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      query: value,
    );
  }

  void _onKeywordsUpdate(List<String> keywords) {
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      keywords: keywords,
    );
  }

  @override
  void initState() {
    super.initState();
    _jumpToLatest();
    _requests = ref.read(requestsProvider).list;
    _fresh.update(_requests.map((item) => item.id));
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      trackerInfos: _requests,
    );
    ref.listenManual(requestsProvider.select((state) => VM(state.list)), (
      prev,
      next,
    ) {
      _requests = next.a;
      updateRequestsThrottler();
    });
  }

  @override
  void dispose() {
    _requestsStateNotifier.dispose();
    super.dispose();
  }

  void updateRequestsThrottler() {
    throttler.call(FunctionTag.requests, () {
      if (!mounted) {
        return;
      }
      final isEquality = trackerInfoListEquality.equals(
        _requests,
        _requestsStateNotifier.value.trackerInfos,
      );
      if (isEquality) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // 必须先更新再赋值：赋值会同步触发重建，那时候界面就要问
          // 「这条新不新」了。
          _fresh.update(_requests.map((item) => item.id));
          _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
            trackerInfos: _requests,
          );
        }
      });
    }, duration: commonDuration);
  }

  Widget _buildList(BuildContext context, List<TrackerInfo> requests) {
    // 这个 context 在协调层内部，取到的才是对的那个控制器。
    _bindController(context);
    final appLocalizations = context.appLocalizations;
    // 请求会被前面挤掉（缓冲有上限），一挤下标就整体位移。没有这张表，
    // Flutter 只能按下标配对，配错的那些会被当成新条目整片重建。
    final indexById = <String, int>{
      for (var index = 0; index < requests.length; index++)
        requests[index].id: index,
    };
    return SuperListView.builder(
      reverse: true,
      shrinkWrap: true,
      physics: const NextClampingScrollPhysics(),
      controller: _scrollController,
      // 顶部要给悬浮胶囊让位（那段高度由 `MediaQuery.padding.top` 发下来）。
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 8,
        bottom: 8,
      ),
      itemCount: requests.length,
      findChildIndexCallback: (key) {
        final id = key is ValueKey<String> ? key.value : null;
        return id == null ? null : indexById[id];
      },
      itemBuilder: (_, index) {
        final trackerInfo = requests[index];
        return StreamItemEntrance(
          key: Key(trackerInfo.id),
          animate: _fresh.isFresh(trackerInfo.id),
          index: _fresh.isFirstBatch ? index : 0,
          child: TrackerInfoItem(
            trackerInfo: trackerInfo,
            onClickKeyword: (value) {
              context.commonScaffoldState?.addKeyword(value);
            },
            detailTitle: appLocalizations.details(appLocalizations.request),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      title: appLocalizations.requests,
      searchState: AppBarSearchState(onSearch: _onSearch),
      onKeywordsUpdate: _onKeywordsUpdate,
      actions: [
        ValueListenableBuilder(
          valueListenable: _requestsStateNotifier,
          builder: (context, state, _) {
            return _AutoScrollAction(
              enabled: state.autoScrollToEnd,
              onPressed: () {
                _requestsStateNotifier.value = _requestsStateNotifier.value
                    .copyWith(
                      autoScrollToEnd:
                          !_requestsStateNotifier.value.autoScrollToEnd,
                    );
              },
            );
          },
        ),
      ],
      body: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: _requestsStateNotifier,
        builder: (context, state, _) {
          final requests = state.list;
          // 同连接页：没启动时说清楚「要先启动」，而不是重复一遍这一页是干什么的。
          final isStart = ref.watch(isStartProvider);
          return StreamEmptyOverlay(
            isEmpty: requests.isEmpty,
            empty: NullStatus(
              label: appLocalizations.nullTip(appLocalizations.requests),
              description: isStart
                  ? appLocalizations.requestsDesc
                  : appLocalizations.streamNeedRunningDesc,
              illustration: const ConnectionEmptyIllustration(),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: CommonScrollBar(
                trackVisibility: false,
                controller: _scrollController,
                child: ScrollToEndBox(
                  controller: _scrollController,
                  dataSource: requests,
                  enable: state.autoScrollToEnd,
                  onCancelToEnd: () {
                    _requestsStateNotifier.value = _requestsStateNotifier.value
                        .copyWith(autoScrollToEnd: false);
                  },
                  child: _buildList(context, requests),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
