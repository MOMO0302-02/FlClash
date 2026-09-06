import 'package:clash_party/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

/// 仪表盘磁贴不能有功能重复的。
///
/// **来历**：用户把全部磁贴摊开后一眼看出「Proxies」出现两次、「Profiles」出现
/// 两次——同名、同图标、同目标页，只差下面那行字（一个显示数量、一个显示当前
/// 选中）。摊开之前每行只有两块，这个重复一直没被发现。
///
/// 这条测试**扫的是枚举里各磁贴打开的目标页**：两块磁贴指向同一个页面，就是
/// 「用户点哪块都一样」，那它们本该合成一块。
///
/// 为什么不去渲染界面比图：磁贴是十几个各自独立的组件，搭出真实环境的成本远高于
/// 它能挡住的问题；而「有没有两块磁贴干同一件事」恰恰是一次源码扫描就能钉死的。
void main() {
  test('没有两块磁贴打开同一个页面', () {
    // 每块磁贴点下去打开什么。null = 不跳页（就地开关、或弹出自己的面板）。
    //
    // **这张表要手工维护**：新增磁贴时把它的目标页填进来。漏填会被下面那条
    // 「表要覆盖全部磁贴」拦住，不会静默漏过。
    const targets = <DashboardWidget, String?>{
      DashboardWidget.statusHero: 'NetworkSpeedDetailView',
      DashboardWidget.trafficUsage: 'TrafficUsageDetailView',
      DashboardWidget.networkDetection: 'NetworkDetectionDetailView',
      DashboardWidget.tunButton: null,
      DashboardWidget.vpnButton: null,
      DashboardWidget.systemProxyButton: null,
      DashboardWidget.smartRoutingButton: 'SmartView',
      DashboardWidget.intranetIp: 'IntranetIpDetailView',
      DashboardWidget.proxyGroupTile: 'ProxiesView',
      DashboardWidget.profileTile: 'ProfilesView',
      DashboardWidget.connectionTile: 'ConnectionsView',
      DashboardWidget.requestTile: 'RequestsView',
      DashboardWidget.logTile: 'LogsView',
      DashboardWidget.resourceTile: 'ResourcesView',
      DashboardWidget.settingTile: 'ToolsView',
      DashboardWidget.memoryInfo: 'MemoryInfoDetailView',
      DashboardWidget.outboundModeV2: null,
    };

    // 先确认这张表没漏磁贴——漏了的话下面的重复检查会假装通过。
    final missing = DashboardWidget.values
        .where((item) => !targets.containsKey(item))
        .map((item) => item.name)
        .toList();
    expect(
      missing,
      isEmpty,
      reason:
          '这些磁贴没登记目标页：${missing.join('、')}。\n'
          '新增磁贴时请一并填进本测试的 targets 表——否则重复检查会漏掉它。',
    );

    // 同一个目标页被两块以上磁贴指向 = 重复。
    final byTarget = <String, List<String>>{};
    targets.forEach((widget, target) {
      if (target != null) {
        byTarget.putIfAbsent(target, () => []).add(widget.name);
      }
    });
    final duplicates = byTarget.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => '${entry.key} ← ${entry.value.join('、')}')
        .toList();

    expect(
      duplicates,
      isEmpty,
      reason:
          '这些磁贴打开的是同一个页面，用户点哪块都一样：\n${duplicates.join('\n')}\n'
          '应该合成一块（把两边各自多出来的信息并进去），而不是并排放两块。',
    );
  });

  test('没有两块磁贴用同一个组件', () {
    // 同一个 child 组件出现两次，等于同一块磁贴被登记了两遍。
    final byRuntimeType = <String, List<String>>{};
    for (final item in DashboardWidget.values) {
      byRuntimeType
          .putIfAbsent(item.widget.child.runtimeType.toString(), () => [])
          .add(item.name);
    }
    final duplicates = byRuntimeType.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => '${entry.key} ← ${entry.value.join('、')}')
        .toList();

    expect(duplicates, isEmpty, reason: '同一个组件被登记成了多块磁贴：\n${duplicates.join('\n')}');
  });
}
