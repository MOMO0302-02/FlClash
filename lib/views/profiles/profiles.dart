import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/plugins/app.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/views/profiles/overwrite/overwrite.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add.dart';
import 'edit.dart';
import 'preview.dart';

class ProfilesView extends StatefulWidget {
  const ProfilesView({super.key});

  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView> {
  Function? applyConfigDebounce;
  bool _isUpdating = false;

  // final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final context = _targetKey.currentContext;
    //   if (context == null) {
    //     return;
    //   }
    //   Scrollable.ensureVisible(
    //     context,
    //     duration: commonDuration,
    //     alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    //   );
    // });
  }

  void _handleShowAddExtendPage() {
    showExtend(
      globalState.navigatorKey.currentState!.context,
      builder: (_) {
        return AdaptiveSheetScaffold(
          body: AddProfileView(
            context: globalState.navigatorKey.currentState!.context,
          ),
          title: context.appLocalizations.addProfile,
        );
      },
    );
  }

  Future<void> _updateProfiles(List<Profile> profiles) async {
    if (_isUpdating == true) {
      return;
    }
    _isUpdating = true;

    // ✅ 优化：显示进度对话框
    final progressNotifier = ValueNotifier<double>(0.0);
    final completedNotifier = ValueNotifier<int>(0);
    final totalProfiles = profiles.where((p) => p.type != ProfileType.file).length;

    if (totalProfiles > 1 && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ValueListenableBuilder(
          valueListenable: progressNotifier,
          builder: (_, progress, __) => ValueListenableBuilder(
            valueListenable: completedNotifier,
            builder: (_, completed, __) => AlertDialog(
              title: Text(context.appLocalizations.update),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text('$completed / $totalProfiles'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final List<UpdatingMessage> messages = [];
    int completed = 0;
    final updateProfiles = profiles.map<Future>((profile) async {
      if (profile.type == ProfileType.file) return;
      try {
        await globalState.container
            .read(profilesActionProvider.notifier)
            .updateProfile(profile, showLoading: totalProfiles == 1);
      } catch (e) {
        messages.add(
          UpdatingMessage(label: profile.realLabel, message: e.toString()),
        );
      } finally {
        completed++;
        completedNotifier.value = completed;
        progressNotifier.value = completed / totalProfiles;
      }
    });
    await Future.wait(updateProfiles);

    // 关闭进度对话框
    if (totalProfiles > 1 && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (messages.isNotEmpty) {
      globalState.showAllUpdatingMessagesDialog(messages);
    }
    _isUpdating = false;
  }

  List<Widget> _buildActions(List<Profile> profiles) {
    return profiles.isNotEmpty
        ? [
            IconButton(
              onPressed: () {
                _updateProfiles(profiles);
              },
              icon: const Icon(Icons.sync),
            ),
            IconButton(
              onPressed: () {
                showSheet(
                  context: context,
                  builder: (_) {
                    return ReorderableProfilesSheet(profiles: profiles);
                  },
                );
              },
              // 用默认尺寸。原来写死 26，而紧挨着的「同步」按钮走的是默认
              // 24——两个按钮并排，一个明显比另一个大。全应用的工具栏图标都是
              // 默认尺寸，这里没有理由特殊。
              icon: const Icon(Icons.sort),
            ),
          ]
        : [];
  }

  Widget _buildFAB() {
    return CommonFloatingActionButton(
      onPressed: _handleShowAddExtendPage,
      icon: const Icon(Icons.add),
      label: context.appLocalizations.addProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final appLocalizations = context.appLocalizations;
        final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
        final state = ref.watch(profilesStateProvider);
        final spacing = 14.mAp;
        return CommonScaffold(
          isLoading: isLoading,
          title: appLocalizations.profiles,
          // 空状态里已经有一个「添加订阅」按钮了，浮动按钮同时出现就是同一屏
          // 两个一模一样的动作。列表为空时让浮动按钮退场。
          floatingActionButton: state.profiles.isEmpty ? null : _buildFAB(),
          actions: _buildActions(state.profiles),
          body: state.profiles.isEmpty
              // 空状态给一个直达动作：这一页没有订阅时唯一该做的事就是加一个，
              // 只显示一行「暂无」等于让用户自己去找入口。
              ? NullStatus(
                  label: appLocalizations.nullProfileDesc,
                  illustration: const ProfileEmptyIllustration(),
                  action: FilledButton.icon(
                    onPressed: _handleShowAddExtendPage,
                    icon: const Icon(Icons.add),
                    label: Text(appLocalizations.addProfile),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const horizontalPadding = 16.0;
                    final columns = utils.getProfilesColumns(
                      constraints.maxWidth - horizontalPadding * 2,
                    );
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(
                        key: profilesStoreKey,
                        padding: const EdgeInsets.only(
                          left: horizontalPadding,
                          right: horizontalPadding,
                          top: 16,
                          bottom: 88,
                        ),
                        child: Grid(
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          crossAxisCount: columns,
                          children: [
                            for (int i = 0; i < state.profiles.length; i++)
                              GridItem(
                                child: ProfileItem(
                                  profile: state.profiles[i],
                                  groupValue: state.currentProfileId,
                                  onChanged: (profileId) {
                                    ref
                                            .read(
                                              currentProfileIdProvider.notifier,
                                            )
                                            .value =
                                        profileId;
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class ProfileItem extends StatelessWidget {
  final Profile profile;
  final int? groupValue;
  final void Function(int? value) onChanged;

  const ProfileItem({
    super.key,
    required this.profile,
    required this.groupValue,
    required this.onChanged,
  });

  Future<void> _handleDeleteProfile(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.profile),
      ),
    );
    if (res != true) {
      return;
    }
    await globalState.container
        .read(profilesActionProvider.notifier)
        .deleteProfile(profile.id);
  }

  Future<void> _handlePreview(BuildContext context) async {
    BaseNavigator.push<String>(context, PreviewProfileView(profile: profile));
  }

  Future updateProfile() async {
    if (profile.type == ProfileType.file) return;
    await globalState.loadingRun(() async {
      await globalState.container
          .read(profilesActionProvider.notifier)
          .updateProfile(profile, showLoading: true);
    }, tag: LoadingTag.profiles);
  }

  void _handleShowEditExtendPage(BuildContext context) {
    showExtend(
      context,
      builder: (_) {
        return AdaptiveSheetScaffold(
          body: EditProfileView(profile: profile, context: context),
          title: context.appLocalizations.edit,
        );
      },
    );
  }

  /// 卡片下半部分。分支口径照抄桌面端 `profile-item.tsx`：
  /// 机场给了用量信息就只显示「流量 / 到期 + 进度条」，没有用量信息才退回
  /// 「类型角标 + 更新时间」那一行。桌面端两者不同时出现，这里保持一致，
  /// 免得一张卡上堆两行意义重叠的小字。
  ///
  /// [selection] 是 0（未选中）到 1（选中）的过渡进度，不是布尔值——卡片底色是
  /// 渐变到主色的，这里的文字颜色必须跟着一起走，否则底色还在半路、字已经先变
  /// 白了。
  List<Widget> _buildInfo(BuildContext context, double selection) {
    final info = profile.subscriptionInfo;
    if (profile.type == ProfileType.url && info != null && info.total != 0) {
      return [
        const SizedBox(height: 10),
        SubscriptionInfoView(
          subscriptionInfo: info,
          // 选中的卡片整块填了主色，进度条和文字要跟着换成白系，否则看不清。
          // 这里只能给布尔值（SubscriptionInfoView 是共享部件），所以进度条的
          // 配色仍是一刀切的，过半就算切换，避免它比周围早半拍或晚半拍。
          onFilled: selection,
        ),
      ];
    }
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final accent = context.styleTokens.accent(colorScheme);
    // 角标颜色：未选中是主色，选中后卡片已是主色底，改用白色（桌面端
    // `border-primary text-primary` ↔ `border-primary-foreground`）。
    final chipColor = Color.lerp(
      accent,
      context.styleTokens.selectedForeground(colorScheme),
      selection,
    )!;
    return [
      const SizedBox(height: 10),
      Row(
        children: [
          _TypeChip(
            label: profile.type == ProfileType.url
                ? appLocalizations.url
                : appLocalizations.file,
            color: chipColor,
          ),
          const Spacer(),
          LastUpdateTimeText(
            lastUpdateDate: profile.lastUpdateDate,
            style: context.textTheme.labelMedium?.copyWith(
              color: Color.lerp(
                colorScheme.onSurfaceVariant,
                const Color(0xCCFFFFFF),
                selection,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _handleCopyLink(BuildContext context) async {
    // 订阅链接带 token。Android 13+ 走平台通道把剪贴板内容标成敏感，避免出现在
    // 复制预览、剪贴板历史和输入法里；标记不上（或非 Android）时回退到普通复制。
    final marked =
        (system.isAndroid
            ? await app?.setSensitiveClipboard(profile.url)
            : null) ??
        false;
    if (!marked) {
      await Clipboard.setData(ClipboardData(text: profile.url));
    }
    if (context.mounted) {
      context.showNotifier(context.appLocalizations.copySuccess);
    }
  }

  Future<void> _handleExportFile(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.safeRun<bool>(() async {
      final mFile = await profile.file;
      final label = profile.realLabel;
      final fileName = label.endsWith('.yaml') || label.endsWith('.yml')
          ? label
          : '$label.yaml';
      final value = await picker.saveFile(fileName, mFile.readAsBytesSync());
      if (value == null) return false;
      return true;
    }, title: appLocalizations.tip);
    if (res == true && context.mounted) {
      context.showNotifier(appLocalizations.exportSuccess);
    }
  }

  void _handlePushGenProfilePage(BuildContext context, int id) {
    BaseNavigator.push(context, OverwriteView(profileId: id));
  }

  Widget _buildMenu(BuildContext context, Color foreground) {
    final appLocalizations = context.appLocalizations;
    return CommonPopupBox(
      popup: CommonPopupMenu(
        items: [
          PopupMenuItemData(
            icon: Icons.edit_outlined,
            label: appLocalizations.edit,
            onPressed: () {
              _handleShowEditExtendPage(context);
            },
          ),
          PopupMenuItemData(
            icon: Icons.visibility_outlined,
            label: appLocalizations.preview,
            onPressed: () {
              _handlePreview(context);
            },
          ),
          PopupMenuItemData(
            icon: Icons.emergency_outlined,
            label: appLocalizations.more,
            subItems: [
              PopupMenuItemData(
                icon: Icons.extension_outlined,
                label: appLocalizations.override,
                onPressed: () {
                  _handlePushGenProfilePage(context, profile.id);
                },
              ),
              if (profile.type == ProfileType.url) ...[
                PopupMenuItemData(
                  icon: Icons.copy,
                  label: appLocalizations.copyLink,
                  onPressed: () {
                    _handleCopyLink(context);
                  },
                ),
              ],
              PopupMenuItemData(
                icon: Icons.file_copy_outlined,
                label: appLocalizations.exportFile,
                onPressed: () {
                  _handleExportFile(context);
                },
              ),
            ],
          ),
          PopupMenuItemData(
            danger: true,
            icon: Icons.delete_outlined,
            label: appLocalizations.delete,
            onPressed: () {
              _handleDeleteProfile(context);
            },
          ),
        ],
      ),
      targetBuilder: (open) {
        return _CardIconButton(
          icon: Icons.more_vert,
          color: foreground,
          onPressed: () => open(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = profile.id == groupValue;
    final tokens = context.styleTokens;
    final colorScheme = context.colorScheme;
    // 桌面端卡片里的字始终是 foreground（近白），选中后转 primary-foreground；
    // 不能靠按钮默认的 onSurfaceVariant，那是灰的，一眼就是 Material 默认样子。
    final restForeground = colorScheme.onSurface;
    final selectedForeground = tokens.selectedForeground(colorScheme);
    return CommonCard(
      key: Key(profile.id.toString()),
      enterActionsOnRight: true,
      isSelected: selected,
      onPressed: () {
        onChanged(profile.id);
      },
      // 卡片底色由 CommonCard 渐变到主色，但卡片里的字、角标、图标按钮是这里自己
      // 算的颜色——原来它们是「啪」地一下全变白，底色还在渐变途中，看起来像两件
      // 互不相干的事。用一条 0→1 的进度同时驱动全部前景色，整块才是一起翻过去的。
      //
      // 时长与 CommonCard 里那层阴影的 AnimatedContainer 对齐，都是 Motion.normal。
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1.0 : 0.0),
        duration: Motion.normal,
        curve: Motion.move,
        builder: (context, selection, _) {
          final foreground = Color.lerp(
            restForeground,
            selectedForeground,
            selection,
          )!;
          // 自己排版而不是套 ListTile：桌面端是「标题一行、操作按钮贴右上、
          // 信息在下」，ListTile 只能把 trailing 垂直居中，做不出这个结构。
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.realLabel,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile.type == ProfileType.url)
                      Consumer(
                        builder: (_, ref, _) {
                          final isUpdating = ref.watch(
                            isUpdatingProvider(profile.updatingKey),
                          );
                          // 更新按钮与转圈之间已经是淡入淡出（FadeThroughBox），
                          // 尺寸也固定成 36×36，所以开始更新时行宽不会跳。
                          return SizedBox(
                            width: 36,
                            height: 36,
                            child: FadeThroughBox(
                              child: isUpdating
                                  ? const Padding(
                                      key: ValueKey('loading'),
                                      padding: EdgeInsets.all(8),
                                      child: HeroSpinner(),
                                    )
                                  : _CardIconButton(
                                      key: const ValueKey('sync'),
                                      icon: Icons.refresh,
                                      color: foreground,
                                      onPressed: updateProfile,
                                    ),
                            ),
                          );
                        },
                      ),
                    _buildMenu(context, foreground),
                  ],
                ),
                ..._buildInfo(context, selection),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 卡片右上角的图标按钮。桌面端用的是 `variant="light"` 的小圆钮——无底色、
/// 图标跟着卡片前景走，选中时一起转白。
class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: Icon(icon, size: 20, color: color),
    );
  }
}

/// 订阅类型角标。桌面端是 HeroUI 的 `variant="bordered"` Chip：只有一圈描边和
/// 同色文字、内部透明；灰底实心块是 Material 的默认样子，不是这里要的。
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class LastUpdateTimeText extends StatelessWidget {
  final DateTime? lastUpdateDate;
  final TextStyle? style;

  const LastUpdateTimeText({
    super.key,
    required this.lastUpdateDate,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (lastUpdateDate == null) {
      return Text('', style: style);
    }
    return TickBuilder(
      duration: const Duration(minutes: 1),
      builder: (context, _) {
        return Text(
          lastUpdateDate!.getLastUpdateTimeDesc(context),
          style: style,
        );
      },
    );
  }
}

class ReorderableProfilesSheet extends StatefulWidget {
  final List<Profile> profiles;

  const ReorderableProfilesSheet({super.key, required this.profiles});

  @override
  State<ReorderableProfilesSheet> createState() =>
      _ReorderableProfilesSheetState();
}

class _ReorderableProfilesSheetState extends State<ReorderableProfilesSheet> {
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    profiles = List.from(widget.profiles);
  }

  Widget _buildItem(int index) {
    final position = ItemPosition.get(index, profiles.length);
    final profile = profiles[index];
    return ItemPositionProvider(
      key: Key(profile.id.toString()),
      position: position,
      child: DecorationListItem(
        trailing: ReorderableDelayedDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(profile.realLabel),
      ),
    );
  }

  void _handleSave() {
    Navigator.of(context).pop();
    globalState.container.read(profilesProvider.notifier).reorder(profiles);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return AdaptiveSheetScaffold(
      sheetTransparentToolBar: true,
      actions: [IconButtonData(icon: Icons.check, onPressed: _handleSave)],
      body: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(top: context.sheetTopPadding),
          proxyDecorator: (child, index, animation) {
            return commonProxyDecorator(_buildItem(index), index, animation);
          },
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              profiles = profiles.copyAndReorder(oldIndex, newIndex);
            });
          },
          itemBuilder: (_, index) {
            return _buildItem(index);
          },
          itemCount: profiles.length,
        ),
      ),
      title: appLocalizations.profilesSort,
    );
  }
}
