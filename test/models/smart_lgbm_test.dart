import 'package:clash_party/common/common.dart';
import 'package:clash_party/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// 模型自动更新那三个全局键，以及「仅 Wi-Fi」那道闸。
///
/// 钉住三件平时看不出来、坏了也没人发现的事：
///
/// 1. **「仅 Wi-Fi」只能在应用侧把关。** 内核不知道自己现在走的是 Wi-Fi 还是
///    蜂窝——下载是它自己发起的。所以闸门是「不在 Wi-Fi 上就干脆不下发
///    `lgbm-auto-update: true`」。这道闸一旦失效，用户会在完全不知情的情况下
///    被扣掉几十兆流量，**而且没有任何报错**。
/// 2. **这三个键是全局顶层键，不是代理组级的。** 写进代理组内核根本不读
///    （内核 `config/config.go` 的 `RawConfig` 直接挂着它们）。写错层级的后果
///    同样是"看着配置对、实际没生效"。
/// 3. **关着时一个键都不写。** 内核默认就不自动更新。
void main() {
  group('lgbmAutoUpdateNow：仅 Wi-Fi 那道闸', () {
    test('没开自动更新时，在不在 Wi-Fi 上都不更新', () {
      const off = SmartOptions(lgbmAutoUpdate: false, lgbmWifiOnly: true);
      expect(off.copyWith(onWifi: true).lgbmAutoUpdateNow, isFalse);
      expect(off.copyWith(onWifi: false).lgbmAutoUpdateNow, isFalse);
    });

    test('开了自动更新 + 仅 Wi-Fi：在 Wi-Fi 上才更新', () {
      const on = SmartOptions(lgbmAutoUpdate: true, lgbmWifiOnly: true);
      expect(on.copyWith(onWifi: true).lgbmAutoUpdateNow, isTrue);
      // 这一条就是那道闸本身：切到流量就当作没开。
      expect(on.copyWith(onWifi: false).lgbmAutoUpdateNow, isFalse);
    });

    test('关掉「仅 Wi-Fi」后，用流量也更新', () {
      const anyNetwork = SmartOptions(
        lgbmAutoUpdate: true,
        lgbmWifiOnly: false,
      );
      expect(anyNetwork.copyWith(onWifi: false).lgbmAutoUpdateNow, isTrue);
      expect(anyNetwork.copyWith(onWifi: true).lgbmAutoUpdateNow, isTrue);
    });
  });

  group('生成的配置里那三个全局键', () {
    /// 一份最小的、含一个 url-test 组的订阅——Smart 改写要有组可改。
    const rawConfig = <String, dynamic>{
      'proxy-groups': [
        {
          'name': 'Auto',
          'type': 'url-test',
          'proxies': ['A', 'B'],
        },
      ],
      'proxies': [
        {'name': 'A', 'type': 'direct'},
        {'name': 'B', 'type': 'direct'},
      ],
    };

    Future<YamlMap> generate(SmartOptions smart) async {
      final decoded = await decodeJSONTask<Map<String, dynamic>>(
        await encodeJSONTask(rawConfig),
      );
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 1,
          rawConfig: decoded,
          realPatchConfig: const PatchClashConfig(),
          overrideDns: true,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'test-ua',
          smart: smart,
        ),
      );
      return loadYaml(result.a) as YamlMap;
    }

    test('自动更新关着时，三个键一个都不写', () async {
      final config = await generate(
        const SmartOptions(enable: true, lgbmAutoUpdate: false),
      );
      expect(config.containsKey('lgbm-auto-update'), isFalse);
      expect(config.containsKey('lgbm-update-interval'), isFalse);
      expect(config.containsKey('lgbm-url'), isFalse);
    });

    test('开了自动更新且在 Wi-Fi 上：写在顶层，不在代理组里', () async {
      final config = await generate(
        const SmartOptions(
          enable: true,
          lgbmAutoUpdate: true,
          lgbmUpdateInterval: 72,
          onWifi: true,
        ),
      );
      // 断言写死字面量，不拿模型跟模型比——那样改坏模型两边一起变，永远绿。
      expect(config['lgbm-auto-update'], isTrue);
      expect(config['lgbm-update-interval'], 72);

      // 代理组里**不该**出现这三个键：内核不从那儿读。
      final group = (config['proxy-groups'] as YamlList).first as YamlMap;
      expect(group.containsKey('lgbm-auto-update'), isFalse);
      expect(group.containsKey('lgbm-update-interval'), isFalse);
    });

    test('仅 Wi-Fi 开着、当前在用流量：一个键都不下发', () async {
      final config = await generate(
        const SmartOptions(
          enable: true,
          lgbmAutoUpdate: true,
          lgbmWifiOnly: true,
          onWifi: false,
        ),
      );
      expect(config.containsKey('lgbm-auto-update'), isFalse);
      expect(config.containsKey('lgbm-update-interval'), isFalse);
    });

    test('地址留空就不写 lgbm-url——空串会顶掉内核内置的地址', () async {
      final config = await generate(
        const SmartOptions(
          enable: true,
          lgbmAutoUpdate: true,
          lgbmUrl: '',
          onWifi: true,
        ),
      );
      expect(config.containsKey('lgbm-url'), isFalse);
    });

    test('填了地址就原样写出去', () async {
      final config = await generate(
        const SmartOptions(
          enable: true,
          lgbmAutoUpdate: true,
          lgbmUrl: 'https://example.com/Model-large.bin',
          onWifi: true,
        ),
      );
      expect(config['lgbm-url'], 'https://example.com/Model-large.bin');
    });

    test('Smart 总开关关着时，自动更新的键也不写——组都换回 url-test 了', () async {
      final config = await generate(
        const SmartOptions(
          enable: false,
          lgbmAutoUpdate: true,
          onWifi: true,
        ),
      );
      expect(config.containsKey('lgbm-auto-update'), isFalse);
    });
  });
}
