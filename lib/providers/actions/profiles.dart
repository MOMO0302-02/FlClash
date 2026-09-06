part of '../action.dart';

/// 订阅下载的总预算。
///
/// `request.getFileResponseForUrl` 用的那个 `Dio()` 没配 `connectTimeout` /
/// `receiveTimeout`，`Profile.update()` 也没有 `.timeout()`：只要服务器完成了
/// 握手却迟迟不发响应体（域名被墙、机场挂了但端口还开着），这条 Future 就
/// **永远不会结束**。界面上的表现是配置页顶部那条进度条一直走、卡片上的转圈
/// 一直转，既没有结果也没有取消入口——模拟器上实测挂了 4 分钟仍在转。
///
/// 这里给的是「整趟」预算（下载 + 内核校验 + 落盘），超了就当失败报出来。
/// 注意 `Future.timeout` 只是不再等，底层那条连接不会被掐掉——真正的取消要在
/// `request` 里挂 `CancelToken`，那不在本次范围内。
const _profileNetworkTimeout = Duration(seconds: 60);

Future<T> _withProfileNetworkTimeout<T>(Future<T> future) {
  return future.withTimeout(
    timeout: _profileNetworkTimeout,
    onTimeout: () => throw currentAppLocalizations.profileUpdateTimeoutTip,
  );
}

@Riverpod(keepAlive: true)
class ProfilesAction extends _$ProfilesAction {
  @override
  void build() {}

  /// 压栈打开配置页。
  ///
  /// 加订阅的几条路径（选文件、粘链接、`clash://` 深链、Sub-Store 导入）原来都是
  /// **清空页面栈 + 把主页切到配置页**。那样落到的是 PageView 里那份常驻的配置
  /// 页——不是压出来的，左上角没有返回箭头，按系统返回会直接退出应用。
  ///
  /// 改成压栈之后，看完订阅按一下返回就回仪表盘。
  ///
  /// **要先清掉已有的栈**：不然连续加两条订阅会叠出两层配置页，得按两次返回。
  void _openProfiles() {
    final navigator = globalState.navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    // 这里没有 BuildContext，只能用全局 key 拿 navigator，所以不走
    // BaseNavigator.push（它要 context）。手机上 CommonRoute 就是它内部用的那个。
    navigator.push(CommonRoute(builder: (_) => const ProfilesView()));
  }

