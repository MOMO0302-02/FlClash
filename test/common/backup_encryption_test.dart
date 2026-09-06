import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:clash_party/common/backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';

/// 备份加密相关的行为守卫。
///
/// 覆盖两件事：
/// 1. [isBackupEncrypted] 能靠 ZIP 头正确区分「加密 / 未加密 / 不是 zip」——恢复
///    流程据它决定要不要向用户要密码，判错了要么老备份被逼着输密码，要么加密备份
///    静默按明文处理。
/// 2. 加密备份确实解不开：没有密码 / 密码错误时内容读取必须抛错，正确密码能读回
///    原文——这就是「备份里的 WebDAV 账号密码和订阅 token 不再明文躺在 zip 里」
///    这条安全属性本身。
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_enc_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> writeSecretFile() async {
    final file = File(join(tempDir.path, 'config.json'));
    await file.writeAsString('{"dav":{"password":"SECRETVALUE"}}');
    return file;
  }

  Future<String> makeBackup({String? password}) async {
    final secret = await writeSecretFile();
    final zipPath = join(tempDir.path, 'backup.zip');
    final encoder = password != null
        ? ZipFileEncoder(password: password)
        : ZipFileEncoder();
    encoder.create(zipPath);
    await encoder.addFile(secret, 'config.json');
    await encoder.close();
    return zipPath;
  }

  group('isBackupEncrypted', () {
    test('reports true for a password-protected backup', () async {
      final zipPath = await makeBackup(password: 'hunter2');
      expect(await isBackupEncrypted(zipPath), isTrue);
    });

    test('reports false for a plain backup', () async {
      final zipPath = await makeBackup();
      expect(await isBackupEncrypted(zipPath), isFalse);
    });

    test('reports false for a file that is not a zip', () async {
      final file = File(join(tempDir.path, 'notzip.bin'));
      await file.writeAsString('this is definitely not a zip archive');
      expect(await isBackupEncrypted(file.path), isFalse);
    });

    test('reports false for a missing file', () async {
      expect(
        await isBackupEncrypted(join(tempDir.path, 'nope.zip')),
        isFalse,
      );
    });
  });

  group('encrypted backup content', () {
    test('the raw zip bytes no longer contain the plaintext secret', () async {
      final zipPath = await makeBackup(password: 'hunter2');
      final bytes = await File(zipPath).readAsBytes();
      final asString = String.fromCharCodes(bytes);
      expect(asString.contains('SECRETVALUE'), isFalse);
    });

    test('the plaintext secret is present in an unencrypted backup', () async {
      // 对照组：证明上一条不是因为压缩碰巧藏了字串——STORE 模式下明文原样可见。
      final secret = await writeSecretFile();
      final zipPath = join(tempDir.path, 'plain.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addFile(secret, 'config.json', 0);
      await encoder.close();
      final bytes = await File(zipPath).readAsBytes();
      expect(String.fromCharCodes(bytes).contains('SECRETVALUE'), isTrue);
    });

    test('correct password reads the original content back', () async {
      final zipPath = await makeBackup(password: 'hunter2');
      final input = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeStream(input, password: 'hunter2');
      final entry = archive.files.firstWhere((f) => f.name == 'config.json');
      final out = OutputMemoryStream();
      entry.writeContent(out);
      await input.close();
      expect(String.fromCharCodes(out.getBytes()), contains('SECRETVALUE'));
    });

    test('wrong password cannot read the content', () async {
      final zipPath = await makeBackup(password: 'hunter2');
      final input = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeStream(input, password: 'wrong');
      final entry = archive.files.firstWhere((f) => f.name == 'config.json');
      final out = OutputMemoryStream();
      expect(() => entry.writeContent(out), throwsA(anything));
      await input.close();
    });
  });
}
