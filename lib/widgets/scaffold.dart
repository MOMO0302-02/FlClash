import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/widgets/pop_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'chip.dart';
import 'inherited.dart';
import 'theme.dart';

typedef OnKeywordsUpdateCallback = void Function(List<String> keywords);

typedef AppBarSearchStateBuilder =
    AppBarSearchState? Function(AppBarSearchState? state);

class CommonScaffold extends StatefulWidget {
  final AppBar? appBar;
  final Widget body;
  final Color? backgroundColor;
  final String? title;
  final bool isLoading;
  final List<Widget>? actions;
  final bool? centerTitle;
  final Widget? floatingActionButton;
  final bool? isTV;
  final AppBarEditState? editState;
  final AppBarSearchState? searchState;
  final OnKeywordsUpdateCallback? onKeywordsUpdate;
  final bool? resizeToAvoidBottomInset;

  const CommonScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.title,
    this.actions,
    this.centerTitle,
    this.editState,
    this.isLoading = false,
    this.searchState,
    this.floatingActionButton,
    this.isTV,
    this.onKeywordsUpdate,
    this.resizeToAvoidBottomInset,
  });

  @override
  State<CommonScaffold> createState() => CommonScaffoldState();
}

class CommonScaffoldState extends State<CommonScaffold> {
  late final ValueNotifier<AppBarState> _appBarState;
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isFabExtendedNotifier = ValueNotifier(true);

  final ValueNotifier<List<String>> _keywordsNotifier = ValueNotifier([]);
  final _textController = TextEditingController();

  bool get _isSearch {
    return _appBarState.value.searchState?.query != null;
  }

  bool get _isEdit {
    final editState = _appBarState.value.editState;
    if (editState == null) {
      return false;
    }
    return editState.editCount > 0;
  }

  @override
  void initState() {
    super.initState();
    _appBarState = ValueNotifier(
      AppBarState(editState: widget.editState, searchState: widget.searchState),
    );
    _loadingNotifier.value = widget.isLoading;
  }

  Future<void> _updateSearchState(AppBarSearchStateBuilder builder) async {
    _appBarState.value = _appBarState.value.copyWith(
      searchState: builder(_appBarState.value.searchState),
    );
  }

  void handleToSearch() {
    _updateSearchState((state) => state?.copyWith(query: ''));
  }

