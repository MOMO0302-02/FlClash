import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/state.dart';
import 'package:flutter/cupertino.dart';

class Request {
  late final Dio dio;
  late final Dio _clashDio;
  String? userAgent;

  Request() {
    dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    // 订阅下载必须有超时。
    //
    // 没有超时时的表现不是「报错」而是**永远转圈**：服务器完成 TCP 握手却不发
    // 响应体（域名被墙、机场挂了但端口还开着）时，这条请求永不结束。实测在模拟器
    // 上复现过——配置页顶部的进度条连续走了 4 分钟仍未停，既没有结果也没有取消
    // 入口，用户只能再点一次，于是并发堆叠。
    //
    // 更糟的是这条路径还在**启动链**上：订阅文件缺失时启动过程会现下一份，卡住
    // 就整个初始化走不完——自动更新、`clash://` 监听、快捷方式全都不注册，应用
    // 半死不活而界面一言不发。
    //
    // 调用方那层 `Future.timeout` 只是「不再等」，掐不掉底层连接；这里的
    // `connectTimeout` / `receiveTimeout` 才真的会断开。两层都要有。
    //
    // 取值：连接 15 秒、收数据 45 秒。订阅通常只有几百 KB，移动网络下也够；
    // 比调用方那层 60 秒短，好让 dio 自己先报出更具体的错误类型。
    _clashDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
      ),
    );
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (Uri uri) {
          client.userAgent = globalState.ua;
          return ClashPartyHttpOverrides.handleFindProxy(uri);
        };
        return client;
      },
    );
  }

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    try {
      return await _clashDio.get<Uint8List>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
    } catch (e) {
      // 不能记 e.toString()：DioException 的 toString 会带上完整请求 URL（订阅
      // 链接里就是 token），有时还夹着响应体。只留脱敏后的主机名和错误类型。
      commonPrint.log(
        'getFileResponseForUrl ${redactUrl(url)} failed: ${e.runtimeType}',
      );
      if (e is DioException) {
        if (e.type == DioExceptionType.unknown) {
          throw currentAppLocalizations.unknownNetworkError;
        } else if (e.type == DioExceptionType.badResponse) {
          throw currentAppLocalizations.networkException;
        }
        // **不要 rethrow 原始的 DioException。**
        //
        // 它的 toString() 长这样：`DioException [connection timeout]: ...
        // SocketException ... address = <订阅主机名>` —— 对用户是天书，而且
        // 会把订阅的主机名回显到界面上。超时和连接失败都归到「网络异常」。
        throw currentAppLocalizations.networkException;
      }
      throw currentAppLocalizations.unknownNetworkError;
    }
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    final response = await _clashDio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    return response;
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) return null;
    return MemoryImage(data);
  }

  /// Success carries the release data, or null when already up to date.
  /// A failed request must stay distinguishable from 'no update', otherwise
  /// an offline check is reported as 'already the latest version'.
  Future<Result<Map<String, dynamic>?>> checkForUpdate() async {
    // 自用构建没有 GitHub Releases，原来的地址指向上游作者的仓库——查了必然
    // 失败，还把请求打到别人那里。直接返回「已是最新」。
    return Result.success(null);
    // ignore: dead_code
    try {
      final response = await dio.get(
        'https://api.github.com/repos/$repository/releases/latest',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode != 200) {
        return Result.error('${response.statusCode}');
      }
      final data = response.data as Map<String, dynamic>;
      final remoteVersion = data['tag_name'];
      final version = globalState.packageInfo.version;
      final hasUpdate =
          utils.compareVersions(remoteVersion.replaceAll('v', ''), version) > 0;
      if (!hasUpdate) return Result.success(null);
      return Result.success(data);
    } catch (e) {
      commonPrint.log('checkForUpdate failed', logLevel: LogLevel.warning);
      return Result.error(e.toString());
    }
  }

  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    'https://ipwho.is': IpInfo.fromIpWhoIsJson,
    'https://api.myip.com': IpInfo.fromMyIpJson,
    'https://ipapi.co/json': IpInfo.fromIpApiCoJson,
    'https://ident.me/json': IpInfo.fromIdentMeJson,
    'http://ip-api.com/json': IpInfo.fromIpAPIJson,
    'https://api.ip.sb/geoip': IpInfo.fromIpSbJson,
    'https://ipinfo.io/json': IpInfo.fromIpInfoIoJson,
  };

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
    var failureCount = 0;
    final token = cancelToken ?? CancelToken();
    final futures = _ipInfoSources.entries.map((source) async {
      final Completer<Result<IpInfo?>> completer = Completer();
      void handleFailRes() {
        if (!completer.isCompleted && failureCount == _ipInfoSources.length) {
          completer.complete(Result.success(null));
        }
      }

      final future = dio
          .get<Map<String, dynamic>>(
            source.key,
            cancelToken: token,
            options: Options(responseType: ResponseType.json),
          )
          .timeout(const Duration(seconds: 10));
      future
          .then((res) {
            if (res.statusCode == HttpStatus.ok && res.data != null) {
              completer.complete(Result.success(source.value(res.data!)));
              return;
            }
            commonPrint.log('checkIp data empty', logLevel: LogLevel.info);
            failureCount++;
            handleFailRes();
          })
          .catchError((e) {
            failureCount++;
            if (e is DioException && e.type == DioExceptionType.cancel) {
              completer.complete(Result.error('cancelled'));
              return;
            }
            commonPrint.log('checkIp error $e', logLevel: LogLevel.warning);
            handleFailRes();
          });
      return completer.future;
    });
    final res = await Future.any(futures);
    token.cancel();
    return res;
  }

  /// 富信息接口：企业、风险评分、注册局、CIDR 这些只有它给。
  ///
  /// 桌面版 `src/renderer/src/pages/network.tsx` 里三个可选数据源之一就是它。
  /// 这里不带查询参数，接口默认回答「请求方自己的 IP」——比把用户的 IP 拼进
  /// URL 更保守，也保证查的一定是当前这条出口链路。
  static const _ipDetailSource = 'https://api.ipapi.is/';

  /// 拉一次富信息。
  ///
  /// 这是 [checkIp] 之外的**第二步**，故意分开：竞速那一步几百毫秒就能给出
  /// IP 让磁贴显示，而这个源只有一家、慢或不通时不该把整个检测一起拖住。所以
  /// 失败一律当作「没有额外信息」，不影响已经拿到的结果。
  Future<Result<IpInfo?>> fetchIpDetail({CancelToken? cancelToken}) async {
    try {
      final res = await dio
          .get<Map<String, dynamic>>(
            _ipDetailSource,
            cancelToken: cancelToken,
            options: Options(responseType: ResponseType.json),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != HttpStatus.ok || res.data == null) {
        return Result.success(null);
      }
      return Result.success(IpInfo.fromIpApiIsJson(res.data!));
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return Result.error('cancelled');
      }
      commonPrint.log('fetchIpDetail error $e', logLevel: LogLevel.warning);
      return Result.success(null);
    }
  }

  /// 测一个地址的往返耗时，用来回答「现在到底能不能上外网」。
  ///
  /// 任何非超时的 HTTP 响应都算通，包括 403、404——目标是探测链路通不通，不是
  /// 探测页面存不存在。拿不到响应返回 null，由界面显示为不可达。
  Future<Duration?> measureLatency(
    String url, {
    CancelToken? cancelToken,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      await dio
          .get<dynamic>(
            url,
            cancelToken: cancelToken,
            options: Options(
              responseType: ResponseType.plain,
              followRedirects: false,
              validateStatus: (_) => true,
            ),
          )
          .timeout(timeout);
      return stopwatch.elapsed;
    } catch (e) {
      commonPrint.log('measureLatency $url failed', logLevel: LogLevel.info);
      return null;
    } finally {
      stopwatch.stop();
    }
  }

  /// 只走 IPv6 的地址。域名本身没有 A 记录，连得上就说明这条链路真的有 IPv6。
  static const _ipv6Source = 'https://v6.ident.me';

  /// 查当前出口有没有 IPv6，有就返回那个地址，没有返回 null。
  ///
  /// 很多机场只给 IPv4，而部分网站（尤其是家宽 + 双栈环境）会优先走 IPv6 绕过
  /// 代理，这一项能直接看出有没有这个风险。
  Future<String?> checkIpv6({CancelToken? cancelToken}) async {
    try {
      final res = await dio
          .get<String>(
            _ipv6Source,
            cancelToken: cancelToken,
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(seconds: 8));
      final address = res.data?.trim();
      // 返回体必须真的像个 IPv6 地址；有些劫持页面会回 200 加一段 HTML。
      if (address == null || !address.contains(':') || address.contains('<')) {
        return null;
      }
      return address;
    } catch (e) {
      commonPrint.log('checkIpv6 failed', logLevel: LogLevel.info);
      return null;
    }
  }
}

final request = Request();
