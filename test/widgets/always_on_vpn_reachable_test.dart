import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 「始终开启 VPN」这一条得让用户找得到。
///
/// **来历**：这个条目写完了、四种语言的译文都齐了、跳系统设置和跳不过去时的兜底
/// 提示也都有，但**全项目零处引用**——它没被任何页面放进去，用户在界面上根本看
/// 不到。写了等于没写，而且不会有任何报错提醒你。
///
/// 这条是**源码扫描**，不是渲染测试。原因说清楚：这一条只在安卓上出现，而
/// `system.isAndroid` 取的是 `Platform.isAndroid`，宿主机上的 widget 测试改不了
/// 它，那段分支根本渲染不出来。所以只能退一步，钉住「有没有人引用它」——而这恰好
/// 就是当初出问题的那件事。
void main() {
  test('AlwaysOnVpnItem 被某个页面真的用上了，不是躺在那儿的死代码', () {
    const owner = 'lib/views/always_on_vpn.dart';
    final referrers = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('always_on_vpn.dart')) {
        continue;
      }
      if (entity.readAsStringSync().contains('AlwaysOnVpnItem')) {
        referrers.add(path);
      }
    }

    expect(
      referrers,
      isNotEmpty,
      reason: '$owner 里的条目没有任何页面引用，用户在界面上找不到它',
    );
  });
}
