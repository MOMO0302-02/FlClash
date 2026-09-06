import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/dashboard_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 磁贴统一版式的几何钉子。
///
/// 用户的要求是「磁贴的文字和图标位置要统一，和桌面端一致」。桌面端侧边栏卡片
/// （`components/sider/*.tsx`）的规则是：**图标左上、附加信息右上、标题左下**。
/// 安卓端所有磁贴现在都走 [DashboardTile]，这组测试把那三处相对位置量出来钉住——
/// 换了 trailing 的种类（开关 / 徽标 / 文本）位置也不能变，否则就又「各摆各的」了。
void main() {
  const iconKey = ValueKey('probe-icon');
  const trailingKey = ValueKey('probe-trailing');
  const titleText = '版式探针';

  /// 把 [tile] 放进一个固定宽度的卡片里画出来，globalState 的两个 late 字段
  /// 按 [scale] 初始化（磁贴高度、内边距都靠它们算）。
  Future<void> pump(
    WidgetTester tester, {
    required Widget tile,
    Size size = const Size(400, 900),
    double scale = 1.0,
    double width = 180,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (context) {
            globalState.measure = Measure.of(context, scale);
            globalState.theme = CommonTheme.of(context, scale);
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(child: SizedBox(width: width, child: tile)),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
  }

  DashboardTile probeTile({Widget? trailing, Widget? body, int rows = 1}) {
    return DashboardTile(
      leading: const Icon(Icons.memory, key: iconKey, size: 20),
      label: titleText,
      trailing: trailing,
      body: body,
      rows: rows,
      onTap: () {},
    );
  }

  group('单块磁贴：图标左上、标题左下、附加信息右上', () {
    testWidgets('图标在标题的正上方，且左对齐', (tester) async {
      await pump(
        tester,
        tile: probeTile(
          trailing: const SizedBox(key: trailingKey, width: 40, height: 32),
        ),
      );
      final icon = tester.getRect(find.byKey(iconKey));
      final title = tester.getRect(find.text(titleText));

      expect(
        icon.center.dy,
        lessThan(title.center.dy),
        reason: '图标应当在标题上方',
      );
      expect(
        (icon.left - title.left).abs(),
        lessThan(1.0),
        reason: '图标和标题应当左对齐（同一条左边缘）',
      );
    });

    testWidgets('附加信息在右上：和图标同一行、贴着右边缘', (tester) async {
      await pump(
        tester,
        tile: probeTile(
          trailing: const SizedBox(key: trailingKey, width: 40, height: 32),
        ),
      );
      final icon = tester.getRect(find.byKey(iconKey));
      final trailing = tester.getRect(find.byKey(trailingKey));
      final title = tester.getRect(find.text(titleText));

      expect(
        trailing.center.dy,
        lessThan(title.top),
        reason: '附加信息应当在顶部一行，位于标题上方',
      );
      expect(
        trailing.left,
        greaterThan(icon.right),
        reason: '附加信息应当在图标右侧',
      );
      // 贴着卡片右边缘：trailing 右沿应当明显在图标右沿之外，靠近卡片右侧。
      expect(
        trailing.right,
        greaterThan(icon.right + 40),
        reason: '附加信息应当靠右，不是挨着图标',
      );
    });
  });

  group('跨磁贴一致：换了 trailing 的种类，图标和标题位置纹丝不动', () {
    testWidgets('开关 / 徽标 / 文本三种 trailing，图标与标题几何完全一致', (tester) async {
      Future<Rect> iconRectWith(Widget trailing) async {
        await pump(tester, tile: probeTile(trailing: trailing));
        return tester.getRect(find.byKey(iconKey));
      }

      Future<Rect> titleRectWith(Widget trailing) async {
        await pump(tester, tile: probeTile(trailing: trailing));
        return tester.getRect(find.text(titleText));
      }

      final trailings = <Widget>[
        dashboardTileSwitch(value: true, onChanged: (_) {}),
        const DashboardCountBadge('63'),
        const Text('192.168.31.181'),
      ];

      final iconRects = <Rect>[];
      final titleRects = <Rect>[];
      for (final t in trailings) {
        iconRects.add(await iconRectWith(t));
        titleRects.add(await titleRectWith(t));
      }

      for (var i = 1; i < iconRects.length; i++) {
        expect(
          iconRects[i],
          iconRects.first,
          reason: '换了 trailing 种类后图标位置变了，版式没统一',
        );
        expect(
          titleRects[i],
          titleRects.first,
          reason: '换了 trailing 种类后标题位置变了，版式没统一',
        );
      }
    });
  });

  group('固定高度内不溢出', () {
    final errors = <String>[];
    late FlutterExceptionHandler? previous;

    setUp(() {
      errors.clear();
      previous = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        if (text.contains('overflowed')) {
          errors.add(text.split('\n').first);
        } else {
          previous?.call(details);
        }
      };
    });

    tearDown(() {
      FlutterError.onError = previous;
    });

    testWidgets('开关磁贴：小屏 + 1.4 倍字号不溢出', (tester) async {
      await pump(
        tester,
        size: const Size(320, 568),
        scale: 1.4,
        width: 150,
        tile: probeTile(
          trailing: dashboardTileSwitch(value: true, onChanged: (_) {}),
        ),
      );
      expect(errors, isEmpty, reason: errors.join('\n'));
    });

    testWidgets('超长 IP 的值磁贴不撑破', (tester) async {
      await pump(
        tester,
        size: const Size(320, 568),
        scale: 1.4,
        width: 150,
        tile: DashboardTile(
          icon: Icons.devices,
          label: '一个特别长的磁贴标题用来测截断',
          onTap: () {},
          trailing: const Text(
            'fe80::1234:5678:9abc:def0',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      expect(errors, isEmpty, reason: errors.join('\n'));
    });

    testWidgets('两行高、带 body 的磁贴不溢出', (tester) async {
      await pump(
        tester,
        size: const Size(320, 568),
        scale: 1.4,
        width: 150,
        tile: probeTile(
          rows: 2,
          body: const Center(child: Text('42.0 MB')),
        ),
      );
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  });
}
