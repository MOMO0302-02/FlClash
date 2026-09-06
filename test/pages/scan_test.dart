import 'package:clash_party/pages/scan.dart';
import 'package:flutter_test/flutter_test.dart';

/// 扫码页判「这个码能不能用」的那一步。
///
/// 判错的两种后果都看不出来：判宽了会把一段普通文字当订阅去下载，判窄了会让一个
/// 本来能用的码被提示成「无法识别」。而扫码本身没法在单测里跑，所以把这一步单独
/// 拎出来钉住。
void main() {
  group('resolveScannedProfileUrl', () {
    test('accepts plain http/https/ftp links', () {
      expect(
        resolveScannedProfileUrl('https://example.com/sub?token=x'),
        'https://example.com/sub?token=x',
      );
      expect(
        resolveScannedProfileUrl('http://example.com/sub'),
        'http://example.com/sub',
      );
      expect(
        resolveScannedProfileUrl('ftp://example.com/sub'),
        'ftp://example.com/sub',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        resolveScannedProfileUrl('  https://example.com/sub \n'),
        'https://example.com/sub',
      );
    });

    test('unwraps clash-style deep links into the inner subscription url', () {
      // 这是最常见的一种订阅二维码，而扫码库把它归成纯文本而不是 URL——
      // 改动前正是这一类被静默丢掉，用户看到的就是「扫了没反应」。
      for (final scheme in ['clash', 'clashmeta', 'clashparty']) {
        expect(
          resolveScannedProfileUrl(
            '$scheme://install-config?url=https%3A%2F%2Fexample.com%2Fsub',
          ),
          'https://example.com/sub',
          reason: 'scheme $scheme should be unwrapped',
        );
      }
    });

    test('rejects deep links that carry no usable url', () {
      expect(
        resolveScannedProfileUrl('clash://install-config'),
        isNull,
      );
      expect(
        resolveScannedProfileUrl('clash://install-config?url=not-a-url'),
        isNull,
      );
      // host 不对的深链不认：只有 install-config 才带订阅地址。
      expect(
        resolveScannedProfileUrl('clash://other?url=https://example.com/sub'),
        isNull,
      );
    });

    test('rejects text that is not a link at all', () {
      expect(resolveScannedProfileUrl('hello world'), isNull);
      expect(resolveScannedProfileUrl('WIFI:S:home;T:WPA;P:secret;;'), isNull);
      expect(resolveScannedProfileUrl(''), isNull);
      expect(resolveScannedProfileUrl('   '), isNull);
      expect(resolveScannedProfileUrl(null), isNull);
    });

    test('still passes through whatever the scanner itself typed as a url', () {
      // 改动前的行为就是「库说是 URL 就原样交给下游」。这里保住它，免得把
      // 本来能用的（比如没写协议的 www. 开头）判成不认识。
      expect(
        resolveScannedProfileUrl('www.example.com/sub', isUrlBarcode: true),
        'www.example.com/sub',
      );
      expect(resolveScannedProfileUrl('www.example.com/sub'), isNull);
    });
  });
}
