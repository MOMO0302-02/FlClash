import 'package:clash_party/common/num.dart';
import 'package:test/test.dart';

void main() {
  group('num.fixed', () {
    test('removes trailing zeros', () {
      expect(1.50.fixed(), '1.5');
    });

    test('keeps significant decimals', () {
      expect(1.23.fixed(), '1.23');
    });

    test('removes decimal point when all zeros', () {
      expect(5.00.fixed(), '5');
    });

    test('respects custom decimals', () {
      expect(1.2345.fixed(decimals: 3), '1.234');
    });

    test('handles integers', () {
      expect(42.fixed(), '42');
    });
  });

  // `num.traffic` 的完整对照（含桌面端 `calcTraffic` 的截短规则、九档单位、
  // 负数与边界）在 `test/common/traffic_format_parity_test.dart`。这里只留几条
  // 冒烟，改格式化规则时**以那一份为准**。
  group('num.traffic', () {
    test('bytes for small values', () {
      final result = 500.traffic;
      // '500.00' 长度 6 → 改成一位小数。
      expect(result.value, '500.0');
      expect(result.unit, 'B');
    });

    test('kilobytes', () {
      final result = 1536.traffic;
      // 不去尾零：'1.50' 不写成 '1.5'。
      expect(result.value, '1.50');
      expect(result.unit, 'KB');
    });

    test('megabytes', () {
      final result = (1024 * 1024 * 2.5).traffic;
      expect(result.value, '2.50');
      expect(result.unit, 'MB');
    });

    test('gigabytes', () {
      final result = (1024 * 1024 * 1024 * 3.0).traffic;
      expect(result.value, '3.00');
      expect(result.unit, 'GB');
    });

    test('zero bytes', () {
      final result = 0.traffic;
      expect(result.value, '0.00');
      expect(result.unit, 'B');
    });
  });

  group('num.shortTraffic', () {
    test('no decimal places', () {
      final result = 1536.shortTraffic;
      expect(result.value, '2');
      expect(result.unit, 'KB');
    });

    test('bytes', () {
      final result = 500.shortTraffic;
      expect(result.value, '500');
      expect(result.unit, 'B');
    });
  });
}
