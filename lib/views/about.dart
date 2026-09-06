import 'dart:async';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/l10n/l10n.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/list.dart';
import 'package:clash_party/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class Contributor {
  final String avatar;
  final String name;
  final String link;

  const Contributor({
    required this.avatar,
    required this.name,
    required this.link,
  });
}

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  /// 「更多」组。
  ///
  /// **没有「检查更新」这一项**：自用构建没有发布渠道，`request.checkForUpdate`
  /// 已经被短路成直接返回「已是最新」。留着一个点了永远说「已是最新」、其实一次
  /// 都没查过的按钮，是界面在骗人。要恢复它得先有真实的更新源。
  ///
  /// **也没有「项目」和 Telegram**：改名时按新名字拼出来的 `chen08209/ClashParty`
  /// 和 `t.me/ClashParty` 都不存在，点了是 404。自用构建本来就没有对外的项目页
  /// 和交流群，与其挂两个死链接不如不挂。
  List<Widget> _buildMoreSection(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    // 带前置图标 + 分隔线，和「设置」页里的分组卡片是同一套形态；
    // 原来无图标、无分隔线，看着像另一个应用的页面。
    return generateSection(
      title: appLocalizations.more,
      items: [
        ListItem(
          leading: const Icon(Icons.memory),
          title: Text(appLocalizations.core),
          onTap: () {
            // 指向真正在用的内核仓库。原来写的是 chen08209/Clash.Meta 的
            // ClashParty 分支，那是改名时按新名字拼出来的，实际不存在。
            globalState.openUrl('https://github.com/vernesong/mihomo');
          },
          trailing: const Icon(Icons.launch, size: 18),
        ),
      ],
    );
  }

  List<Widget> _buildContributorsSection(AppLocalizations appLocalizations) {
    const contributors = [
      Contributor(
        avatar: 'assets/images/avatar/june2.jpg',
        name: 'June2',
        link: 'https://t.me/Jibadong',
      ),
      Contributor(
        avatar: 'assets/images/avatar/arue.jpg',
        name: 'Arue',
        link: 'https://t.me/xrcm6868',
      ),
    ];
    return generateSection(
      separated: false,
      title: appLocalizations.otherContributors,
      items: [
        ListItem(
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 24,
              children: [
                for (final contributor in contributors)
                  Avatar(contributor: contributor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final items = [
      // 应用标识块原来是裸的 ListTile 平铺在页面上，和下面两组圆角卡片不是一个
      // 观感；套进无标题的分组卡片后，整页三块都是同一种卡片。
      ...generateSection(
        items: [
          ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer(
                  builder: (_, ref, _) {
                    return _DeveloperModeDetector(
                      child: Wrap(
                        spacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              'assets/images/icon.png',
                              width: 64,
                              height: 64,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appName,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              Text(
                                globalState.packageInfo.version,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ],
                      ),
                      onEnterDeveloperMode: () {
                        ref
                            .read(appSettingProvider.notifier)
                            .update(
                              (state) => state.copyWith(developerMode: true),
                            );
                        context.showNotifier(
                          appLocalizations.developerModeEnableTip,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  appLocalizations.desc,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      ..._buildContributorsSection(appLocalizations),
      ..._buildMoreSection(context),
    ];
    return BaseScaffold(
      title: appLocalizations.about,
      body: Padding(
        padding: kMaterialListPadding.copyWith(top: 16, bottom: 16),
        child: generateListView(items),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final Contributor contributor;

  const Avatar({super.key, required this.contributor});

  @override
  Widget build(BuildContext context) {
    // 原来 onTap 被注释掉了，等于挂了个 GestureDetector 却什么都不做；
    // 贡献者本来就带链接，点开它才是这块存在的意义。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        globalState.openUrl(contributor.link);
      },
      child: Column(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircleAvatar(
              foregroundImage: AssetImage(contributor.avatar),
            ),
          ),
          const SizedBox(height: 4),
          Text(contributor.name, style: context.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
