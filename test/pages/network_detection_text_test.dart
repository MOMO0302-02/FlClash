import 'package:clash_party/models/models.dart';
import 'package:clash_party/views/dashboard/widgets/network_detection.dart';
import 'package:clash_party/views/dashboard/widgets/network_detection_detail.dart';
import 'package:flutter_test/flutter_test.dart';

/// 这两个函数负责把「拿到多少算多少」的 IP 信息拼成给人看的文字。
///
/// 数据源不同，字段缺席的组合也不同，拼错的表现是界面上出现 ", , 美国" 或者
/// 一行光秃秃的分隔符——都是只有真跑到那个组合才会看见的，所以逐个组合钉住。
void main() {
  group('NetworkDetectionDetailView.locationText', () {
    test('joins city, region and country when all are present', () {
      const info = IpInfo(
        ip: '8.8.8.8',
        countryCode: 'US',
        country: 'United States',
        region: 'California',
        city: 'Mountain View',
      );
      expect(
        NetworkDetectionDetailView.locationText(info),
        'Mountain View, California, United States',
      );
    });

    test('skips the parts that are missing', () {
      const onlyCountry = IpInfo(
        ip: '8.8.8.8',
        countryCode: 'US',
        country: 'United States',
      );
      expect(
        NetworkDetectionDetailView.locationText(onlyCountry),
        'United States',
      );

      const noCity = IpInfo(
        ip: '8.8.8.8',
        countryCode: 'US',
        country: 'United States',
        region: 'California',
      );
      expect(
        NetworkDetectionDetailView.locationText(noCity),
        'California, United States',
      );
    });

    test('falls back to the country code when there is no country name', () {
      const info = IpInfo(ip: '8.8.8.8', countryCode: 'us');
      expect(NetworkDetectionDetailView.locationText(info), 'US');
    });

    test('does not repeat a region that equals the city', () {
      // 城市即直辖市/城邦时，两个字段常常是同一个词（Singapore, Singapore）。
      const info = IpInfo(
        ip: '8.8.8.8',
        countryCode: 'SG',
        country: 'Singapore',
        region: 'Singapore',
        city: 'Singapore',
      );
      expect(
        NetworkDetectionDetailView.locationText(info),
        'Singapore, Singapore',
      );
    });
  });

  group('NetworkDetection.ipLine', () {
    // 磁贴上**只显示 IP**，不再追加城市。
    //
    // 原来是「IP · 城市」，但半宽磁贴一行放不下，城市几乎总是被截成
    // 「43.198.97.166 · Hon…」——半截地名既没信息量、又像出了错。地区已经由
    // 左边的国旗表达，完整的地理位置、经纬度、运营商都在详情页里。
    test('有位置信息时也只显示 IP', () {
      const withCity = IpInfo(
        ip: '8.8.8.8',
        countryCode: 'US',
        country: 'United States',
        region: 'California',
        city: 'Mountain View',
      );
      expect(NetworkDetection.ipLine(withCity), '8.8.8.8');
    });

    test('没有位置信息时同样只显示 IP', () {
      const info = IpInfo(ip: '8.8.8.8', countryCode: 'US');
      expect(NetworkDetection.ipLine(info), '8.8.8.8');
    });
  });
}
