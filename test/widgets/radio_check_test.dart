import 'package:clash_party/widgets/list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('radio row shows a check on the selected option only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RadioGroup<String>(
            groupValue: 'b',
            onChanged: (_) {},
            child: Column(
              children: [
                for (final v in ['a', 'b', 'c'])
                  ListItem.radio(value: v, onTap: () {}, title: Text(v)),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Radio<String>), findsNothing);

    // 对勾**每一行都有**，只是没选中的那些透明度是 0——始终占位才不会在选中
    // 瞬间把标题挤窄。所以这里要找的是「哪一个是看得见的」。
    final visibleChecks = tester
        .widgetList<AnimatedOpacity>(
          find.ancestor(
            of: find.byIcon(Icons.check),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .where((widget) => widget.opacity == 1)
        .length;
    expect(visibleChecks, 1, reason: '只有选中的那条该显示对勾');

    final checkTile = find.ancestor(
      of: find.byWidgetPredicate(
        (widget) => widget is AnimatedOpacity && widget.opacity == 1,
      ),
      matching: find.byType(ListTile),
    );
    expect(find.descendant(of: checkTile, matching: find.text('b')), findsOne);
  });
}
