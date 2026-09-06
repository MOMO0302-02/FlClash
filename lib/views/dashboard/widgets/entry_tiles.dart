import 'package:clash_party/common/common.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/views/connection/connections.dart';
import 'package:clash_party/views/connection/requests.dart';
import 'package:clash_party/views/dashboard/widgets/dashboard_tile.dart';
import 'package:clash_party/views/logs.dart';
import 'package:clash_party/views/profiles/profiles.dart';
import 'package:clash_party/views/proxies/proxies.dart';
import 'package:clash_party/views/resources.dart';
import 'package:clash_party/views/tools.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 入口磁贴：图标在左上、可选的计数在右上、标题在左下，点击进入二级页面。
///
/// 这是 Clash Party 桌面版侧边栏那一列卡片在手机上的形态——主页就是一堵磁贴，
/// 不设常驻导航栏，点哪块进哪块。版式走 [DashboardTile]，和开关、Smart、内存等
/// 磁贴共用同一套「图标左上 / 附加信息右上 / 标题左下」。
///
/// **不再显示标题下面那行副标题（当前节点 / 当前订阅）。** 桌面端侧边栏这两块卡片
/// 就只有图标、计数、标题三样，没有副标题；那行小字是之前加的，用户嫌它把磁贴弄乱，
/// 而当前节点在「状态总览」那块大磁贴上本来就有。
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.count,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// 右上角的计数徽标。没有可统计的数量时留空。
  final String? count;

  @override
  Widget build(BuildContext context) {
    return DashboardTile(
      icon: icon,
      label: label,
      onTap: onTap,
      // 计数是等配置读完才有的，原来是「啪」地凭空出现一个角标。缩放淡入让它像
      // 长出来的，也顺带把「3 → 4」那种变化交代清楚。
      //
      // 这里**不**用 AnimatedCount：它是个整数计数，滚过 3.4、3.7 这些中间值毫无
      // 意义，格式化出来还是 3——只是让数字晚跳一会儿而已。
      trailing: AnimatedSwitcher(
        duration: Motion.normal,
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.exit,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: count == null
            ? const SizedBox.shrink()
            : DashboardCountBadge(count!, key: ValueKey(count)),
      ),
    );
  }
}

/// 代理组入口，带组数量。
class ProxyGroupTile extends ConsumerWidget {
  const ProxyGroupTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(currentGroupsStateProvider).value.length;
    return EntryTile(
      label: Intl.message('proxies'),
      icon: Icons.workspaces,
      count: count > 0 ? '$count' : null,
      // 用压栈而不是切换页面：没有常驻导航栏，切换过去就没有返回入口了。
      onTap: () => showExtend(context, builder: (_) => const ProxiesView()),
    );
  }
}

/// 订阅入口。
class ProfileTile extends ConsumerWidget {
  const ProfileTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(profilesProvider).length;
    return EntryTile(
      label: Intl.message('profiles'),
      icon: Icons.cloud_download,
      count: count > 0 ? '$count' : null,
      onTap: () => showExtend(context, builder: (_) => const ProfilesView()),
    );
  }
}

/// 连接入口。
class ConnectionTile extends StatelessWidget {
  const ConnectionTile({super.key});

  @override
  Widget build(BuildContext context) {
    return EntryTile(
      label: Intl.message('connections'),
      icon: Icons.swap_horiz,
      onTap: () => showExtend(context, builder: (_) => const ConnectionsView()),
    );
  }
}

/// 请求记录入口。
class RequestTile extends StatelessWidget {
  const RequestTile({super.key});

  @override
  Widget build(BuildContext context) {
    return EntryTile(
      label: Intl.message('requests'),
      icon: Icons.receipt_long,
      onTap: () => showExtend(context, builder: (_) => const RequestsView()),
    );
  }
}

/// 日志入口。
class LogTile extends StatelessWidget {
  const LogTile({super.key});

  @override
  Widget build(BuildContext context) {
    return EntryTile(
      label: Intl.message('logs'),
      icon: Icons.article_outlined,
      onTap: () => showExtend(context, builder: (_) => const LogsView()),
    );
  }
}

/// 外部资源入口。
class ResourceTile extends StatelessWidget {
  const ResourceTile({super.key});

  @override
  Widget build(BuildContext context) {
    return EntryTile(
      label: Intl.message('resources'),
      icon: Icons.storage,
      onTap: () => showExtend(context, builder: (_) => const ResourcesView()),
    );
  }
}

/// 设置入口（原来的「工具」页）。
class SettingTile extends StatelessWidget {
  const SettingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return EntryTile(
      label: Intl.message('tools'),
      icon: Icons.settings,
      onTap: () => showExtend(context, builder: (_) => const ToolsView()),
    );
  }
}
