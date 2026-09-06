import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/pages/scan.dart' show resolveScannedProfileUrl;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class Picker {
  Future<PlatformFile?> pickerFile() async {
    return FilePicker.pickFile(initialDirectory: await appPath.downloadDirPath);
  }

  Future<String?> saveFile(String fileName, Uint8List bytes) async {
    final path = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    if (!system.isAndroid && path != null) {
      final file = File(path);
      await file.safeWriteAsBytes(bytes);
    }
    return path;
  }

  Future<String?> saveFileWithPath(String fileName, String localPath) async {
    final localFile = File(localPath);
    if (!await localFile.exists()) {
      await localFile.create(recursive: true);
    }
    final bytes = await localFile.readAsBytes();
    final path = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    await localFile.safeDelete();
    return path;
  }

  Future<String?> pickerConfigQRCode() async {
    final xFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xFile == null) {
      return null;
    }
    final controller = MobileScannerController();
    try {
      final capture = await controller.analyzeImage(
        xFile.path,
        formats: [BarcodeFormat.qrCode],
      );
      final raw = capture?.barcodes.firstOrNull?.rawValue;
      // **和相机走同一套判定。**
      //
      // 原来这里只认 `result.isUrl`，而最常见的订阅二维码 `clash://install-config
      // ?url=...` 不是 URL——于是同一个码，用摄像头扫得进去，从相册导入却报
      // 「请上传有效的二维码」。那不是"没识别出来"，是**说了错话**。
      //
      // `resolveScannedProfileUrl` 是扫码页用的那个纯函数：直链、clash:// 深链、
      // 以及扫码库自己判成 URL 的都认，是原判定的超集。
      final result = raw == null
          ? null
          : resolveScannedProfileUrl(raw, isUrlBarcode: raw.isUrl);
      if (result == null) {
        throw currentAppLocalizations.pleaseUploadValidQrcode;
      }
      return result;
    } finally {
      // 原来建了不放。每次从相册导入都会漏一个扫码控制器（连带它持有的相机资源）。
      await controller.dispose();
    }
  }
}

extension PlatformFileExt on PlatformFile {
  Future<Uint8List> readBytes() {
    return readAsBytes();
  }
}

final picker = Picker();
