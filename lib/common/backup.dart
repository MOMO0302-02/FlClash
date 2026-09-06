import 'dart:io';

/// 判断 [path] 处的备份包是不是加密的。
///
/// 只读 ZIP 第一个本地文件头（local file header）的通用标志位：签名是
/// `PK\x03\x04`，标志位（偏移 6，小端）的第 0 位为 1 即表示该条目已加密。
/// 备份是「整包一起加/不加密」，所以看第一个条目就够了。恢复时据此决定要不
/// 要向用户要密码——老的未加密备份因此仍能不输密码直接恢复。
///
/// 放在独立文件里（不引 l10n、不引隔离区代码）是为了能脱离整份应用单独做单测。
Future<bool> isBackupEncrypted(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    return false;
  }
  final raf = await file.open();
  try {
    final header = await raf.read(8);
    if (header.length < 8) {
      return false;
    }
    final isLocalHeader =
        header[0] == 0x50 &&
        header[1] == 0x4B &&
        header[2] == 0x03 &&
        header[3] == 0x04;
    if (!isLocalHeader) {
      return false;
    }
    final flags = header[6] | (header[7] << 8);
    return (flags & 0x1) != 0;
  } finally {
    await raf.close();
  }
}