  Widget _buildSearchingAppBarTheme(Widget child) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          // 原来写死 grey[900]/white，在纯黑底的主题上会突然冒出一块中性灰。
          // 搜索态该做的是「比页面底提一档」，交给配色里的容器层。
          backgroundColor: colorScheme.surfaceContainer,
          iconTheme: theme.primaryIconTheme.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          titleTextStyle: theme.textTheme.titleLarge,
          toolbarTextStyle: theme.textTheme.bodyMedium,
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: theme.inputDecorationTheme.hintStyle,
          border: InputBorder.none,
        ),
      ),
      child: child,
    );
  }

  @override
  void didUpdateWidget(CommonScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editState != widget.editState) {
      _appBarState.value = _appBarState.value.copyWith(
        editState: widget.editState,
      );
    }
    if (oldWidget.searchState != widget.searchState) {
      _appBarState.value = _appBarState.value.copyWith(
        searchState: widget.searchState,
      );
    }
    if (oldWidget.isLoading != widget.isLoading) {
      _loadingNotifier.value = widget.isLoading;
    }
  }

  void _handleClearInput() {
    _textController.text = '';
    if (_appBarState.value.searchState != null) {
      _appBarState.value.searchState!.onSearch('');
    }
  }

  void _handleClear() {
    if (_textController.text.isNotEmpty) {
      _handleClearInput();
      return;
    }
    _popAppBarLayer();
  }

  void handleExitSearching() {
    if (!_isSearch) {
      return;
    }
    _handleClearInput();
    _updateSearchState((state) => state?.copyWith(query: null));
  }

  void _handleExitAppBarLayer() {
    handleExitSearching();
    if (_isEdit) {
      _appBarState.value.editState?.onExit();
    }
  }

  void _popAppBarLayer() {
    if (!_isEdit && !_isSearch) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _appBarState.dispose();
    _textController.dispose();
    _isFabExtendedNotifier.dispose();
    _loadingNotifier.dispose();
    // 漏了它：搜索关键词的 notifier 一直没被释放，每开一个带搜索的页面就留一个。
    _keywordsNotifier.dispose();
    super.dispose();
  }

  void addKeyword(String keyword) {
    final isContains = _keywordsNotifier.value.contains(keyword);
    if (isContains) return;
    final keywords = List<String>.from(_keywordsNotifier.value)..add(keyword);
    _keywordsNotifier.value = keywords;
  }

  void _deleteKeyword(String keyword) {
    final isContains = _keywordsNotifier.value.contains(keyword);
    if (!isContains) return;
    final keywords = List<String>.from(_keywordsNotifier.value)
      ..remove(keyword);
    _keywordsNotifier.value = keywords;
  }

  Widget? _buildLeading(VoidCallback? backAction) {
    if (_isEdit) {
      return IconButton(
        onPressed: _popAppBarLayer,
        icon: const Icon(Icons.close),
      );
    }
    if (_isSearch) {
      return IconButton(
        onPressed: _popAppBarLayer,
        icon: const Icon(Icons.arrow_back),
      );
    }
    if (backAction != null) {
      return BackButton(
        onPressed: () {
          if (!mounted) {
            return;
          }
          backAction();
        },
      );
    }
    // **能返回就给个返回键。**
    //
    // 原来这一层返回 null，由 `AppBar(automaticallyImplyLeading: true)` 自己补。
    // 现在标题栏是会被滚走的 sliver，返回键改成单独固定在最上层，那条 sliver 的
    // 自动补齐关掉了——这里不补的话，**被推入的页面就完全没有返回键**。
    // 判据用 `impliesAppBarDismissal`，**不用 `canPop()`**：前者正是 `AppBar` 的
    // `automaticallyImplyLeading` 内部用的那个，换成它才和改造之前的行为逐条一致。
    // `canPop()` 宽得多——只要栈里不止一条路由就为真，搜索态那种"压了一层但不该
    // 显示返回键"的场合会多冒出一个按钮（实测撞红了 scaffold_leading_test）。
    return ModalRoute.of(context)?.impliesAppBarDismissal ?? false
        ? const BackButton()
        : null;
  }

  Widget _buildTitle(AppBarSearchState? startState) {
    final appLocalizations = context.appLocalizations;
    return _isSearch
        ? TextField(
            autofocus: true,
            controller: _textController,
            inputFormatters: TextInputLimits.limit(TextInputLimits.search),
            style: context.textTheme.titleLarge,
            onChanged: (value) {
              if (startState != null) {
                startState.onSearch(value);
              }
            },
            decoration: InputDecoration(hintText: appLocalizations.search),
          )
        : Text(
            !_isEdit
                ? widget.title!
                : appLocalizations.selectedCountTitle(
                    '${_appBarState.value.editState?.editCount ?? 0}',
                  ),
            // 标题过长时省略，别顶进右侧的操作按钮。
            //
            // AppBar 会给标题留出扣掉 leading 和 actions 之后的宽度，但标题
            // Text 本身不设溢出策略时，中文标题 + 右侧几个图标按钮在窄屏上仍会
            // 挤在一起。加上 maxLines:1 + 省略号，标题该短就短，不抢按钮的位置。
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
  }

  List<Widget> _buildActions(bool hasSearch, List<Widget> actions) {
    if (_isSearch) {
      return genActions([
        IconButton(onPressed: _handleClear, icon: const Icon(Icons.close)),
      ]);
    }
    // 右侧这一排（搜索、⋮、刷新……）和左边的返回键同样会被内容滚过，一并垫底。
    // 逐个包，而不是给整排包一层：整排包出来是个胶囊，按钮之间的空隙也被填上，
    // 看不出是几个按钮。
    return genActions([
      if (hasSearch && widget.searchState?.autoAddSearch == true)
        IconButton(
          onPressed: () {
            _updateSearchState((state) => state?.copyWith(query: ''));
          },
          icon: const Icon(Icons.search),
        ),
      ...actions,
    ]);
  }

  Widget _buildAppBarWrap(Widget child) {
    final appBar = _isSearch ? _buildSearchingAppBarTheme(child) : child;
    if (_isEdit || _isSearch) {
      return BackLayerScope(onBack: _handleExitAppBarLayer, child: appBar);
    }
    return appBar;
  }

  /// 固定顶栏：通栏、贴顶、和页面同底色，底下一条分隔线。
  ///
  /// **照抄桌面端** `components/base/base-page.tsx:48-74`：
  /// ```
  /// sticky top-0 h-12.25 w-full bg-background   ← 通栏、贴顶、同底色
  ///   └ p-2 flex justify-between h-12            ← 48 高、8 内边距
  ///       └ title: text-lg leading-8             ← 18 号、左对齐、不加粗
  ///   └ <Divider />                              ← 分隔线划界
  /// content: overflow-y-auto                     ← 内容独立滚动区
  /// ```
  ///
  /// **为什么撤掉了上一版的悬浮胶囊**（三个问题都出自"浮起来"这一个决定）：
  /// 1. 胶囊左右各留 12dp 边距，内容从那两条缝里露出来，滚动时文字在胶囊两侧闪；
  /// 2. 内容从胶囊底下穿过 → 每个页面都得自己记得留出胶囊高度，漏了不报错、只是
  ///    第一项被压住半截。八个设置页曾同时漏掉，全靠用户截图才发现；
  /// 3. 底色和页面一样却又浮着，说不清它是"一层"还是"页面的一部分"。
  ///
  /// 通栏 + 分隔线把这三条一起消掉：没有缝、内容天然从顶栏下方开始、分隔线明确
  /// 划界。**顶栏固定不动**——返回键、搜索、⋮、刷新都在里面，跟着内容滚走的话
  /// 这些按钮会一起消失。
  ///
  /// 唯一偏离桌面端的地方：**要避开状态栏**。桌面端没有状态栏，这是手机的物理
  /// 约束，不算偏离设计。
  Widget _buildTopBar(VoidCallback? backAction) {
    return ValueListenableBuilder<AppBarState>(
      valueListenable: _appBarState,
      builder: (_, state, _) {
        final leading = _buildLeading(backAction);
        return _buildAppBarWrap(
          _TopBarSurface(
            child: Row(
              children: [
                // 没有返回键时补一点左内边距，标题不至于贴着屏幕边缘。
                if (leading != null) leading else const SizedBox(width: 16),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: Theme.of(context).appBarTheme.titleTextStyle,
                    child: _buildTitle(state.searchState),
                  ),
                ),
                ..._buildActions(
                  state.searchState != null,
                  state.actions.isNotEmpty
                      ? state.actions
                      : widget.actions ?? [],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.appBar != null || widget.title != null);
    final backActionProvider = CommonScaffoldBackActionProvider.of(context);
    final isTV = widget.isTV ?? system.isTV;
    final body = SafeArea(
      // **不避顶部。** `SliverAppBar` 默认 `primary: true`，已经把状态栏高度算进
      // 自己的高度里了；这里再避一次，标题栏和内容之间就会多出一条状态栏那么高的
      // 空白，而且它加在滚动视图**外面**，滚动时不会跟着走——标题栏都滚没了它还
      // 杵在那儿。用户看到的「每个页面顶层还是有横条」就是它。
      //
      // 左右和底部仍然要避：刘海屏的圆角、底部手势条。
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTV && widget.floatingActionButton != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: CommonScaffoldFabExtendedProvider(
                isExtended: true,
                child: widget.floatingActionButton!,
              ),
            ),
          ValueListenableBuilder(
            valueListenable: _keywordsNotifier,
            builder: (_, keywords, _) {
              if (widget.onKeywordsUpdate != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onKeywordsUpdate!(keywords);
                });
              }
              if (keywords.isEmpty) {
                return const SizedBox();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    for (final keyword in keywords)
                      CommonChip(
                        label: keyword,
                        type: ChipType.delete,
                        onPressed: () {
                          _deleteKeyword(keyword);
                        },
                      ),
                  ],
                ),
              );
            },
          ),
          Expanded(child: widget.body),
        ],
      ),
    );
    // 所有页面都从这里长出来，控件主题挂在这一层就等于全局生效，
    // 不用每个页面各自记得包一层。
    final backAction = backActionProvider?.backAction;
    return CommonControlTheme(
      child: Scaffold(
        // **没有 appBar。** 用 `Scaffold.appBar` 拿不到"顶栏和内容同底色 + 底下
        // 一条分隔线"这个构造，而且它会强行给标题居中/加粗一套 Material 默认样式。
        // 自己叠一条更省事，桌面端也是自己写的。
        body: NotificationListener<ScrollNotification>(
          // **只认最外层那个滚动**：页面里常有横向列表、内嵌小列表，它们的滚动
          // 不该影响右下角悬浮按钮的展开收起。
          onNotification: (notification) {
            if (notification.depth != 0) {
              return false;
            }
            if (notification is UserScrollNotification) {
              if (notification.direction == ScrollDirection.reverse) {
                _isFabExtendedNotifier.value = false;
              } else if (notification.direction == ScrollDirection.forward) {
                _isFabExtendedNotifier.value = true;
              }
            }
            return false;
          },
          child: widget.appBar != null
              // 少数页面自带完整顶栏（比如底部弹层），照旧。
              ? Column(
                  children: [
                    widget.appBar!,
                    Expanded(child: body),
                  ],
                )
              // **顶栏在上、内容在下，上下两段，不叠加。**
              //
              // 这是照桌面端 `base-page.tsx` 的结构：`sticky` 顶栏 + 独立滚动的
              // 内容区。内容天然从顶栏下方开始，所以**没有任何页面需要知道顶栏
              // 多高**——上一版的悬浮胶囊要求每个页面自己留出高度，八个设置页曾
              // 同时漏掉，漏了还不报错。
              : Column(
                  children: [
                    _buildTopBar(backAction),
                    // 加载进度条贴在分隔线上，通栏宽度。
                    ValueListenableBuilder(
                      valueListenable: _loadingNotifier,
                      builder: (_, value, _) {
                        // **必须占位**：高度在有无之间跳变会把整块内容顶上顶下。
                        return SizedBox(
                          height: 4,
                          child: value == true
                              ? const LinearProgressIndicator(minHeight: 4)
                              : null,
                        );
                      },
                    ),
                    Expanded(child: body),
                  ],
                ),
        ),
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
        backgroundColor: widget.backgroundColor,
        floatingActionButton: !isTV && widget.floatingActionButton != null
            ? ValueListenableBuilder<bool>(
                valueListenable: _isFabExtendedNotifier,
                builder: (_, isExtended, child) {
                  return CommonScaffoldFabExtendedProvider(
                    isExtended: isExtended,
                    child: child!,
                  );
                },
                child: widget.floatingActionButton,
              )
            : null,
      ),
    );
  }
}

