import 'dart:async';
import 'dart:io';

import 'package:clash_party/common/backup.dart';
import 'package:clash_party/common/common.dart';
import 'package:clash_party/common/dav_client.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/action.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/dialog.dart';
import 'package:clash_party/widgets/fade_box.dart';
import 'package:clash_party/widgets/input.dart';
import 'package:clash_party/widgets/list.dart';
import 'package:clash_party/widgets/scaffold.dart';
import 'package:clash_party/widgets/text.dart';
import 'package:clash_party/widgets/hero_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BackupAndRestore extends ConsumerStatefulWidget {
  const BackupAndRestore({super.key});

  @override
  ConsumerState<BackupAndRestore> createState() => _BackupAndRestoreState();
}

class _BackupAndRestoreState extends ConsumerState<BackupAndRestore>
    with UniqueKeyStateMixin {
  final _davConnection = DAVConnectionController();

  @override
  void initState() {
    super.initState();
    ref.listenManual(davSettingProvider, (_, _) {
      _updateDAVClient();
    }, fireImmediately: true);
  }

  void _updateDAVClient() {
    unawaited(_davConnection.update(ref.read(davSettingProvider)));
  }

  @override
  void dispose() {
    _davConnection.dispose();
    super.dispose();
  }

  Future<void> _showAddWebDAV(DAVProps? dav) async {
    await globalState.showCommonDialog<String>(
      child: WebDAVFormDialog(dav: dav?.copyWith()),
    );
  }

  Future<void> _backupOnWebDAV() async {
    final appLocalizations = context.appLocalizations;
    final password = await _promptBackupPassword();
    if (password == null || !mounted) return;
    final res = await globalState.loadingRun<bool>(
      () async {
        final client = _davConnection.client;
        if (client == null) {
          return false;
        }
        final path = await globalState.container
            .read(backupActionProvider.notifier)
            .backup(password: password);
        if (path.isEmpty) {
          return false;
        }
        return client.backup(path);
      },
      tag: LoadingTag.backup_restore,
      title: appLocalizations.backup,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.backup,
      message: TextSpan(text: appLocalizations.backupSuccess),
    );
  }

  Future<void> _restoreOnWebDAV(RestoreOption option) async {
    final appLocalizations = context.appLocalizations;
    // 先只下载备份文件，下完再判断要不要密码——密码对话框不能开在「加载中」的
    // 遮罩里，所以下载和真正的恢复拆成两段 loadingRun。
    final downloaded = await globalState.loadingRun<bool>(
      () async {
        final client = _davConnection.client;
        if (client == null) {
          return false;
        }
        await client.restore();
        return true;
      },
      tag: LoadingTag.backup_restore,
      title: appLocalizations.restore,
    );
    if (downloaded != true || !mounted) return;
    final resolved = await _resolveRestorePassword();
    if (!resolved.proceed || !mounted) return;
    final res = await globalState.loadingRun<bool>(
      () async {
        await globalState.container
            .read(backupActionProvider.notifier)
            .restore(option, password: resolved.password);
        return true;
      },
      tag: LoadingTag.backup_restore,
      title: appLocalizations.restore,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.restore,
      message: TextSpan(text: appLocalizations.restoreSuccess),
    );
  }

  Future<void> _handleRestoreOnWebDAV() async {
    final restoreOption = await globalState.showCommonDialog<RestoreOption>(
      child: const RestoreOptionsDialog(),
    );
    if (restoreOption == null || !context.mounted) return;
    _restoreOnWebDAV(restoreOption);
  }

  Future<void> _backupOnLocal() async {
    final appLocalizations = context.appLocalizations;
    final password = await _promptBackupPassword();
    if (password == null || !mounted) return;
    final res = await globalState.loadingRun<bool>(
      () async {
        final path = await globalState.container
            .read(backupActionProvider.notifier)
            .backup(password: password);
        if (path.isEmpty) {
          return false;
        }
        final value = await picker.saveFileWithPath(
          utils.getBackupFileName(),
          path,
        );
        if (value == null) return false;
        return true;
      },
      title: appLocalizations.backup,
      tag: LoadingTag.backup_restore,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.backup,
      message: TextSpan(text: appLocalizations.backupSuccess),
    );
  }

  Future<void> _restoreOnLocal(RestoreOption option) async {
    final appLocalizations = context.appLocalizations;
    final file = await picker.pickerFile();
    final path = file?.path;
    if (path == null) return;
    await File(path).safeCopy(await appPath.backupFilePath);
    if (!mounted) return;
    final resolved = await _resolveRestorePassword();
    if (!resolved.proceed || !mounted) return;
    final res = await globalState.loadingRun<bool>(
      () async {
        await globalState.container
            .read(backupActionProvider.notifier)
            .restore(option, password: resolved.password);
        return true;
      },
      tag: LoadingTag.backup_restore,
      title: appLocalizations.restore,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.restore,
      message: TextSpan(text: appLocalizations.restoreSuccess),
    );
  }

  /// 弹「设置备份密码」对话框。返回用户输入的密码；取消返回 null（上层据此中止）。
  Future<String?> _promptBackupPassword() async {
    return globalState.showCommonDialog<String>(
      child: const _BackupPasswordDialog(isSetting: true),
    );
  }

  /// 判断刚下载/选中的备份要不要密码，需要就弹框要。
  ///
  /// 返回记录：[proceed] 为 false 表示用户取消、应中止；否则 [password] 是要传给
  /// 恢复流程的密码（未加密的老备份为 null）。
  Future<({bool proceed, String? password})> _resolveRestorePassword() async {
    final encrypted = await isBackupEncrypted(await appPath.backupFilePath);
    if (!encrypted) {
      return (proceed: true, password: null);
    }
    if (!mounted) {
      return (proceed: false, password: null);
    }
    final password = await globalState.showCommonDialog<String>(
      child: const _BackupPasswordDialog(isSetting: false),
    );
    if (password == null) {
      return (proceed: false, password: null);
    }
    return (proceed: true, password: password);
  }

  Future<void> _handleRestoreOnLocal() async {
    final option = await globalState.showCommonDialog<RestoreOption>(
      child: const RestoreOptionsDialog(),
    );
    if (option == null || !mounted) return;
    _restoreOnLocal(option);
  }

  void _handleChange(String? value, WidgetRef ref) {
    if (value == null) {
      return;
    }
    ref
        .read(davSettingProvider.notifier)
        .update((state) => state?.copyWith(fileName: value));
  }

  Future<void> _handleUpdateRestoreStrategy() async {
    final restoreStrategy = ref.read(
      appSettingProvider.select((state) => state.restoreStrategy),
    );
    final res = await globalState.showCommonDialog(
      child: OptionsDialog<RestoreStrategy>(
        title: currentAppLocalizations.restoreStrategy,
        options: RestoreStrategy.values,
        textBuilder: (mode) => Intl.message('restoreStrategy_${mode.name}'),
        value: restoreStrategy,
      ),
    );
    if (res == null) {
      return;
    }
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(restoreStrategy: res));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final dav = ref.watch(davSettingProvider);
    final isLoading = ref.watch(loadingProvider(LoadingTag.backup_restore));
    return CommonScaffold(
      isLoading: isLoading,
      title: appLocalizations.backupAndRestore,
      // 三组都走 generateSection，才和其它设置页一样是圆角分组卡片。
      // 原来是 ListHeader + 裸列表项通栏平铺，那是 FlClash 的样子。
      body: Builder(
        // **这层 Builder 不能省。** 胶囊高度是 CommonScaffold 注入到正文里的，
        // 在构造 CommonScaffold 的那一层取会少一个胶囊加两段间隙（64dp），
        // 第一项就会被胶囊压住半截。
        builder: (context) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // 三组卡片依次浮上来。这一页打开后不会被数据刷新反复重建，逐项入场
            // 不会变成抖动。
            StaggeredEntrance(
              index: 0,
              // 绑定/解绑 WebDAV 会让这张卡片在「一行提示」和「五行设置」之间整块
              // 变形。原来是对话框一关就瞬间换掉，下面两组跟着跳走；让卡片自己长
              // 高收矮，看得出多出来的几行是从这张卡里长出来的。
              child: AnimatedSize(
                duration: Motion.normal,
                curve: Motion.move,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: generateSection(
                    title: appLocalizations.remote,
                    isFirst: true,
                    items: [
                      if (dav == null)
                        ListItem(
                          leading: const Icon(Icons.account_box),
                          title: Text(appLocalizations.noInfo),
                          subtitle: Text(appLocalizations.pleaseBindWebDAV),
                          trailing: FilledButton.tonal(
                            onPressed: () {
                              _showAddWebDAV(dav);
                            },
                            child: Text(appLocalizations.bind),
                          ),
                        )
                      else ...[
                        ListItem(
                          leading: const Icon(Icons.account_box),
                          title: TooltipText(
                            text: Text(
                              dav.user,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(appLocalizations.connectivity),
                                ValueListenableBuilder(
                                  valueListenable: _davConnection,
                                  builder: (_, isCompleter, _) {
                                    // 连通性指示灯本来就是淡入淡出的：转圈和绿点/
                                    // 红点之间不闪一下，才看得出是同一个东西有了
                                    // 结果。
                                    return Center(
                                      child: FadeThroughBox(
                                        child: isCompleter == null
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: HeroSpinner(),
                                              )
                                            : Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: !isCompleter
                                                      ? context
                                                            .colorScheme
                                                            .error
                                                      : AppStyleTokens.success,
                                                ),
                                                width: 12,
                                                height: 12,
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () {
                              _showAddWebDAV(dav);
                            },
                            child: Text(appLocalizations.edit),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ListItem.input(
                          title: Text(appLocalizations.file),
                          subtitle: Text(dav.fileName),
                          dialogTitle: appLocalizations.file,
                          value: dav.fileName,
                          resetValue: defaultDavFileName,
                          maxLength: TextInputLimits.fileName,
                          onChanged: (value) {
                            _handleChange(value, ref);
                          },
                        ),
                        ListItem(
                          onTap: () {
                            _backupOnWebDAV();
                          },
                          title: Text(appLocalizations.backup),
                          subtitle: Text(appLocalizations.remoteBackupDesc),
                        ),
                        ListItem(
                          onTap: () {
                            _handleRestoreOnWebDAV();
                          },
                          title: Text(appLocalizations.restore),
                          subtitle: Text(
                            appLocalizations.restoreFromWebDAVDesc,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            StaggeredEntrance(
              index: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: generateSection(
                  title: appLocalizations.local,
                  items: [
                    ListItem(
                      onTap: () {
                        _backupOnLocal();
                      },
                      title: Text(appLocalizations.backup),
                      subtitle: Text(appLocalizations.localBackupDesc),
                    ),
                    ListItem(
                      onTap: () {
                        _handleRestoreOnLocal();
                      },
                      title: Text(appLocalizations.restore),
                      subtitle: Text(appLocalizations.restoreFromFileDesc),
                    ),
                  ],
                ),
              ),
            ),
            StaggeredEntrance(
              index: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: generateSection(
                  title: appLocalizations.options,
                  items: [
                    Consumer(
                      builder: (_, ref, _) {
                        final restoreStrategy = ref.watch(
                          appSettingProvider.select(
                            (state) => state.restoreStrategy,
                          ),
                        );
                        return ListItem(
                          onTap: () {
                            _handleUpdateRestoreStrategy();
                          },
                          title: Text(appLocalizations.restoreStrategy),
                          trailing: FilledButton(
                            onPressed: () {
                              _handleUpdateRestoreStrategy();
                            },
                            child: Text(
                              Intl.message(
                                'restoreStrategy_${restoreStrategy.name}',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestoreOptionsDialog extends StatefulWidget {
  const RestoreOptionsDialog({super.key});

  @override
  State<RestoreOptionsDialog> createState() => _RestoreOptionsDialogState();
}

class _RestoreOptionsDialogState extends State<RestoreOptionsDialog> {
  void _handleOnTab(RestoreOption? option) {
    if (option == null) return;
    Navigator.of(context).pop(option);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.restore,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Wrap(
        children: [
          ListItem(
            onTap: () {
              _handleOnTab(RestoreOption.onlyProfiles);
            },
            title: Text(appLocalizations.restoreOnlyConfig),
          ),
          ListItem(
            onTap: () {
              _handleOnTab(RestoreOption.all);
            },
            title: Text(appLocalizations.restoreAllData),
          ),
        ],
      ),
    );
  }
}

class WebDAVFormDialog extends ConsumerStatefulWidget {
  final DAVProps? dav;

  const WebDAVFormDialog({super.key, this.dav});

  @override
  ConsumerState<WebDAVFormDialog> createState() => _WebDAVFormDialogState();
}

class _WebDAVFormDialogState extends ConsumerState<WebDAVFormDialog> {
  late TextEditingController _uriController;
  late TextEditingController _userController;
  late TextEditingController _passwordController;
  final _obscureController = ValueNotifier<bool>(true);
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _uriController = TextEditingController(text: widget.dav?.uri);
    _userController = TextEditingController(text: widget.dav?.user);
    _passwordController = TextEditingController(text: widget.dav?.password);
  }

  /// 只判断是不是明文 http（用于给一条警告，不参与校验、不拦提交）。
  bool _isPlainHttp(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.scheme.toLowerCase() == 'http';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(davSettingProvider.notifier)
        .update(
          (_) => DAVProps(
            uri: _uriController.text,
            user: _userController.text,
            password: _passwordController.text,
            fileName: widget.dav?.fileName ?? defaultDavFileName,
          ),
        );
    Navigator.pop(context);
  }

  void _delete() {
    ref.read(davSettingProvider.notifier).update((_) => null);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _obscureController.dispose();
    _uriController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.webDAVConfiguration,
      actions: [
        if (widget.dav != null)
          TextButton(onPressed: _delete, child: Text(appLocalizations.delete)),
        TextButton(onPressed: _submit, child: Text(appLocalizations.save)),
      ],
      child: Form(
        key: _formKey,
        // 点「保存」时三个字段下面可能同时长出红色提示，对话框一下子高出一截。
        // 让它长过去，用户看到的是「多出了几行说明」，而不是整个框跳了一下。
        child: AnimatedSize(
          duration: Motion.quick,
          curve: Motion.move,
          alignment: Alignment.topCenter,
          child: Wrap(
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _uriController,
                    inputFormatters: TextInputLimits.limit(TextInputLimits.uri),
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.link),
                      border: const OutlineInputBorder(),
                      labelText: appLocalizations.address,
                      helperText: appLocalizations.addressHelp,
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty || !value.isUrl) {
                        return appLocalizations.addressTip;
                      }
                      return null;
                    },
                  ),
                  // 明文 HTTP 只警告、不拦——局域网 NAS 确实会用 http。
                  // 用 http:// 时 Basic 认证的账号密码是明文传输的。
                  ListenableBuilder(
                    listenable: _uriController,
                    builder: (context, _) {
                      final show = _isPlainHttp(_uriController.text);
                      return AnimatedSize(
                        duration: Motion.quick,
                        curve: Motion.move,
                        alignment: Alignment.topLeft,
                        child: !show
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 18,
                                      color: context.colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        appLocalizations.insecureWebDAVWarning,
                                        style: context.textTheme.bodySmall
                                            ?.copyWith(
                                              color: context.colorScheme.error,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      );
                    },
                  ),
                ],
              ),
              TextFormField(
                controller: _userController,
                inputFormatters: TextInputLimits.limit(
                  TextInputLimits.userName,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.account_circle),
                  border: const OutlineInputBorder(),
                  labelText: appLocalizations.account,
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return appLocalizations.emptyTip(appLocalizations.account);
                  }
                  return null;
                },
              ),
              ValueListenableBuilder(
                valueListenable: _obscureController,
                builder: (_, obscure, _) {
                  return TextFormField(
                    controller: _passwordController,
                    inputFormatters: TextInputLimits.limit(
                      TextInputLimits.password,
                    ),
                    obscureText: obscure,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.password),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          _obscureController.value = !obscure;
                        },
                      ),
                      labelText: appLocalizations.password,
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return appLocalizations.emptyTip(
                          appLocalizations.password,
                        );
                      }
                      return null;
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置/输入备份密码的对话框。
///
/// [isSetting] 为真是「创建备份时设密码」，为假是「恢复加密备份时输密码」。两种
/// 场景都要求非空——备份不给可选的「不加密」出口，因为备份里含 WebDAV 账号密码
/// 和带 token 的订阅链接。返回用户输入的密码；取消返回 null。
class _BackupPasswordDialog extends StatefulWidget {
  final bool isSetting;

  const _BackupPasswordDialog({required this.isSetting});

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _obscure = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _controller.dispose();
    _obscure.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop<String>(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: widget.isSetting
          ? appLocalizations.backupEncryptTitle
          : appLocalizations.restoreDecryptTitle,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(appLocalizations.confirm)),
      ],
      child: Form(
        key: _formKey,
        child: Wrap(
          runSpacing: 16,
          children: [
            Text(
              widget.isSetting
                  ? appLocalizations.backupEncryptDesc
                  : appLocalizations.restoreDecryptDesc,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _obscure,
              builder: (_, obscure, _) {
                return TextFormField(
                  controller: _controller,
                  inputFormatters: TextInputLimits.limit(
                    TextInputLimits.password,
                  ),
                  obscureText: obscure,
                  autofocus: true,
                  onFieldSubmitted: (_) {
                    _submit();
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.password),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        _obscure.value = !obscure;
                      },
                    ),
                    labelText: appLocalizations.password,
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.emptyTip(
                        appLocalizations.password,
                      );
                    }
                    return null;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
