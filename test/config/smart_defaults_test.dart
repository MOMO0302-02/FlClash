import 'package:clash_party/common/constant.dart';
import 'package:clash_party/common/smart_routing.dart';
import 'package:clash_party/models/config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smart 选路各项参数的默认值。
///
/// 用户要求「调整为最优数值」。**每一条都得有内核源码里的依据**，不能凭感觉——
/// 所以把结论和依据一起钉在这里：以后有人想改动其中任何一个，得先推翻对应的依据。
///
/// 前提：这些值在用户打开「Smart 选路」总开关之前**一个字节都不生效**，总开关
/// 本身仍然默认关（它会改写订阅里的代理组名和规则指向，不能替用户做主）。
void main() {
  const settings = AppSettingProps();

  group('该开的开', () {
    test('用 LightGBM 模型选路：开', () {
      // Smart 的全部意义就是用训练好的模型选路，关掉就退回启发式打分——
      // 开了 Smart 又不用模型等于白开。模型文件不在时内核会自己下载。
      expect(settings.smartUseLightGBM, isTrue);
    });

    test('模型自动更新：开', () {
      // 模型会过期。流量那头已经有闸——「只在 Wi-Fi 更新」默认开着，只有当前
      // 确实在 Wi-Fi 上才会真的下发 `lgbm-auto-update: true`。
      expect(settings.smartLgbmAutoUpdate, isTrue);
      expect(settings.smartLgbmWifiOnly, isTrue, reason: '这道闸是上一条成立的前提');
    });

    test('延迟去抖：150 毫秒', () {
      // 150 取自**内核自带的示例配置**（`docs/config.yaml:1723` 的
      // `# tolerance: 150`，url-test 组下，和 Smart 组是同一套比较逻辑）。
      //
      // 留 0 的话两个节点差 1 毫秒也要换。手机网络抖动大，结果是反复横跳、
      // 连接被反复重建。
      //
      // 不会盖掉模型的判断：`smart.go:674` 那次排序排的是**送进模型之前的
      // 候选集**，模型打分在后面。
      expect(settings.smartTolerance, defaultSmartTolerance);
      expect(defaultSmartTolerance, 150);
    });

    test('策略：粘性会话', () {
      // 同一条会话固定走一个节点，否则同一个页面的多个请求会散到不同出口。
      expect(settings.smartStrategy, smartStrategyStickySessions);
    });
  });

  group('该关的关——这几条不是"还没来得及调"，是查过源码之后故意留关的', () {
    test('收集数据：关', () {
      // 实测它**只**往 `smart_weight_data.csv` 写数据，供离线用 LightGBM v4.x
      // 训练（`component/smart/lightgbm/collector.go`）；运行时选路一点都不读它。
      // 本应用不能训练模型 → 开着就是白占最多 100 MB 磁盘。
      expect(settings.smartCollectData, isFalse);
    });

    test('采样率：1（全采样）', () {
      // 它只在 `smart.go:1419` 拦截**数据收集**，与选路无关；收集关着时这个值
      // 没有任何意义。
      expect(settings.smartSampleRate, 1.0);
    });

    test('按运营商归纳（prefer-asn）：关', () {
      // 它在选路路径上可能多做一次**阻塞的** DNS 解析（`smart.go:2005` 的
      // `resolver.ResolveIP`），还要把 10.8 MB 的 ASN 库读进内存。手机上代价
      // 明确、收益不确定，留给用户按需自己开。
      expect(settings.smartPreferAsn, isFalse);
    });

    test('Smart 总开关本身：关', () {
      // 打开它会改写订阅里的代理组名字和规则指向，不能替用户做主。
      // 上面那些"最优值"都要等用户主动打开这个开关才生效。
      expect(settings.smartRouting, isFalse);
    });
  });

  test('模型更新间隔沿用内核默认的 72 小时', () {
    expect(settings.smartLgbmUpdateInterval, defaultSmartLgbmInterval);
    expect(defaultSmartLgbmInterval, 72);
  });
}
