import 'package:clash_party/common/redact.dart';
import 'package:test/test.dart';

void main() {
  group('redactUri', () {
    test('drops the query string that carries the subscription token', () {
      final result = redactUri(
        Uri.parse('https://sub.example.com/api/v1/client?token=SECRETVALUE'),
      );
      expect(result, isNot(contains('SECRETVALUE')));
      expect(result, isNot(contains('token')));
      expect(result, 'https://sub.example.com/…');
    });

    test('drops a token that sits in the path instead of the query', () {
      // 很多机场把 token 直接放路径里，只删查询串是不够的。
      final result = redactUri(
        Uri.parse('https://sub.example.com/link/SECRETVALUE'),
      );
      expect(result, isNot(contains('SECRETVALUE')));
      expect(result, 'https://sub.example.com/…');
    });

    test('drops user:password userinfo', () {
      final result = redactUri(
        Uri.parse('https://alice:SECRETVALUE@dav.example.com/backup'),
      );
      expect(result, isNot(contains('SECRETVALUE')));
      expect(result, isNot(contains('alice')));
    });

    test('drops the fragment', () {
      final result = redactUri(
        Uri.parse('https://sub.example.com/x#SECRETVALUE'),
      );
      expect(result, isNot(contains('SECRETVALUE')));
    });

    test('keeps scheme, host and port so logs stay useful', () {
      expect(
        redactUri(Uri.parse('http://10.0.2.2:8765/test.yaml')),
        'http://10.0.2.2:8765/…',
      );
    });

    test('adds no trailing marker when nothing was removed', () {
      expect(redactUri(Uri.parse('https://example.com')), 'https://example.com');
    });

    test('redacts a deep link that wraps a subscription url', () {
      final result = redactUri(
        Uri.parse(
          'clash://install-config?url=https%3A%2F%2Fsub.example.com'
          '%2Fc%3Ftoken%3DSECRETVALUE',
        ),
      );
      expect(result, isNot(contains('SECRETVALUE')));
      expect(result, isNot(contains('sub.example.com')));
      expect(result, 'clash://install-config/…');
    });

    test('handles a scheme with no host', () {
      expect(redactUri(Uri.parse('mailto:someone@example.com')), 'mailto:…');
    });
  });

  group('redactUrl', () {
    test('redacts a parsable url', () {
      expect(
        redactUrl('https://sub.example.com/c?token=SECRETVALUE'),
        'https://sub.example.com/…',
      );
    });

    test('never echoes back a url it failed to parse', () {
      // 解析失败常常正是因为串里有奇怪字符，原样返回等于没脱敏。
      // 'http://host:notaport' 这类端口非数字的串 Uri.tryParse 会返回 null。
      final result = redactUrl('http://host:notaport/?token=SECRETVALUE');
      expect(result, isNot(contains('SECRETVALUE')));
      expect(result, '<unparsable url>');
    });

    test('still redacts a malformed-looking url that does parse', () {
      // Uri.tryParse 很宽松（空格会被转义），这类串仍走正常脱敏分支，
      // 关键是 token 不能漏出去。
      final result = redactUrl('https://exa mple.com/?token=SECRETVALUE');
      expect(result, isNot(contains('SECRETVALUE')));
    });
  });

  group('describeCoreArguments', () {
    test('redacts the sideloaded provider body', () {
      final result = describeCoreArguments({
        'providerName': 'my-provider',
        'data': 'proxies:\n  - name: n\n    password: SECRETVALUE\n',
      });
      expect(result, isNot(contains('SECRETVALUE')));
      expect(result, isNot(contains('password')));
      // provider 名字本身不是凭据，留着方便排查。
      expect(result, contains('my-provider'));
    });

    test('redacts sensitive keys regardless of value length', () {
      expect(describeCoreArguments({'token': 'ab'}), '{token: <redacted>}');
      expect(describeCoreArguments({'url': 'ab'}), '{url: <redacted>}');
    });

    test('key matching is case insensitive', () {
      expect(describeCoreArguments({'Password': 'ab'}), contains('<redacted>'));
    });

    test('keeps short scalars so ordinary debugging still works', () {
      final result = describeCoreArguments({
        'mixed-port': 7890,
        'enable': true,
        'log-level': 'error',
      });
      expect(result, contains('mixed-port: 7890'));
      expect(result, contains('enable: true'));
      expect(result, contains('log-level: error'));
    });

    test('replaces any over-long value with just its length', () {
      final long = 'x' * 500;
      final result = describeCoreArguments({'somethingElse': long});
      expect(result, isNot(contains(long)));
      expect(result, '{somethingElse: <500 chars>}');
    });

    test('redacts a long bare string argument', () {
      final result = describeCoreArguments('y' * 300);
      expect(result, '<300 chars>');
    });

    test('handles null', () {
      expect(describeCoreArguments(null), 'null');
    });
  });
}
