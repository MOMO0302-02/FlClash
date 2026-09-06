import 'package:clash_party/widgets/activate_box.dart';
import 'package:clash_party/widgets/builder.dart';
import 'package:clash_party/widgets/disabled_mask.dart';
import 'package:clash_party/widgets/inherited.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ActivateBox blocks pointer events when inactive', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ActivateBox(
          active: false,
          child: TextButton(onPressed: () => taps++, child: const Text('tap')),
        ),
      ),
    );

    await tester.tap(find.text('tap'), warnIfMissed: false);

    expect(taps, 0);
  });

  testWidgets('ActivateBox allows pointer events when active', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ActivateBox(
          active: true,
          child: TextButton(onPressed: () => taps++, child: const Text('tap')),
        ),
      ),
    );

    await tester.tap(find.text('tap'));

    expect(taps, 1);
  });

  testWidgets('DisabledMask applies filter only when status is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DisabledMask(status: true, child: Text('disabled')),
      ),
    );

    expect(find.byType(ColorFiltered), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: DisabledMask(status: false, child: Text('enabled')),
      ),
    );
    // 变灰现在是渐变的，所以关掉之后要等过渡跑完才回到「完全没有滤镜」。
    // 中途仍然挂着 ColorFiltered 是对的——那正是它在往回退。
    await tester.pumpAndSettle();

    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('FloatingActionButtonExtendedBuilder defaults to extended', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FloatingActionButtonExtendedBuilder(
          builder: (isExtended) => Text('extended: $isExtended'),
        ),
      ),
    );

    expect(find.text('extended: true'), findsOneWidget);
  });

  testWidgets('FloatingActionButtonExtendedBuilder reads inherited state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommonScaffoldFabExtendedProvider(
          isExtended: false,
          child: FloatingActionButtonExtendedBuilder(
            builder: (isExtended) => Text('extended: $isExtended'),
          ),
        ),
      ),
    );

    expect(find.text('extended: false'), findsOneWidget);
  });
}
