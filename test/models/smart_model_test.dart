import 'dart:convert';

import 'package:clash_party/views/config/smart_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// 模型文件的"完整性"判断。
///
/// 钉住的是一件**平时看不出来、坏了也没人发现**的事：一个下载到一半的
/// `Model.bin` 和一个完整的模型**开头一模一样**（都是 `tree`），只有结尾能把它们
/// 分开。真实事故里就是这样：用户机器上 2,231,744 字节的残片让内核每次配置检查
/// 都硬失败、彻底起不来，而残片和 21,422,159 字节的完整文件光看开头分辨不出来。
///
/// 如果哪天有人"简化"成只看开头，这一组测试要变红。
void main() {
  /// 拼一段"看起来像模型"的字节。
  ///
  /// 头尾都照着真文件写：真的 `Model.bin` 第一行是 `tree`，最后一行是
  /// `[/target_enhance]`（本机那份 9,345,218 字节的标准版实测如此）。
  List<int> buildModel({
    String header = 'tree\nversion=v4\nnum_class=1\n',
    String body = '',
    String footer = '[/target_enhance]\n',
  }) {
    // 保证比探测窗口长，否则会先被"太短"那条拦掉，测不到我们想测的分支。
    final padding = 'x' * (smartModelProbeSize * 4);
    return utf8.encode('$header$padding$body$footer');
  }

  group('smartModelBytesLookComplete', () {
    test('头是 tree、尾是 [/target_enhance] 的算完整', () {
      expect(smartModelBytesLookComplete(buildModel()), isTrue);
    });

    test('尾部断在一个数字中间的残片认得出来——这正是真实事故里那种文件', () {
      // 真实残片的结尾就是这个形状：一行 key=value 写了一半。
      final truncated = buildModel(footer: 'target_weight_q75=1.17');
      expect(smartModelBytesLookComplete(truncated), isFalse);
    });

    test('开头对、结尾整段缺失也算不完整', () {
      expect(smartModelBytesLookComplete(buildModel(footer: '')), isFalse);
    });

    test('结尾对但开头不是 tree 的不算——那不是 LightGBM 的文本模型', () {
      expect(
        smartModelBytesLookComplete(buildModel(header: '<html>404\n')),
        isFalse,
      );
    });

    test('结尾后面有多余空白仍算完整', () {
      expect(
        smartModelBytesLookComplete(buildModel(footer: '[/target_enhance]\n\n')),
        isTrue,
      );
    });

    test('空文件不算完整', () {
      expect(smartModelBytesLookComplete(const <int>[]), isFalse);
    });

    test('比探测窗口还短的一律不算——最小的模型也有 9 MB', () {
      final tiny = utf8.encode('tree\n[/target_enhance]\n');
      expect(tiny.length, lessThan(smartModelProbeSize));
      expect(smartModelBytesLookComplete(tiny), isFalse);
    });

    test('非 UTF-8 的任意二进制不会抛异常，只会判成不完整', () {
      final garbage = List<int>.filled(smartModelProbeSize * 4, 0xFF);
      expect(smartModelBytesLookComplete(garbage), isFalse);
    });
  });

  group('smartModelLooksComplete 的头尾探测', () {
    test('长度为 0 时直接不算完整，哪怕头尾都对', () {
      expect(
        smartModelLooksComplete(
          head: utf8.encode('tree\n'),
          tail: utf8.encode('[/target_enhance]\n'),
          length: 0,
        ),
        isFalse,
      );
    });

    test('只给头尾两段也能判完整——真读文件时就是这么读的，不读中间那 26 MB', () {
      expect(
        smartModelLooksComplete(
          head: utf8.encode('tree\nversion=v4\n'),
          tail: utf8.encode('target_weight_nonzero_ratio=100.00\n'
              '[/target_enhance]\n'),
          length: 9345218,
        ),
        isTrue,
      );
    });
  });

  group('默认下载地址', () {
    test('就是内核内置的那个，别改成别的域名', () {
      expect(
        defaultSmartModelUrl,
        'https://github.com/vernesong/mihomo/releases/download/'
        'LightGBM-Model/Model.bin',
      );
    });
  });
}
