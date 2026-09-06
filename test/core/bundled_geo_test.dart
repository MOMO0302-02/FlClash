import 'dart:io';

import 'package:clash_party/common/constant.dart';
import 'package:flutter_test/flutter_test.dart';

/// 随包携带哪些 geo 数据。
///
/// **来历**：真机实测发现 `GEOIP.dat` 从装到卸都没被读过一次，却占了安装包
/// 4.59 MB、设备上 20.5 MB，还会被定时更新反复下载。
///
/// 为什么它用不上（读内核源码确认，不是猜的）：
/// * 内核只在 `geodata-mode: true` 时才读 GeoIP.dat
///   （`component/geodata/init.go:121` 的 `if GeodataMode()`），为假时用的是
///   GEOIP.metadb（MMDB）；
/// * `geoMode` 是 `component/geodata/utils.go:14` 的裸 bool，**默认 false**；
/// * 本应用从不写 `geodata-mode` 这个键，界面上也没有对应开关；
/// * 定时更新同样分叉（`component/updater/update_geo.go:203`），为假时更新 MMDB。
///
/// 这条测试钉两件事：名单里没有它，**而且资源目录里也真的没有这个文件**。
/// 只钉名单是不够的——文件留在 `assets/data/` 里照样会被打进安装包，
/// 而 `pubspec.yaml` 声明的是整个目录。
void main() {
  test('不随包携带 GEOIP.dat：内核默认模式下根本不读它', () {
    expect(bundledGeoFileNames, isNot(contains(GEOIP)));
    expect(
      File('assets/data/$GEOIP').existsSync(),
      isFalse,
      reason: '文件还在 assets/data 里，照样会被打进安装包（pubspec 声明的是整个目录）',
    );
  });

  test('内核默认模式真正要用的三个仍然随包携带', () {
    // 少带任何一个，第一次启动就得联网下载，没网就直接不能用。
    for (final name in [MMDB, GEOSITE, ASN]) {
      expect(bundledGeoFileNames, contains(name));
      expect(
        File('assets/data/$name').existsSync(),
        isTrue,
        reason: '$name 不见了',
      );
    }
  });
}
