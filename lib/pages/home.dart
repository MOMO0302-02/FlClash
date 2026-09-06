import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/manager/app_manager.dart';
import 'package:clash_party/models/common.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef OnSelected = void Function(int index);

/// 手机上的根页面：磁贴主页，只有它不该有返回键。
const _rootPageLabel = PageLabel.dashboard;

/// 写成顶层函数而不是内联闭包：`CommonScaffoldBackActionProvider` 按回调的
/// 身份判断要不要通知下游，每次 build 新建闭包会让每个页面白白重建一次。
void _backToRootPage() {
  globalState.container
      .read(currentPageLabelProvider.notifier)
      .toPage(_rootPageLabel);
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasViewSize = ref.watch(
      viewSizeProvider.select((size) => !size.isEmpty),
    );
    if (!hasViewSize) {
      return const SizedBox.shrink();
    }
    return HomeBackScopeContainer(
      child: AppSidebarContainer(
        child: Material(
          color: context.colorScheme.surface,
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(navigationStateProvider);
              final isMobile = state.viewMode == ViewMode.mobile;
              // 手机上不要任何常驻导航栏：主页就是一堵磁贴，点磁贴进二级页面。
              // 这是 Clash Party 桌面版的形态——侧边一列卡片，点了才展开右侧内容。
              // 顶部分段栏和底部标签栏都撤掉了，桌面端仍然走左侧 NavigationRail。
              return FocusTraversalGroup(
                policy: PageTraversalPolicy(),
                child: MediaQuery.removePadding(
                  // 页面自己会用 SafeArea 吃掉状态栏边距，这边再加一次就会在
                  // 顶上多出一大块空白。
                  removeTop: false,
                  removeBottom: isMobile,
                  removeLeft: isMobile,
                  removeRight: isMobile,
                  context: context,
                  child: child!,
                ),
              );
            },
            child: Consumer(
              builder: (_, ref, _) {
                final navigationItems = ref
                    .watch(currentNavigationItemsStateProvider)
                    .value;
                final isMobile = ref.watch(isMobileViewProvider);
                return _HomePageView(
                  navigationItems: navigationItems,
                  pageBuilder: (_, index) {
                    final navigationItem = navigationItems[index];
                    final navigationView = navigationItem.builder(context);
                    final Widget scopedView = PageFocusScope(
                      child: navigationView,
                    );
                    // 手机上没有常驻导航栏，页面之间只能靠切页——导入订阅后
                    // 自动跳到配置页就是这么走的。切过去的页面不是压栈出来的，
                    // AppBar 补不出返回键，用户会被困在那一页（系统返回还会直接
                    // 退出应用）。把「回仪表盘」交给 CommonScaffold 去画。
                    final hasRootPage = navigationItems.any(
                      (item) => item.label == _rootPageLabel,
                    );
                    final pagedView =
                        isMobile &&
                            hasRootPage &&
                            navigationItem.label != _rootPageLabel
                        ? CommonScaffoldBackActionProvider(
                            backAction: _backToRootPage,
                            child: scopedView,
                          )
                        : scopedView;
                    final view = KeepScope(
                      key: ValueKey(navigationItem.label),
                      keep: navigationItem.keep,
                      child: isMobile
                          ? pagedView
                          : Navigator(
                              key: ValueKey(
                                '${navigationItem.label.name}_navigator',
                              ),
                              pages: [MaterialPage(child: scopedView)],
                              onDidRemovePage: (_) {},
                            ),
                    );
                    return Consumer(
                      key: ValueKey(navigationItem.label),
                      builder: (_, ref, child) {
                        final isActive = ref.watch(
                          currentPageLabelProvider.select(
                            (label) => label == navigationItem.label,
                          ),
                        );
                        return PageActivityScope(
                          isActive: isActive,
                          child: ExcludeFocus(
                            excluding: !isActive,
                            child: child!,
                          ),
                        );
                      },
                      child: view,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    final pageLabel = ref.read(currentPageLabelProvider);
    return widget.navigationItems.indexWhere((item) => item.label == pageLabel);
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    final isMobile = ref.read(isMobileViewProvider);
    if (isAnimateToPage && isMobile && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(
      currentNavigationItemsStateProvider.select((state) => state.value.length),
    );
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<PageLabel>) {
          return null;
        }
        final index = widget.navigationItems.indexWhere(
          (item) => item.label == key.value,
        );
        return index == -1 ? null : index;
      },
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
  }
}

class HomeBackScopeContainer extends ConsumerWidget {
  final Widget child;

  const HomeBackScopeContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context, ref) {
    return CommonPopScope(
      onPop: (context) async {
        final pageLabel = ref.read(currentPageLabelProvider);
        final realContext =
            GlobalObjectKey(pageLabel).currentContext ?? context;
        final canPop = Navigator.canPop(realContext);
        if (canPop) {
          Navigator.of(realContext).pop();
          return false;
        }
        // 切页进来的二级页面栈上是空的，照原样走 handleClose 等于「按返回直接
        // 退出应用」。手机上没有别的回退入口，先退回仪表盘。
        if (ref.read(isMobileViewProvider) && pageLabel != _rootPageLabel) {
          _backToRootPage();
          return false;
        }
        await globalState.container
            .read(systemActionProvider.notifier)
            .handleClose();
        return false;
      },
      child: child,
    );
  }
}
