import 'dart:async';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/profiles/preview.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'custom/custom.dart';
import 'script.dart';
import 'standard.dart';

class OverwriteView extends ConsumerStatefulWidget {
  final int profileId;

  const OverwriteView({super.key, required this.profileId});

  @override
  ConsumerState<OverwriteView> createState() => _OverwriteViewState();
}

class _OverwriteViewState extends ConsumerState<OverwriteView> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _handlePreview() async {
    final profile = ref.read(profileProvider(widget.profileId));
    if (profile == null) {
      return;
    }
    BaseNavigator.push<String>(context, PreviewProfileView(profile: profile));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ProfileIdProvider(
      profileId: widget.profileId,
      child: CommonScaffold(
        title: appLocalizations.override,
        actions: [
          CommonMinFilledButtonTheme(
            child: FilledButton(
              onPressed: _handlePreview,
              child: Text(appLocalizations.preview),
            ),
          ),
          const SizedBox(width: 8),
        ],
        body: const CustomScrollView(slivers: [_Title(), _Content()]),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    globalState.container.read(setupActionProvider.notifier).autoApplyProfile();
  }
}

class _Title extends ConsumerWidget {
  const _Title();

  String _getTitle(BuildContext context, OverwriteType type) {
    return switch (type) {
      OverwriteType.standard => context.appLocalizations.standard,
      OverwriteType.script => context.appLocalizations.script,
      OverwriteType.custom => context.appLocalizations.overwriteTypeCustom,
    };
  }

  IconData _getIcon(OverwriteType type) {
    return switch (type) {
      OverwriteType.standard => Icons.stars,
      OverwriteType.script => Icons.rocket,
      OverwriteType.custom => Icons.dashboard_customize,
    };
  }

  String _getDesc(BuildContext context, OverwriteType type) {
    return switch (type) {
      OverwriteType.standard => context.appLocalizations.standardModeDesc,
      OverwriteType.script => context.appLocalizations.scriptModeDesc,
      OverwriteType.custom => context.appLocalizations.overwriteTypeCustomDesc,
    };
  }

  void _handleChangeType(WidgetRef ref, int profileId, OverwriteType type) {
    ref.read(profilesProvider.notifier).updateProfile(profileId, (state) {
      return state.copyWith(overwriteType: type);
    });
  }

  @override
  Widget build(context, ref) {
    final appLocalizations = context.appLocalizations;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final overwriteType = ref.watch(overwriteTypeProvider(profileId));
    // 三种模式改成「一列带图标的行 + 选中的那条右边打蓝勾」的单选组，和代理页
    // 设置面板、设置页用的是同一套。原来是一排要横滑的胶囊卡片：放不下就得拖，
    // 看不出哪些是一组，而且三条说明只能显示当前选中那一条。
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: generateSection(
          title: appLocalizations.overrideMode,
          isFirst: true,
          items: [
            for (final type in OverwriteType.values)
              ListItem(
                leading: _OptionLeadingIcon(
                  icon: _getIcon(type),
                  selected: overwriteType == type,
                ),
                title: Text(_getTitle(context, type)),
                subtitle: Text(_getDesc(context, type)),
                // 对勾始终占位、只改透明度：三条说明文字长短不一，做成
                // null / Icon 的二选一会让整列文字在换模式时重新折行。
                trailing: _OptionCheckIcon(selected: overwriteType == type),
                onTap: () {
                  _handleChangeType(ref, profileId, type);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content();

  @override
  Widget build(BuildContext context, ref) {
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final overwriteType = ref.watch(overwriteTypeProvider(profileId));
    ref.listen(clashConfigProvider(profileId), (_, _) {});
    // 这里**故意没有**淡入淡出：三个分支返回的都是 sliver（可滚动的列表、
    // 可拖动排序的列表），而 Flutter 没有 sliver 版的 AnimatedSwitcher。硬把它们
    // 塞进盒子里再做切换会毁掉滚动和拖拽。要做只能改这三个页面的结构，超出本轮
    // 范围。
    return switch (overwriteType) {
      OverwriteType.standard => const StandardContent(),
      OverwriteType.script => const ScriptContent(),
      OverwriteType.custom => const CustomContent(),
    };
  }
}

/// 单选组里那个「选中的一条右边一个主色对勾」。
///
/// 与 `views/access.dart` 里的同名部件是同一份实现——真正该放的地方是
/// `widgets/list.dart` 的 `ListItem.radio`，但那是共享文件，本轮不动。
class _OptionCheckIcon extends StatelessWidget {
  const _OptionCheckIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1.0 : 0.0),
      duration: Motion.quick,
      curve: Motion.enter,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
      ),
      child: Icon(
        Icons.check,
        size: 20,
        color: context.styleTokens.accent(context.colorScheme),
      ),
    );
  }
}

/// 单选行左边的图标：选中时转主色，与对勾同一个时长。
class _OptionLeadingIcon extends StatelessWidget {
  const _OptionLeadingIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final accent = context.styleTokens.accent(colorScheme);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1.0 : 0.0),
      duration: Motion.quick,
      curve: Motion.move,
      builder: (_, t, _) => Icon(
        icon,
        size: 20,
        color: Color.lerp(colorScheme.onSurface, accent, t),
      ),
    );
  }
}
