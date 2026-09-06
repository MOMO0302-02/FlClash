import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/theme.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/dashboard/widgets/dashboard_tile.dart';
import 'package:clash_party/views/dashboard/widgets/network_detection.dart'
    as tile;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 网络检测磁贴上的 IP：不许被切，也不许小到看不清。
///
/// **来历（用户前后提了三次）**：
/// 1. **横着被截**——磁贴上写的是「IP · 城市」，半宽磁贴一行放不下，变成
///    `43.198.97.166 · Hon…`。改成只显示 IP。
/// 2. **竖着被切**——为了给 IP 让地方把它挪到了磁贴中段，而一行高的磁贴总共
///    80 像素，去掉上下内边距 16、顶部图标行 32、底部标题约 20，中段只剩约
///    12 像素，17 号字上下都被切掉。挪回右上角那一行（32 像素高）。
/// 3. **「换个长一点的 IP 会不会溢出」**——不会溢出，但会出另一个问题：
///    `FittedBox(scaleDown)` 没有下限，IPv6 是 39 个字符，同样的宽度要缩到
///    5 号字左右，等于看不见。现在缩到原字号的 0.7 就停，再塞不下就**从中间
///    省略**（IP 的头尾才是能认出地址的部分，从尾巴截等于白截）。
///
/// **不按「画出来的字符串等于原始 IP」来断言。** widget 测试用的是内置测试字体，
/// 每个字符都是边长等于字号的方块，比任何真字体都宽得多——同一个磁贴宽度下，
/// 真机上放得下的 IP 在测试里必然触发省略。所以这里钉的是**行为**：没超出边界、
/// 没小过下限、省略时头尾都在、地方够时一个像素都不动。
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String ip,
    double textScale = 1.0,
    double width = 160,
  }) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        // 直接给一个「查完了、拿到 IP 了」的状态，不发任何网络请求。
        networkDetectionProvider.overrideWithBuild(
          (_, _) => NetworkDetectionState(
            isLoading: false,
            ipInfo: IpInfo(ip: ip, countryCode: 'HK'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          builder: (context, child) {
            globalState.measure = Measure.of(context, textScale);
            globalState.theme = CommonTheme.of(context, textScale);
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: const tile.NetworkDetection(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 磁贴上那一行 IP 的 Text。
  ///
  /// **按「样式里有等宽数字」找。** 那是 IP 这一行独有的
  /// （`dashboardTileValueStyle` + `tabularFigures`），标题和左上角的国旗都没有。
  ///
  /// 前两版都栽了：按完整 IP 找——省略之后画出来的是 `208.8…3.24`，找不到；
  /// 按「含点或冒号」找——省到极限会变成 `255…55`，一个点都不剩；按「不是标题的
  /// 那一个」找——左上角还有个国旗 Text（`🇭🇰`）排在前面。
  Text ipText(WidgetTester tester) {
    return tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(tile.NetworkDetection),
            matching: find.byType(Text),
          ),
        )
        .firstWhere((item) => item.style?.fontFeatures != null);
  }

  void expectInsideTile(WidgetTester tester) {
    final bounds = tester.getRect(find.byType(tile.NetworkDetection));
    final text = tester.getRect(find.byWidget(ipText(tester)));
    expect(text.left, greaterThanOrEqualTo(bounds.left - 0.5), reason: '左边被切');
    expect(text.right, lessThanOrEqualTo(bounds.right + 0.5), reason: '右边被切');
    expect(text.top, greaterThanOrEqualTo(bounds.top - 0.5), reason: '上边被切');
    expect(text.bottom, lessThanOrEqualTo(bounds.bottom + 0.5), reason: '下边被切');
  }

  // 12 位是常见 IPv4（用户截图里那个）、15 位是 IPv4 最长、39 位是 IPv6 最长。
  const ips = [
    '208.8.203.24',
    '255.255.255.255',
    '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
  ];

  for (final ip in ips) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('$ip 在 ${scale}x 字号下不超出磁贴', (tester) async {
        await pump(tester, ip: ip, textScale: scale);
        expectInsideTile(tester);
      });

      testWidgets('$ip 在 ${scale}x 字号下不会小过下限', (tester) async {
        await pump(tester, ip: ip, textScale: scale);

        final context = tester.element(find.byType(tile.NetworkDetection));
        final base = dashboardTileValueStyle(context)!.fontSize!;
        // 下限是原字号的 0.7。再往下就该省略而不是继续缩——缩到 5 号字虽然
        // 不溢出，但等于看不见，那正是当初 `FittedBox(scaleDown)` 的毛病。
        expect(
          ipText(tester).style!.fontSize,
          greaterThanOrEqualTo(base * 0.7 - 0.01),
          reason: 'IP 被缩到了看不清的程度',
        );
      });
    }
  }

  testWidgets('省略时留头留尾，不是从尾巴截掉', (tester) async {
    const ip = '2001:0db8:85a3:0000:0000:8a2e:0370:7334';
    // 故意给一个放不下的宽度，逼出省略那条路。
    await pump(tester, ip: ip, width: 150);

    final shown = ipText(tester).data!;
    expect(shown, isNot(ip), reason: '这个宽度下本就该省略，没省略说明没走到那条路');
    expect(shown, contains('…'));
    // 头尾都得留着：IP 的头尾才是能认出「这是哪个地址」的部分，
    // 默认那种从尾巴截的省略号（`2001:0db8:85a…`）看不出区别。
    final head = shown.split('…').first;
    final tail = shown.split('…').last;
    expect(head, isNotEmpty, reason: '头没留');
    expect(tail, isNotEmpty, reason: '尾没留');
    expect(ip, startsWith(head));
    expect(ip, endsWith(tail));
  });

  testWidgets('地方够宽时原样显示，一个像素都不缩', (tester) async {
    const ip = '208.8.203.24';
    // 测试字体每个字符都是边长等于字号的方块：12 个字符 × 17 = 204，
    // 加上左边的国旗和左右内边距，给 400 足够宽裕。
    await pump(tester, ip: ip, width: 400);

    final text = ipText(tester);
    expect(text.data, ip, reason: '地方够还省略，那是白省');

    final context = tester.element(find.byType(tile.NetworkDetection));
    expect(
      text.style!.fontSize,
      dashboardTileValueStyle(context)!.fontSize,
      reason: '地方够还缩小，那是白缩',
    );
  });
}
