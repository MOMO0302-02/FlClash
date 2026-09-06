import 'package:clash_party/common/context.dart';
import 'package:clash_party/views/config/general.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';

class ConfigView extends StatelessWidget {
  const ConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: context.appLocalizations.basicConfig,
      // 和其它设置页一样用圆角分组卡片，不再是通栏平铺 + 分割线。
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: generateSection(isFirst: true, items: generalItems),
      ),
    );
  }
}
