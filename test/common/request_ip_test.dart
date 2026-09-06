import 'dart:async';
import 'dart:typed_data';

import 'package:clash_party/common/request.dart';
import 'package:clash_party/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 网络检测里三个新增的请求。
///
/// 全部把 dio 的适配器换成桩，测试不碰真网络：真连外网的测试在没网的机器上会
/// 红，在有网的机器上又会因为对方接口改版而红，两种都不是被测代码的问题。
void main() {
  late HttpClientAdapter originalAdapter;

  setUp(() {
    originalAdapter = request.dio.httpClientAdapter;
  });

  tearDown(() {
    request.dio.httpClientAdapter = originalAdapter;
  });

  group('fetchIpDetail', () {
    test('parses the rich payload', () async {
      request.dio.httpClientAdapter = _StubAdapter(
        (options) => _json('''
{
  "ip": "8.8.8.8",
  "company": {"name": "Google LLC", "abuser_score": "0.0012 (Low)"},
  "asn": {"asn": 15169, "org": "Google LLC", "rir": "ARIN",
          "country": "us", "route": "8.8.8.0/24", "type": "business"},
  "location": {"country": "United States", "country_code": "US",
               "city": "Mountain View"}
}
'''),
      );

      final result = await request.fetchIpDetail();

      expect(result.data?.company, 'Google LLC');
      expect(result.data?.registry, 'ARIN');
      expect(result.data?.cidr, '8.8.8.0/24');
    });

    test('a broken payload is no data rather than an error', () async {
      // 这一步只是给详情页补空行。它挂掉不该把已经拿到的 IP 一起作废，所以
      // 返回的是「没有额外信息」而不是失败。
      request.dio.httpClientAdapter = _StubAdapter(
        (options) => _json('{"unexpected": true}'),
      );

      final result = await request.fetchIpDetail();

      expect(result.isSuccess, isTrue);
      expect(result.data, isNull);
    });

    test('a network failure is no data rather than an error', () async {
      request.dio.httpClientAdapter = _StubAdapter(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      final result = await request.fetchIpDetail();

      expect(result.isSuccess, isTrue);
      expect(result.data, isNull);
    });

    test('cancelling is reported as an error, not as no data', () async {
      // 「用户切了节点，这次检测作废」和「这个源没信息」必须分得开，否则调用处
      // 会把一次作废当成一次有效的空结果贴到界面上。
      request.dio.httpClientAdapter = _StubAdapter(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        ),
      );

      final result = await request.fetchIpDetail();

      expect(result.isError, isTrue);
    });
  });

  group('measureLatency', () {
    test('any http answer counts as reachable', () async {
      // 目标是探链路通不通，不是探页面存不存在——403 / 404 同样说明通了。
      request.dio.httpClientAdapter = _StubAdapter(
        (options) => ResponseBody.fromString('forbidden', 403),
      );

      final latency = await request.measureLatency('https://example.com');

      expect(latency, isNotNull);
    });

    test('an unreachable target returns null instead of throwing', () async {
      request.dio.httpClientAdapter = _StubAdapter(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final latency = await request.measureLatency('https://example.com');

      expect(latency, isNull);
    });

    test('a target slower than the budget returns null', () async {
      request.dio.httpClientAdapter = _StubAdapter(
        (options) => Future.delayed(
          const Duration(milliseconds: 300),
          () => ResponseBody.fromString('', 204),
        ),
      );

      final latency = await request.measureLatency(
        'https://example.com',
        timeout: const Duration(milliseconds: 50),
      );

      expect(latency, isNull);
    });
  });

  group('checkIpv6', () {
    test('returns the address when the v6-only host answers', () async {
      request.dio.httpClientAdapter = _StubAdapter(
        (options) => ResponseBody.fromString('2606:4700:4700::1111', 200),
      );

      expect(await request.checkIpv6(), '2606:4700:4700::1111');
    });

    test('a hijacked html answer does not count as IPv6', () async {
      // 有些网络会对连不上的域名回一个 200 的门户页。它不含冒号或者含尖括号，
      // 两条都拦下来，免得把「被劫持」显示成「支持 IPv6」。
      request.dio.httpClientAdapter = _StubAdapter(
        (options) => ResponseBody.fromString(
          '<html><body>login: required</body></html>',
          200,
        ),
      );

      expect(await request.checkIpv6(), isNull);
    });

    test('no answer means no IPv6', () async {
      request.dio.httpClientAdapter = _StubAdapter(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      expect(await request.checkIpv6(), isNull);
    });
  });
}

ResponseBody _json(String body) => ResponseBody.fromString(
  body,
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
