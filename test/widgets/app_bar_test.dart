import 'package:clash_party/application.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// 页面顶栏：**通栏、贴顶、和页面同底色，底下一条分隔线**。
///
/// ## 这个形态是照抄桌面端的，中间走过四轮弯路
///
/// 桌面端 `components/base/base-page.tsx:48-74`：
/// ```
/// sticky top-0 h-12.25 w-full bg-background   ← 通栏、贴顶、同底色
///   └ p-2 flex justify-between h-12            ← 48 高、8 内边距
///       └ title: text-lg leading-8             ← 18 号、左对齐、不加粗
///   └ <Divider />                              ← 分隔线划界
/// content: overflow-y-auto                     ← 内容独立滚动区
/// ```
///
/// 走过的弯路，每一条都别再走回去：
///
/// 1. **56 高、22 号的通栏** —— 用户：「每个页面的顶部标题栏太大了」。
///    桌面端是 48 高、18 号。
/// 2. **标题淡出、栏留在原地** —— 半成品：48 像素的空条还占着。
/// 3. **整条栏随内容滚走** —— 搜索、⋮、刷新跟着一起消失，得往回滚才能用；
///    而且内容顶进了状态栏，截图里时间和列表项叠在一起。
/// 4. **悬浮胶囊**（上一版）—— 用户：「我觉得现在这样还是很怪」。三个毛病都出自
///    "浮起来"这一个决定：胶囊左右各留 12dp，内容从那两条缝里露出来滚动时闪；
///    内容从胶囊底下穿过 → 每个页面得自己留出胶囊高度，八个设置页曾同时漏掉、
///    漏了还不报错；底色和页面一样却又浮着，说不清它是一层还是页面的一部分。
///
/// **最终形态**：通栏 + 分隔线。没有缝、内容天然从顶栏下方开始、分隔线明确划界。
/// 顶栏固定不动，按钮永远可用。
void main() {
  Widget page() => CommonScaffold(
    title: '仪表盘',
    body: ListView.builder(
      itemCount: 60,
      itemBuilder: (_, index) => SizedBox(height: 60, child: Text('$index')),
    ),
  );

  /// [statusBar] 模拟状态栏高度。真机上一定不为 0，而「内容怼进状态栏」这类问题
  /// 在 0 的环境里根本复现不出来。
  ///
  /// [pushed] 为真时页面是被推上来的，`canPop()` 成立，才有返回按钮可验。
  /// 用 `initialRoute: '/second'`：Flutter 会按路径逐段建栈（先 `/` 再 `/second`）。
  Future<void> pump(
    WidgetTester tester, {
    bool pushed = false,
    double statusBar = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          globalState.theme = CommonTheme.of(context, 1);
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: EdgeInsets.only(top: statusBar)),
            child: child!,
          );
        },
        // 高度和字号挂在主题上，测试必须走同一份主题，不能自己拼一个。
        theme: ThemeData(
          useMaterial3: true,
          appBarTheme: ApplicationState.appBarThemeOf(
            ColorScheme.fromSeed(seedColor: const Color(0xFF006FEE)),
          ),
        ),
        initialRoute: pushed ? '/second' : '/',
        routes: {
          '/': (_) =>
              pushed ? const Scaffold(body: SizedBox.shrink()) : page(),
          '/second': (_) => page(),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 装标题那一行的那个盒子（不含状态栏那段内边距）。
  Rect titleRowRect(WidgetTester tester) {
    return tester.getRect(
      find.ancestor(of: find.text('仪表盘'), matching: find.byType(SizedBox)).first,
    );
  }

  /// 整条顶栏画出来的范围（含它自己吃掉的状态栏高度和底部分隔线）。
  ///
  /// **按 key 找，不按类型找。** 按 `find.byType(Container)` 量的是含 margin 的
  /// 外框，"有人给顶栏加了左右边距"这种回归量不出来（第一版这么写，变异验不红）。
  Finder topBarFinder() => find.byKey(const ValueKey('top-bar-surface'));

  Rect topBarRect(WidgetTester tester) => tester.getRect(topBarFinder());

  testWidgets('顶栏高度和标题字号对齐桌面端', (tester) async {
    await pump(tester);

    // **期望值写死 48 / 18**，不引用产品代码里的常量——引用的话改了常量两边一起
    // 变，变异测试当场验不红（早先就是这么写的，验红时露馅）。
    // 出处：桌面端 `base-page.tsx:48` 的 `h-12`、`:50` 的 `text-lg`。
    expect(titleRowRect(tester).height, 48.0, reason: '顶栏高度不是 48 了');

    final title = tester.widget<Text>(find.text('仪表盘'));
    final style = DefaultTextStyle.of(
      tester.element(find.text('仪表盘')),
    ).style.merge(title.style);
    expect(style.fontSize, 18.0, reason: '标题字号不是 18 了');
    expect(style.fontSize, isNot(22.0), reason: '又回到 Material 默认的 22 了');
  });

  testWidgets('顶栏通栏、贴顶，左右两侧不留缝', (tester) async {
    await pump(tester, statusBar: 40);

    final screen = tester.getRect(find.byType(MaterialApp));
    final bar = topBarRect(tester);

    // **来历**：上一版是悬浮胶囊，左右各留 12dp 边距，页面内容从那两条缝里露出来，
    // 滚动时文字在胶囊两侧闪。桌面端是 `w-full`，通栏。
    expect(bar.left, screen.left, reason: '顶栏左边留了缝，内容会从那里露出来');
    expect(bar.right, screen.right, reason: '顶栏右边留了缝');
    expect(bar.top, screen.top, reason: '顶栏没有贴顶');
  });

  testWidgets('顶栏自己吃掉状态栏，标题落在状态栏下方', (tester) async {
    await pump(tester, statusBar: 40);

    final titleRow = titleRowRect(tester);

    // **来历**：更早一版让整条栏滚走、内容顶到屏幕最上面，用户截图里状态栏的时间
    // 和列表项叠在一起。顶栏自己吃掉状态栏高度就不会再出现这个问题。
    expect(
      titleRow.top,
      greaterThanOrEqualTo(40),
      reason: '标题行顶边在 ${titleRow.top}，压进了 40 高的状态栏',
    );
  });

  testWidgets('内容从顶栏下方开始，不需要页面自己留高度', (tester) async {
    await pump(tester, statusBar: 40);

    final bar = topBarRect(tester);
    final firstItem = tester.getRect(find.text('0'));

    // **这条是撤掉悬浮胶囊的核心收益。** 上一版内容从胶囊底下穿过，于是每个页面
    // 都得自己在顶部留出胶囊高度；漏了不报错、只是第一项被压住半截，八个设置页
    // 曾同时漏掉。改成上下两段之后，内容天然从顶栏下方开始。
    expect(
      firstItem.top,
      greaterThanOrEqualTo(bar.bottom - 1),
      reason:
          '内容从 ${firstItem.top} 开始，而顶栏底边在 ${bar.bottom}'
          '——内容不该压在顶栏底下',
    );
  });

  testWidgets('内容是顶栏下方的独立滚动区，滚动时不侵入顶栏', (tester) async {
    await pump(tester, statusBar: 40);

    final bar = topBarRect(tester);

    // **量滚动视口本身，不量里面的条目。** `ListView` 会把视口外的一段也留在
    // widget 树里（cacheExtent），对那些条目取 `getRect` 拿到的是它们的逻辑位置，
    // 可以在视口上方——按条目断言会得到"内容跑到顶栏上面去了"的假结论。
    // 第一版这么写的，当场误报。
    expect(
      tester.getRect(find.byType(ListView)).top,
      greaterThanOrEqualTo(bar.bottom - 1),
      reason: '滚动区顶边压在顶栏里了，说明又变回叠加布局',
    );

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // 滚多远都不该动：内容区是独立滚动区（桌面端 `overflow-y-auto`），
    // 不像悬浮胶囊那版从顶栏底下穿过去。
    expect(
      tester.getRect(find.byType(ListView)).top,
      greaterThanOrEqualTo(bar.bottom - 1),
      reason: '滚动之后滚动区跑到顶栏上面去了',
    );
  });

  testWidgets('顶栏底下有分隔线', (tester) async {
    await pump(tester);

    // 顶栏和页面同底色（桌面端 `bg-background`），**靠这条线划界**。
    // 没有它的话顶栏和内容糊成一片，说不清哪里是顶栏。
    final decoration =
        tester.widget<DecoratedBox>(topBarFinder()).decoration as BoxDecoration;
    final divider = decoration.border?.bottom;
    expect(divider, isNotNull, reason: '顶栏底下没有分隔线，和内容糊在一起了');
    expect(
      divider!.color.a,
      greaterThan(0),
      reason: '分隔线是全透明的，等于没有',
    );
    expect(
      decoration.boxShadow ?? const <BoxShadow>[],
      isEmpty,
      reason: '顶栏投了影，看着又浮起来了——分隔线已经划清界，不该再叠阴影',
    );
  });

  testWidgets('滚动之后顶栏和返回键都还在', (tester) async {
    await pump(tester, pushed: true, statusBar: 40);

    expect(find.text('仪表盘'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    final before = topBarRect(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // **顶栏必须固定不动。** 有一版让整条栏滚走，搜索、⋮、刷新跟着一起消失，
    // 用户得往回滚才能用——用户原话：「返回按钮照常理来说应该一直显示」。
    expect(find.text('仪表盘'), findsOneWidget, reason: '标题滚没了');
    expect(find.byType(BackButton), findsOneWidget, reason: '返回键滚没了');
    expect(topBarRect(tester), before, reason: '顶栏位置不该随滚动变');
  });

  testWidgets('被推入的页面一定有返回按钮', (tester) async {
    await pump(tester, pushed: true);

    // 顶栏自带的「自动补返回键」是关掉的（顶栏自己排布局）。这里不补的话，被推入
    // 的页面就完全没有返回键——改造过程中真出现过这个回归。
    expect(find.byType(BackButton), findsOneWidget);
  });
}
