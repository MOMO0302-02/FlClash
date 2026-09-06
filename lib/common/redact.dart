/// 日志脱敏。
///
/// 订阅地址就是凭据本身：机场把账号 token 放在查询串（`?token=...`）里，也
/// 经常直接放在路径里（`/link/<token>`）。所以要判定「这条日志安不安全」，
/// 不能只看有没有 `password` 字样——**整条 URL 都得当成密码对待**。
///
/// 这里只保留「哪台服务器」这一点信息（scheme + host + port），足够排查
/// 连不上/证书错/走没走代理这类问题，但拿不到任何可复用的凭据。
library;

/// URL 中除了 scheme/host/port 以外一律不进日志。
///
/// 返回形如 `https://sub.example.com/…`，末尾的 `/…` 表示「这里原本还有
/// 路径或查询串，已删掉」。没有被删的东西时不加这个后缀，免得看日志的人
/// 以为丢了信息。
String redactUri(Uri uri) {
  final hasSecretPart =
      uri.path.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty;
  final suffix = hasSecretPart ? '/…' : '';

  // clash://install-config?url=… 这类有 host；mailto: 这类没有。
  if (uri.host.isEmpty) {
    return uri.hasScheme ? '${uri.scheme}:…' : '…';
  }

  final buffer = StringBuffer();
  if (uri.hasScheme) {
    buffer.write('${uri.scheme}://');
  }
  buffer.write(uri.host);
  if (uri.hasPort) {
    buffer.write(':${uri.port}');
  }
  buffer.write(suffix);
  return buffer.toString();
}

/// [redactUri] 的字符串版本。解析不了就整条丢掉——**不能原样返回**，
/// 解析失败往往正是因为里面有奇怪的凭据字符。
String redactUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return '<unparsable url>';
  }
  return redactUri(uri);
}

/// 传给内核的方法参数里，哪些键的值绝不能进日志。
///
/// `data` 是 sideLoadExternalProvider 的整份 proxy-provider 文件（节点密码、
/// UUID 都在里面）；其余是常见的凭据字段名。
const _sensitiveArgumentKeys = <String>{
  'data',
  'password',
  'secret',
  'token',
  'url',
  'uri',
  'proxy-providers',
  'rule-providers',
};

/// 超过这个长度的字符串一律不进日志：正常的调试参数（端口、开关、模式名）
/// 都很短，长字符串基本只可能是配置正文。
const _maxLoggedValueLength = 120;

/// 把内核方法参数变成「够排查问题、但不含凭据」的一行描述。
///
/// 保留端口、开关、模式名这类短标量（排查问题真正要看的东西），
/// 抹掉长文本与敏感键名对应的值。
String describeCoreArguments(Object? arguments) {
  if (arguments == null) {
    return 'null';
  }
  if (arguments is Map) {
    final parts = arguments.entries.map((entry) {
      final key = entry.key.toString();
      return '$key: ${_describeValue(key, entry.value)}';
    });
    return '{${parts.join(', ')}}';
  }
  return _describeValue(null, arguments);
}

String _describeValue(String? key, Object? value) {
  if (key != null && _sensitiveArgumentKeys.contains(key.toLowerCase())) {
    return '<redacted>';
  }
  if (value == null) {
    return 'null';
  }
  if (value is num || value is bool) {
    return '$value';
  }
  final text = value.toString();
  if (text.length > _maxLoggedValueLength) {
    return '<${text.length} chars>';
  }
  return text;
}