List<Widget> genActions(List<Widget> actions, {double? space}) {
  return <Widget>[
    ...actions.separated(SizedBox(width: space ?? 4)),
    const SizedBox(width: 8),
  ];
}

class BaseScaffold extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget body;

  const BaseScaffold({
    super.key,
    required this.title,
    this.actions = const [],
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(body: body, title: title, actions: actions);
  }
}

/// 固定顶栏的材质：通栏、和页面同底色、底下一条分隔线。
///
/// 照抄桌面端 `components/base/base-page.tsx:48-74`：`bg-background` 同底色 +
/// `<Divider />` 划界。**不投影、不提亮**——分隔线已经把界划清楚了，再叠阴影会
/// 让这条栏看起来是浮起来的，那正是上一版悬浮胶囊的毛病。
///
/// **要避开状态栏**，这是唯一偏离桌面端的地方（桌面端没有状态栏）。
///
/// **不上液态玻璃。** 玻璃只给"浮在内容之上、内容从底下穿过"的面用；这条栏和
/// 内容是上下两段，背后什么都没有，模糊出来是一片纯色，白付一份逐帧重采样的开销。
class _TopBarSurface extends StatelessWidget {
  const _TopBarSurface({required this.child});

  /// 给测试用的定位点。
  ///
  /// **不用 `find.byType(Container)`**：`Container` 带 margin 时会在外面套一层
  /// `Padding`，而 `getRect` 量到的是**含 margin 的外框**——于是"有人给顶栏加了
  /// 左右边距"这种回归，按 Container 量根本量不出来（实测变异验不红）。
  /// 挂 key 到真正画底色和分隔线的那个盒子上，量到的才是**画出来的范围**。
  static const surfaceKey = ValueKey('top-bar-surface');

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.styleTokens;
    return DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(bottom: BorderSide(color: tokens.topBarDividerOf(context))),
      ),
      child: Padding(
        // 顶栏自己吃掉状态栏高度：内容从它下方开始，不会怼进状态栏。
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: SizedBox(height: kAppBarToolbarHeight, child: child),
      ),
    );
  }
}

