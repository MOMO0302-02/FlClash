/// 局域网访问的密码保护。
///
/// 对应桌面版 `src/renderer/src/pages/mihomo.tsx`：那一页在「允许局域网连接」开关
/// 下面依次是允许网段、禁止网段、**用户验证**（`:1249-1319`，`authentication`）、
/// **跳过验证的前缀**（`:1321-1345`，`skip-auth-prefixes`）；控制器密钥
/// （`:969-1010`，`secret`）在外部控制器那一栏里。这里按同样的相邻关系摆：
/// [LanAuthItem] 紧跟「允许局域网」，[SecretItem] 紧跟「外部控制器」。
///
/// 桌面版没做、这里加的只有一处：**开了局域网又没设密码时给出警告**。桌面机常年
/// 待在自己家的网里，手机天天连公共 Wi-Fi，一个没有密码的开放代理端口在咖啡馆
/// 里是实打实的问题，而这件事用户完全看不出来。
///
/// 允许网段 / 禁止网段（`lan-allowed-ips`、`lan-disallowed-ips`）这次没做，
/// 密码本身已经能解决"别人能用我的代理"这个问题。
library;

import 'dart:math';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 要不要报警：只有"门开着且没锁"才算危险。
///
/// 局域网没开的时候没设密码完全正常，那种情况下也报警只会训练用户忽略警告，
/// 等到真出事那一次他也照样划过去。
///
/// 入口那一行和页面里的横幅共用这一个判断。两边各写一遍 `allowLan && noAuth`
/// 看着一样，但改了一边忘了另一边不会有任何征兆——变异测试当场抓到过这件事：
/// 把入口那一行的条件改坏，页面的测试全绿。
bool _lanAtRisk({required bool allowLan, required bool noAuth}) {
  return allowLan && noAuth;
}

class LanAuthItem extends ConsumerWidget {
  const LanAuthItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final vm2 = ref.watch(
      patchClashConfigProvider.select(
        (state) => VM2(state.allowLan, state.authentication.isEmpty),
      ),
    );
    final atRisk = _lanAtRisk(allowLan: vm2.a, noAuth: vm2.b);
    final colorScheme = context.colorScheme;
    return ListItem.open(
      leading: Icon(
        atRisk ? Icons.gpp_maybe_outlined : Icons.password_outlined,
        color: atRisk ? colorScheme.error : null,
      ),
      title: Text(appLocalizations.lanAuth),
      subtitle: Text(
        atRisk ? appLocalizations.lanAuthWarning : appLocalizations.lanAuthDesc,
        style: atRisk ? TextStyle(color: colorScheme.error) : null,
      ),
      blur: false,
      widget: const LanAuthView(),
    );
  }
}

class LanAuthView extends ConsumerWidget {
  const LanAuthView({super.key});

  Future<void> _addOrEdit(
    BuildContext context,
    WidgetRef ref, {
    String? origin,
  }) async {
    final entry = await globalState.showCommonDialog<String>(
      child: _AuthDialog(origin: origin),
    );
    if (entry == null) {
      return;
    }
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final next = List<String>.from(state.authentication);
      final index = origin == null ? -1 : next.indexOf(origin);
      if (index == -1) {
        next.add(entry);
      } else {
        next[index] = entry;
      }
      return state.copyWith(authentication: next);
    });
  }

  Future<void> _delete(WidgetRef ref, String item) async {
    final appLocalizations = currentAppLocalizations;
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.userName),
      ),
    );
    if (res != true) {
      return;
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            authentication: state.authentication
                .where((entry) => entry != item)
                .toList(),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final vm2 = ref.watch(
      patchClashConfigProvider.select(
        (state) => VM2(state.authentication, state.allowLan),
      ),
    );
    final authentication = vm2.a;
    final atRisk = _lanAtRisk(allowLan: vm2.b, noAuth: authentication.isEmpty);
    return BaseScaffold(
      title: appLocalizations.lanAuth,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (atRisk)
            ...generateSection(
              isFirst: true,
              items: [
                ListItem(
                  leading: Icon(
                    Icons.gpp_maybe_outlined,
                    color: context.colorScheme.error,
                  ),
                  title: Text(
                    appLocalizations.lanAuthWarning,
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                ),
              ],
            ),
          ...generateSection(
            isFirst: !atRisk,
            title: appLocalizations.lanAuth,
            actions: [
              IconButton(
                tooltip: appLocalizations.add,
                onPressed: () {
                  _addOrEdit(context, ref);
                },
                icon: const Icon(Icons.add),
              ),
            ],
            items: [
              if (authentication.isEmpty)
                ListItem(
                  title: Text(appLocalizations.lanAuthEmpty),
                  subtitle: Text(appLocalizations.lanAuthDesc),
                )
              else ...[
                for (final item in authentication)
                  ListItem(
                    title: Text(_userOf(item)),
                    // 列表里**不显示密码**，只显示位数。设了几位是有用的信息
                    // （能看出自己是不是选了个三位数的密码），密码本身没必要
                    // 摊在屏幕上给旁边的人看。
                    subtitle: Text('•' * _passOf(item).length),
                    onTap: () {
                      _addOrEdit(context, ref, origin: item);
                    },
                    trailing: IconButton(
                      tooltip: appLocalizations.delete,
                      onPressed: () {
                        _delete(ref, item);
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ListItem(
                  leading: const Icon(Icons.info_outline),
                  title: Text(appLocalizations.lanAuthLocalTip),
                ),
              ],
            ],
          ),
          ...generateSection(
            title: appLocalizations.options,
            items: const [SkipAuthPrefixesItem()],
          ),
        ],
      ),
    );
  }
}

/// 内核 `parseAuthentication`（`config/config.go:1658-1666`）用的是
/// `strings.Cut(line, ":")`——**按第一个冒号切**，所以用户名里不能有冒号，
/// 密码里可以。这两个函数和那条规则保持一致。
String _userOf(String entry) {
  final index = entry.indexOf(':');
  return index == -1 ? entry : entry.substring(0, index);
}

String _passOf(String entry) {
  final index = entry.indexOf(':');
  return index == -1 ? '' : entry.substring(index + 1);
}

class SkipAuthPrefixesItem extends ConsumerWidget {
  const SkipAuthPrefixesItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final items = ref.watch(
      patchClashConfigProvider.select((state) => state.skipAuthPrefixes),
    );
    return ListItem.open(
      title: Text(appLocalizations.skipAuthPrefixes),
      subtitle: Text(appLocalizations.skipAuthPrefixesDesc),
      blur: false,
      maxWidth: 360,
      widget: ListInputPage(
        title: appLocalizations.skipAuthPrefixes,
        items: items,
        itemMaxLength: TextInputLimits.cidr,
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith(
                skipAuthPrefixes: List<String>.from(value as Iterable),
              ),
            );
      },
    );
  }
}

