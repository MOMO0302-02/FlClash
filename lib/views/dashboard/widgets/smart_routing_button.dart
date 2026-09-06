import 'package:clash_party/common/common.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/views/config/smart.dart';
import 'package:clash_party/views/dashboard/widgets/dashboard_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首页上的「Smart 内核」开关磁贴。
///
/// **为什么值得占首页一格**：这是唯一一个会改变"节点怎么被挑出来"的开关——开着
/// 由内核的 Smart 算法按历史表现挑，关掉就退回"谁快用谁"。用户想对比两种选路
/// 效果时会反复拨它，埋在设置里第二层太深。
///
/// 拨动后会自动重新下发整份配置（见 `core_manager.dart` 里那条监听），不需要
/// 手动重启内核。磁贴上的开关只管"开/关"这一件事；点卡片其它地方直接进 Smart
/// 内核设置页（模型、数据收集、策略、容差都在那儿）。
///
/// 版式和其它开关磁贴（虚拟网卡、系统代理）完全一致（[DashboardTile]）：图标左上、
/// 开关右上、标题左下，**没有任何状态文字**。
///
/// 标题用 `smartCore`（「Smart 内核」）而不是原来的 `smartRouting`（「自动 Smart
/// 覆写」）——这样磁贴标题、设置入口（`tools.dart`）、设置页标题（`smart.dart`）
/// 三处一致，都叫「Smart 内核」，不再各叫各的。
///
/// **模型未就绪的警告不放在磁贴上**：模型没下下来时内核只是安静地退回「按延迟挑」，
/// 但那条警告放在 Smart 二级设置页（模型状态那一行）更合适——首页磁贴保持纯净，
/// 和另外两块开关磁贴长得一模一样。
class SmartRoutingButton extends StatelessWidget {
  const SmartRoutingButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return DashboardTile(
      // 实心图标，和其它磁贴一套。
      // 用「大脑」而不是「闪光星星」。
      //
      // `auto_awesome` 那个闪光是泛指「AI 魔法」，几乎每个应用的每个智能功能都在
      // 用它——看到它并不知道这块磁贴具体干什么。而 Smart 内核做的事很具体：
      // **按历史表现自己学、自己挑节点**。大脑是这件事最直白的图形表达，也和
      // 旁边那些具象图标（云下载=订阅、齿轮=设置、内存条=内存）的表意方式一致。
      icon: Icons.psychology,
      label: appLocalizations.smartCore,
      onTap: () {
        BaseNavigator.push(context, const SmartView());
      },
      trailing: Consumer(
        builder: (_, ref, _) {
          final enable = ref.watch(
            appSettingProvider.select((state) => state.smartRouting),
          );
          return dashboardTileSwitch(
            value: enable,
            onChanged: (value) {
              ref
                  .read(appSettingProvider.notifier)
                  .update((state) => state.copyWith(smartRouting: value));
            },
          );
        },
      ),
    );
  }
}