  void updateCurrentSelectedMap(String groupName, String proxyName) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile != null &&
        currentProfile.selectedMap[groupName] != proxyName) {
      final selectedMap = Map<String, String>.from(currentProfile.selectedMap)
        ..[groupName] = proxyName;
      ref
          .read(profilesProvider.notifier)
          .put(currentProfile.copyWith(selectedMap: selectedMap));
    }
  }

  Future<void> deleteProfile(int id) async {
    await ref.read(profilesProvider.notifier).del(id);
    await clearEffect(id);
    final currentProfileId = ref.read(currentProfileIdProvider);
    if (currentProfileId == id) {
      final profiles = ref.read(profilesProvider);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        ref.read(currentProfileIdProvider.notifier).value = updateId;
      } else {
        ref.read(currentProfileIdProvider.notifier).value = null;
        ref.read(setupActionProvider.notifier).setRunning(false);
      }
    }
  }

  Future<void> autoUpdateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (!profile.autoUpdate) continue;
      final isNotNeedUpdate = profile.lastUpdateDate
          ?.add(profile.autoUpdateDuration)
          .isBeforeNow;
      if (isNotNeedUpdate == false || profile.type == ProfileType.file) {
        continue;
      }
      try {
        await updateProfile(profile);
        _autoUpdateFailures.remove(profile.id);
      } catch (e) {
        commonPrint.log(e.toString(), logLevel: LogLevel.warning);
        _noteAutoUpdateFailure(profile);
      }
    }
  }

  /// 每条订阅「连着失败了几次」。只活在内存里，不进配置。
  final Map<int, int> _autoUpdateFailures = {};

  /// 自动更新失败到什么程度才值得打扰用户。
  ///
  /// 后台任务 20 分钟跑一次（application.dart:110），偶发一次失败下一轮多半就好
  /// 了，为它弹提示纯属噪音。但连着三次（≈1 小时）通常意味着订阅地址或 token
  /// 已经废了——这件事后台再重试多少遍也不会好，只有用户能处理，而现状是它
  /// **只写日志**：卡片上的流量、到期日就一直停在旧值，用户完全不知道自己的
  /// 订阅早就停更了。
  ///
  /// 只在第 3 次那一下说一次。之后继续失败不再重复，免得每 20 分钟骚扰一遍；
  /// 成功一次就清零，下一轮连败会重新计数。
  static const _autoUpdateFailureNoticeThreshold = 3;

  void _noteAutoUpdateFailure(Profile profile) {
    final count = (_autoUpdateFailures[profile.id] ?? 0) + 1;
    _autoUpdateFailures[profile.id] = count;
    if (count != _autoUpdateFailureNoticeThreshold) {
      return;
    }
    globalState.showNotifier(
      currentAppLocalizations.profileAutoUpdateFailedTip(profile.realLabel),
    );
  }

  void putProfile(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (ref.read(currentProfileIdProvider) != null) return;
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }

  Future<void> updateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (profile.type == ProfileType.file) continue;
      await updateProfile(profile);
    }
  }

  Future<void> updateProfile(
    Profile profile, {
    bool showLoading = false,
  }) async {
    try {
      if (showLoading) {
        ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = true;
      }
      ref.read(profilesProvider.notifier).put(profile);
      final newProfile = await _withProfileNetworkTimeout(profile.update());
      ref.read(profilesProvider.notifier).put(newProfile);
      if (profile.id == ref.read(currentProfileIdProvider)) {
        ref
            .read(setupActionProvider.notifier)
            .applyProfileDebounce(silence: true);
      }
    } finally {
      // 只有自己点亮过才负责熄灭。后台定时任务 updateAllProfiles 走的是
      // showLoading: false 那条路；它跑完时若无条件清零，会把用户手动点同步
      // 时正在转的那个圈也一起关掉——转圈没了、按钮回来了，用户以为完事再点
      // 一次，同一个订阅就被并发更新两遍（两条路都会写同一个配置文件）。
      if (showLoading) {
        ref.read(isUpdatingProvider(profile.updatingKey).notifier).value =
            false;
      }
    }
  }

  Future<void> addProfileFormFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile == null) return;
    final bytes = await platformFile.readBytes();
    // 加完订阅**压栈**打开配置页，不再「清空栈 + 切页」。
    //
    // 原来的写法会把用户丢到主页 PageView 里那份常驻的配置页上——那一份不是压
    // 出来的，所以左上角没有返回箭头，按系统返回还会直接退出应用。返回键那一轮
    // 已经给切页进来的页面补上了箭头，但「压栈打开」本身才是更顺的交互：看完订阅
    // 一按返回就回到仪表盘，而不是停在一个平级的页面上。
    _openProfiles();
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () async {
        return Profile.normal(label: platformFile.name).saveFile(bytes);
      },
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  /// [label] 给调用方一个「我已经知道这条订阅叫什么」的机会。
  ///
  /// Sub-Store 列表里每条订阅本来就带着名字，不传的话订阅落地后只会拿到
  /// Content-Disposition 里的文件名或者一串雪花 ID，用户回到订阅页认不出是哪条。
  /// `Profile.update()` 里用的是 `label.takeFirstValid(...)`，所以传了就以传的为准。
  Future<void> addProfileFormURL(String url, {String? label}) async {
    _openProfiles();
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () async {
        return _withProfileNetworkTimeout(
          Profile.normal(
            label: label,
            url: url,
          ).update(fallbackLabel: _nextDefaultLabel()),
        );
      },
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  /// 订阅自己没说名字时用的「配置 N」。
  ///
  /// N 从 1 开始，**跳过已经被占用的号**：连着导入三条得到配置 1/2/3；删掉中间
  /// 那条再导入会补回配置 2，而不是直接跳到配置 4。
  ///
  /// 复用已有的 `profile` 文案（中文「配置」/英文 Profile）后面拼数字，不为这
  /// 一处新增一个带参数的消息——四种语言的语序都能这么拼。
  String _nextDefaultLabel() {
    final prefix = currentAppLocalizations.profile;
    final used = ref.read(profilesProvider).map((item) => item.label).toSet();
    for (var index = 1; index <= used.length + 1; index++) {
      final candidate = '$prefix $index';
      if (!used.contains(candidate)) {
        return candidate;
      }
    }
    return '$prefix ${used.length + 1}';
  }

  void setProfileAndAutoApply(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (profile.id == ref.read(currentProfileIdProvider)) {
      ref.read(setupActionProvider.notifier).applyProfileDebounce();
    }
  }

  Future<void> addProfileFormQrCode() async {
    final url = await globalState.safeRun(picker.pickerConfigQRCode);
    if (url == null) return;
    addProfileFormURL(url);
  }

  void reorder(List<Profile> profiles) {
    ref.read(profilesProvider.notifier).reorder(profiles);
  }

  Future<void> clearEffect(int profileId) async {
    final profilePath = await appPath.getProfilePath(profileId.toString());
    final profileFile = File(profilePath);
    final isExists = await profileFile.exists();
    if (isExists) {
      await profileFile.safeDelete(recursive: true);
    }
    final error = await coreController.clearEffect(profileId);
    if (error.isNotEmpty) {
      commonPrint.log(error, logLevel: LogLevel.warning);
    }
  }
}