/// 外部控制器的访问密钥。
class SecretItem extends ConsumerWidget {
  const SecretItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final secret = ref.watch(
      patchClashConfigProvider.select((state) => state.secret),
    );
    return ListItem(
      leading: const Icon(Icons.key_outlined),
      title: Text(appLocalizations.externalControllerSecret),
      subtitle: Text(
        secret.isEmpty
            ? appLocalizations.externalControllerSecretDesc
            : '•' * secret.length,
      ),
      onTap: () async {
        final next = await globalState.showCommonDialog<String>(
          child: _SecretDialog(origin: secret),
        );
        if (next == null) {
          return;
        }
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(secret: next));
      },
    );
  }
}

/// 会遮住字符的输入框。
///
/// 本来想直接用 `widgets/input.dart` 里的 `AddDialog`——它已经能做"两个字段"的
/// 弹窗（Hosts 就是那么编辑的），但它的输入框没有遮字符这个能力，而
/// `lib/widgets/` 这次不归我改，所以在这里自己搭一个最小的。
class _ObscuredField extends StatefulWidget {
  const _ObscuredField({
    required this.controller,
    required this.label,
    required this.maxLength,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final VoidCallback? onSubmitted;

  @override
  State<_ObscuredField> createState() => _ObscuredFieldState();
}

class _ObscuredFieldState extends State<_ObscuredField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      // 密码框不该被输入法学走，也不该出现在联想候选里。
      enableSuggestions: false,
      autocorrect: false,
      inputFormatters: TextInputLimits.limit(widget.maxLength),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          onPressed: () {
            setState(() {
              _obscure = !_obscure;
            });
          },
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      onFieldSubmitted: (_) {
        widget.onSubmitted?.call();
      },
    );
  }
}

class _AuthDialog extends StatefulWidget {
  const _AuthDialog({this.origin});

  final String? origin;

  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userController;
  late final TextEditingController _passController;

  @override
  void initState() {
    super.initState();
    final origin = widget.origin;
    _userController = TextEditingController(
      text: origin == null ? '' : _userOf(origin),
    );
    _passController = TextEditingController(
      text: origin == null ? '' : _passOf(origin),
    );
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(
      context,
    ).pop<String>('${_userController.text}:${_passController.text}');
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: widget.origin == null
          ? appLocalizations.add
          : appLocalizations.edit,
      actions: [
        TextButton(onPressed: _submit, child: Text(appLocalizations.confirm)),
      ],
      child: Form(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        key: _formKey,
        child: Wrap(
          runSpacing: 16,
          children: [
            TextFormField(
              controller: _userController,
              inputFormatters: TextInputLimits.limit(TextInputLimits.userName),
              decoration: InputDecoration(labelText: appLocalizations.userName),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return appLocalizations.emptyTip(appLocalizations.userName);
                }
                // 内核按**第一个冒号**切 `用户名:密码`。用户名里带冒号会被从
                // 冒号处截断，等于用户设的账号和实际生效的账号不是一个——
                // 拦在这里，别让人事后对着"密码明明是对的"发愁。
                if (value.contains(':')) {
                  return appLocalizations.lanAuthUserNameTip;
                }
                return null;
              },
            ),
            _ObscuredField(
              controller: _passController,
              label: appLocalizations.password,
              maxLength: TextInputLimits.password,
              onSubmitted: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecretDialog extends StatefulWidget {
  const _SecretDialog({required this.origin});

  final String origin;

  @override
  State<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<_SecretDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.origin);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 只把随机串**填进输入框**，不直接生效——用户还得自己按确认。
  /// 悄悄生成一个密钥再启用，会让人下次连不上还查不出原因。
  void _generate() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    // Random.secure()：这是个凭据，不该用可预测的伪随机数生成。
    final random = Random.secure();
    _controller.text = List.generate(
      16,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.externalControllerSecret,
      actions: [
        TextButton(
          onPressed: _generate,
          child: Text(appLocalizations.generateRandom),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop<String>(_controller.text);
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Wrap(
        runSpacing: 16,
        children: [
          _ObscuredField(
            controller: _controller,
            label: appLocalizations.externalControllerSecret,
            maxLength: TextInputLimits.password,
          ),
        ],
      ),
    );
  }
}
