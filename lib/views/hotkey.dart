import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/providers.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/card.dart';
import 'package:clash_party/widgets/dialog.dart';
import 'package:clash_party/widgets/list.dart';
import 'package:clash_party/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

extension IntlExt on Intl {
  static String actionMessage(String messageText) =>
      Intl.message('action_$messageText');
}

class HotKeyView extends StatelessWidget {
  const HotKeyView({super.key});

  String getSubtitle(BuildContext context, HotKeyAction hotKeyAction) {
    final appLocalizations = context.appLocalizations;
    final key = hotKeyAction.key;
    if (key == null) {
      return appLocalizations.noHotKey;
    }
    final modifierLabels = hotKeyAction.modifiers.map(
      (item) => item.physicalKeys.first.label,
    );
    var text = '';
    if (modifierLabels.isNotEmpty) {
      text += "${modifierLabels.join(" ")}+";
    }
    text += PhysicalKeyboardKey(key).label;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final accent = context.styleTokens.accent(context.colorScheme);
    return BaseScaffold(
      title: appLocalizations.hotkeyManagement,
      // 原来是通栏平铺的 ListView，和设置页其它子页的圆角分组卡片对不上。
      // 快捷键就那么几条，一张卡片装得下。
      body: generateListView(
        generateSection(
          isFirst: true,
          title: appLocalizations.options,
          items: [
            for (final hotAction in HotAction.values)
              Consumer(
                builder: (_, ref, _) {
                  final hotKeyAction = ref.watch(
                    getHotKeyActionProvider(hotAction),
                  );
                  final hasKey = hotKeyAction.key != null;
                  return ListItem(
                    title: Text(IntlExt.actionMessage(hotAction.name)),
                    // 未设置时用次要文字色：主色是「已经设了一个键」的信号，
                    // 拿它去显示「无快捷键」等于在强调一个空值。
                    subtitle: Text(
                      getSubtitle(context, hotKeyAction),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: hasKey
                            ? accent
                            : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      globalState.showCommonDialog(
                        child: HotKeyRecorder(hotKeyAction: hotKeyAction),
                      );
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

class HotKeyRecorder extends ConsumerStatefulWidget {
  final HotKeyAction hotKeyAction;

  const HotKeyRecorder({super.key, required this.hotKeyAction});

  @override
  ConsumerState<HotKeyRecorder> createState() => _HotKeyRecorderState();
}

class _HotKeyRecorderState extends ConsumerState<HotKeyRecorder> {
  late ValueNotifier<HotKeyAction> hotKeyActionNotifier;

  @override
  void initState() {
    super.initState();
    hotKeyActionNotifier = ValueNotifier<HotKeyAction>(
      widget.hotKeyAction.copyWith(),
    );
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent keyEvent) {
    if (keyEvent is KeyUpEvent) return false;
    final keys = HardwareKeyboard.instance.physicalKeysPressed;

    final key = keyEvent.physicalKey;

    final modifiers = KeyboardModifier.values
        .where(
          (e) =>
              e.physicalKeys.any(keys.contains) &&
              !e.physicalKeys.contains(key),
        )
        .toSet();
    hotKeyActionNotifier.value = hotKeyActionNotifier.value.copyWith(
      modifiers: modifiers,
      key: key.usbHidUsage,
    );
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  void _handleRemove() {
    Navigator.of(context).pop();
    _updateOrAddHotKeyAction(
      hotKeyActionNotifier.value.copyWith(modifiers: {}, key: null),
    );
  }

  void _handleConfirm() {
    final appLocalizations = context.appLocalizations;
    Navigator.of(context).pop();
    final hotKeyActions = ref.read(hotKeyActionsProvider);
    final currentHotkeyAction = hotKeyActionNotifier.value;
    if (currentHotkeyAction.key == null ||
        currentHotkeyAction.modifiers.isEmpty) {
      globalState.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(text: appLocalizations.inputCorrectHotkey),
      );
      return;
    }
    final index = hotKeyActions.indexWhere(
      (item) =>
          item.action != currentHotkeyAction.action &&
          item.key == currentHotkeyAction.key &&
          keyboardModifierListEquality.equals(
            item.modifiers,
            currentHotkeyAction.modifiers,
          ),
    );
    if (index != -1) {
      globalState.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(text: appLocalizations.hotkeyConflict),
      );
      return;
    }
    _updateOrAddHotKeyAction(currentHotkeyAction);
  }

  void _updateOrAddHotKeyAction(HotKeyAction hotKeyAction) {
    final hotKeyActions = ref.read(hotKeyActionsProvider);
    final index = hotKeyActions.indexWhere(
      (item) => item.action == hotKeyAction.action,
    );
    if (index == -1) {
      ref.read(hotKeyActionsProvider.notifier).value = List.from(hotKeyActions)
        ..add(hotKeyAction);
    } else {
      ref.read(hotKeyActionsProvider.notifier).value = List.from(hotKeyActions)
        ..[index] = hotKeyAction;
    }

    ref.read(hotKeyActionsProvider.notifier).value = index == -1
        ? (List.from(hotKeyActions)..add(hotKeyAction))
        : (List.from(hotKeyActions)..[index] = hotKeyAction);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Focus(
      onKeyEvent: (_, _) {
        return KeyEventResult.handled;
      },
      autofocus: true,
      child: CommonDialog(
        title: IntlExt.actionMessage(widget.hotKeyAction.action.name),
        actions: [
          TextButton(
            onPressed: () {
              _handleRemove();
            },
            child: Text(appLocalizations.remove),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              _handleConfirm();
            },
            child: Text(appLocalizations.confirm),
          ),
        ],
        child: ValueListenableBuilder(
          valueListenable: hotKeyActionNotifier,
          builder: (_, hotKeyAction, _) {
            final key = hotKeyAction.key;
            final modifiers = hotKeyAction.modifiers;
            return SizedBox(
              width: dialogCommonWidth,
              child: key != null
                  ? Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final modifier in modifiers)
                          KeyboardKeyBox(
                            keyboardKey: modifier.physicalKeys.first,
                          ),
                        if (modifiers.isNotEmpty)
                          Text('+', style: context.textTheme.titleMedium),
                        KeyboardKeyBox(keyboardKey: PhysicalKeyboardKey(key)),
                      ],
                    )
                  : Text(
                      appLocalizations.pressKeyboard,
                      style: context.textTheme.titleMedium,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class KeyboardKeyBox extends StatelessWidget {
  final KeyboardKey keyboardKey;

  const KeyboardKeyBox({super.key, required this.keyboardKey});

  @override
  Widget build(BuildContext context) {
    // 原来挂了个空的 onPressed，卡片因此有按下水波纹，看着能点其实什么都不做。
    // 这里只是把键名画出来，不是按钮。
    return CommonCard(
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(keyboardKey.label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
