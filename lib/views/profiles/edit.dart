import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/core/controller.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/pages/editor.dart';
import 'package:clash_party/providers/action.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';

class EditProfileView extends StatefulWidget {
  final Profile profile;
  final BuildContext context;

  const EditProfileView({
    super.key,
    required this.context,
    required this.profile,
  });

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  late final TextEditingController _labelController;
  late final TextEditingController _urlController;
  late final TextEditingController _autoUpdateDurationController;
  late bool _autoUpdate;
  String? _rawText;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _fileInfoNotifier = ValueNotifier<FileInfo?>(null);
  Uint8List? _fileData;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.profile.label);
    _urlController = TextEditingController(text: widget.profile.url);
    _autoUpdate = widget.profile.autoUpdate;
    _autoUpdateDurationController = TextEditingController(
      text: widget.profile.autoUpdateDuration.inMinutes.toString(),
    );
    _updateFileInfo();
  }

  Future<void> _updateFileInfo() async {
    final file = await widget.profile.file;
    final fileInfo = await file.getFileInfo();
    if (!mounted) {
      return;
    }
    _fileInfoNotifier.value = fileInfo;
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    var profile = widget.profile.copyWith(
      url: _urlController.text,
      label: _labelController.text,
      autoUpdate: _autoUpdate,
      // 用 tryParse 而不是 parse：间隔输入框只在「自动更新」打开时才挂在树上，
      // 一关掉它就从 Form 里注销、校验器也不再运行，而控制器里可能还留着用户
      // 刚清空的空串。此时 int.parse('') 抛 FormatException；又因为
      // _handleConfirm 是 async、被当成 VoidCallback 交给保存按钮，异常只会掉进
      // 没人接的 Future 里——界面表现是「点保存毫无反应」，而且这一趟改的名字、
      // 地址、以及「关掉自动更新」本身全部丢失。
      autoUpdateDuration: Duration(
        minutes:
            int.tryParse(_autoUpdateDurationController.text) ??
            widget.profile.autoUpdateDuration.inMinutes,
      ),
    );
    final profilesAction = globalState.container.read(
      profilesActionProvider.notifier,
    );
    final hasUpdate = widget.profile.url != profile.url;
    if (_fileData != null) {
      if (profile.type == ProfileType.url && _autoUpdate) {
        final appLocalizations = context.appLocalizations;
        final res = await globalState.showMessage(
          title: appLocalizations.tip,
          message: TextSpan(text: appLocalizations.profileHasUpdate),
        );
        if (res == true) {
          profile = profile.copyWith(autoUpdate: false);
        }
      }
      // saveFile 会先让内核校验这份配置，不合法就抛出内核给的原因。而
      // _handleConfirm 是被当成 VoidCallback 交给保存按钮的 async 方法，抛出来
      // 的异常掉进没人接的 Future：界面表现是「点保存毫无反应」——上传了一个坏
      // 配置的用户既看不到错误、也不知道为什么退不出去。用 safeRun 接住并把内核
      // 的原因弹出来，校验没过就留在编辑页，不要 pop 掉让人以为存成功了。
      final savedProfile = await globalState.safeRun(
        () => profile.saveFile(_fileData!),
        silence: false,
      );
      if (savedProfile == null) {
        return;
      }
      profilesAction.putProfile(savedProfile);
    } else if (!hasUpdate) {
      profilesAction.putProfile(profile);
    } else {
      globalState.safeRun(() async {
        await Future.delayed(commonDuration);
        if (hasUpdate) {
          await profilesAction.updateProfile(profile);
        }
      });
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _setAutoUpdate(bool value) {
    if (_autoUpdate == value) return;
    setState(() {
      _autoUpdate = value;
    });
  }

  Future<void> _handleSaveEdit(BuildContext context, String data) async {
    final message = await globalState.safeRun<String>(() async {
      final message = await coreController.validateConfigWithData(data);
      return message;
    }, silence: false);
    if (message?.isNotEmpty == true) {
      globalState.showMessage(
        title: currentAppLocalizations.tip,
        message: TextSpan(text: message),
      );
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pop(data);
    }
  }

  Future<void> _editProfileFile() async {
    final fileData = _fileData;
    if (fileData != null) {
      // A pending upload has not been written to disk yet; editing must show
      // that content, otherwise saving here would discard the upload.
      try {
        _rawText = utf8.decode(fileData);
      } on FormatException {
        _rawText ??= '';
      }
    } else if (_rawText == null) {
      final profilePath = await appPath.getProfilePath(
        widget.profile.id.toString(),
      );
      final file = File(profilePath);
      if (await file.exists()) {
        _rawText = await file.readAsString();
      }
    }
    if (!mounted) return;
    final title = widget.profile.label.takeFirstValid([
      widget.profile.id.toString(),
    ]);
    final editorPage = EditorPage(
      title: title,
      content: _rawText!,
      onSave: (context, _, content) {
        _handleSaveEdit(context, content);
      },
      onPop: (context, _, content) async {
        if (content == _rawText) {
          return true;
        }
        final res = await globalState.showMessage(
          title: title,
          message: TextSpan(text: context.appLocalizations.hasCacheChange),
        );
        if (res == true && context.mounted) {
          _handleSaveEdit(context, content);
        } else {
          return true;
        }
        return false;
      },
    );
    final data = await BaseNavigator.push<String>(context, editorPage);
    if (data == null) {
      return;
    }
    _rawText = data;
    _fileData = Uint8List.fromList(utf8.encode(data));
    _fileInfoNotifier.value = _fileInfoNotifier.value?.copyWith(
      size: _fileData?.length ?? 0,
      lastModified: DateTime.now(),
    );
  }

  Future<void> _uploadProfileFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile == null) return;
    _fileData = await platformFile.readBytes();
    if (!mounted) {
      return;
    }
    _fileInfoNotifier.value = _fileInfoNotifier.value?.copyWith(
      size: _fileData?.length ?? 0,
      lastModified: DateTime.now(),
    );
  }

  Future<void> _handleBack() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.fileIsUpdate),
    );
    if (res == true) {
      _handleConfirm();
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    _fileInfoNotifier.dispose();
    _autoUpdateDurationController.dispose();
    super.dispose();
    globalState.container.read(setupActionProvider.notifier).autoApplyProfile();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    // 输入框去掉自己的方框（`InputBorder.none`）：外面已经有一张圆角分组卡片，
    // 再画一圈边就是框套框，那正是 Material 默认表单的样子。
    const fieldBorder = InputBorder.none;
    final items = [
      // 这一组的高度会在两种情况下变：开关「自动更新」时多出/收起「更新间隔」
      // 那一行，以及校验不通过时字段下面长出一行红字。两种都会把下面的内容整块
      // 顶走，硬跳的话眼睛得重新找位置。AnimatedSize 让卡片自己长高收矮，多出来
      // 的那行是被拉出来的。
      //
      // 不在单条上做高度收缩：分隔线由 generateSection 在条目之间自动插，留一条
      // 高度为 0 的条目会在卡片底部剩下一条孤立的横线。
      //
      // 这里用最短的 Motion.quick 而不是 normal：链接输入框会随内容折行长高，
      // AnimatedSize 在长高期间是裁切的，时长一长，刚敲出来的那一行连同光标会被
      // 短暂盖住。180 毫秒短到察觉不出，又足够把「多出一行」这件事说清楚。
      AnimatedSize(
        duration: Motion.quick,
        curve: Motion.move,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: generateSection(
            title: appLocalizations.general,
            isFirst: true,
            items: [
              ListItem(
                title: TextFormField(
                  textInputAction: TextInputAction.next,
                  controller: _labelController,
                  inputFormatters: TextInputLimits.limit(TextInputLimits.name),
                  decoration: InputDecoration(
                    border: fieldBorder,
                    labelText: appLocalizations.name,
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.profileNameNullValidationDesc;
                    }
                    return null;
                  },
                ),
              ),
              if (widget.profile.type == ProfileType.url) ...[
                ListItem(
                  title: TextFormField(
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.url,
                    controller: _urlController,
                    inputFormatters: TextInputLimits.limit(TextInputLimits.url),
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      border: fieldBorder,
                      labelText: appLocalizations.url,
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return appLocalizations.profileUrlNullValidationDesc;
                      }
                      if (!value.isUrl) {
                        return appLocalizations.profileUrlInvalidValidationDesc;
                      }
                      return null;
                    },
                  ),
                ),
                ListItem.toggle(
                  title: Text(appLocalizations.autoUpdate),
                  value: _autoUpdate,
                  onChanged: _setAutoUpdate,
                ),
                if (_autoUpdate)
                  ListItem(
                    title: TextFormField(
                      textInputAction: TextInputAction.next,
                      controller: _autoUpdateDurationController,
                      inputFormatters: TextInputLimits.digitsOnly(
                        TextInputLimits.interval,
                      ),
                      decoration: InputDecoration(
                        border: fieldBorder,
                        labelText: appLocalizations.autoUpdateInterval,
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return appLocalizations
                              .profileAutoUpdateIntervalNullValidationDesc;
                        }
                        try {
                          int.parse(value);
                        } catch (_) {
                          return appLocalizations
                              .profileAutoUpdateIntervalInvalidValidationDesc;
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      ValueListenableBuilder<FileInfo?>(
        valueListenable: _fileInfoNotifier,
        builder: (_, fileInfo, _) {
          return FadeThroughBox(
            alignment: Alignment.centerLeft,
            // 分组整块出现/消失：文件信息还没读出来时连标题一起不画，
            // 否则会先出现一张空卡片再被填上，闪一下。
            child: fileInfo == null
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: generateSection(
                      title: appLocalizations.profile,
                      items: [
                        ListItem(
                          title: Text(fileInfo.getDesc(context)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Wrap(
                                runSpacing: 6,
                                spacing: 12,
                                children: [
                                  CommonChip(
                                    avatar: const Icon(Icons.edit),
                                    label: appLocalizations.edit,
                                    onPressed: _editProfileFile,
                                  ),
                                  CommonChip(
                                    avatar: const Icon(Icons.upload),
                                    label: appLocalizations.upload,
                                    onPressed: _uploadProfileFile,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    ];
    return FocusTraversalGroup(
      policy: PageTraversalPolicy(),
      child: PageFocusScope(
        child: CommonPopScope(
          onPop: (context) {
            if (_fileData == null) {
              return true;
            }
            _handleBack();
            return false;
          },
          child: FloatLayout(
            floatingWidget: FloatWrapper(
              child: CommonFloatingActionButton(
                onPressed: _handleConfirm,
                icon: const Icon(Icons.save),
                label: appLocalizations.save,
              ),
            ),
            child: Form(
              key: _formKey,
              // 组间距由 generateSection 自己带（标题上下的留白），不再靠
              // 分隔用的 SizedBox 撑开，否则两套间距叠在一起会松垮。
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                children: items,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
