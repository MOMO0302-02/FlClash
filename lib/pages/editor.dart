import 'dart:convert';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/common.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

typedef EditingValueChangeBuilder = Widget Function(CodeLineEditingValue value);
typedef TextEditingValueChangeBuilder = Widget Function(TextEditingValue value);

class EditorPage extends ConsumerStatefulWidget {
  final String title;
  final String? content;
  final List<Language> languages;
  final bool supportRemoteDownload;
  final bool titleEditable;
  final Function(BuildContext context, String title, String content)? onSave;
  final Future<bool> Function(
    BuildContext context,
    String title,
    String content,
  )?
  onPop;

  const EditorPage({
    super.key,
    required this.title,
    required this.content,
    this.titleEditable = false,
    this.onSave,
    this.onPop,
    this.supportRemoteDownload = false,
    this.languages = const [Language.yaml],
  });

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  late CodeLineEditingController _controller;
  late CodeFindController _findController;
  late TextEditingController _titleController;
  late FocusNode _focusNode;
  late bool readOnly = false;
  late final SelectionToolbarController _toolbarController;

  @override
  void initState() {
    super.initState();
    readOnly = widget.onSave == null;
    _toolbarController = ContextMenuControllerImpl(readOnly);
    _focusNode = FocusNode();
    _controller = CodeLineEditingController.fromText(widget.content);
    _findController = CodeFindController(_controller);
    _titleController = TextEditingController(text: widget.title);
    if (system.isDesktop) {
      return;
    }
    _focusNode.onKeyEvent = ((_, event) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final key = event.logicalKey;
      if (!keys.contains(key)) {
        return KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _controller.moveCursor(AxisDirection.up);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        _controller.moveCursor(AxisDirection.down);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _controller.selection.endIndex;
        _controller.moveCursor(AxisDirection.left);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _controller.moveCursor(AxisDirection.right);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    });
  }

  @override
  void didUpdateWidget(covariant oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 页面可能在这一帧之前就被弹掉（预览页会随内容变化重建本页），
      // 那时控制器已经 dispose，再写 text 会直接抛。
      if (!mounted) {
        return;
      }
      final content = widget.content;
      if (content != null && oldWidget.content != content) {
        _controller.text = content;
        _controller.clearHistory();
      }
    });
  }

  @override
  void dispose() {
    _toolbarController.hide(context);
    _findController.dispose();
    _controller.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _wrapController(EditingValueChangeBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (_, value, _) {
        return builder(value);
      },
    );
  }

  Widget _wrapTitleController(TextEditingValueChangeBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _titleController,
      builder: (_, value, _) {
        return builder(value);
      },
    );
  }

  void _handleSearch() {
    _findController.findMode();
  }

  Future<void> _handleImportFormFile() async {
    await globalState.safeRun(() async {
      final file = await picker.pickerFile();
      if (file == null) {
        return;
      }
      // A non-UTF-8 pick throws; surface it instead of failing silently.
      final text = utf8.decode(await file.readBytes());
      // 和 didUpdateWidget 里那条注释同一个道理：等这些 await 回来时页面可能
      // 已经被弹掉、_controller 已 dispose，再写 text 会抛。而 safeRun 会把它
      // 当成导入失败弹一个错误框，用户看到的是一句莫名其妙的报错。
      if (!mounted) {
        return;
      }
      _controller.text = text;
    }, silence: false);
  }

  Future<void> _handleImportFormUrl() async {
    final appLocalizations = context.appLocalizations;
    final url = await globalState.showCommonDialog(
      child: InputDialog(
        title: appLocalizations.import,
        value: '',
        labelText: appLocalizations.url,
        inputFormatters: TextInputLimits.limit(TextInputLimits.url),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.value);
          }
          if (!value.isUrl) {
            return appLocalizations.urlTip(appLocalizations.value);
          }
          return null;
        },
      ),
    );
    if (url == null) {
      return;
    }
    await globalState.safeRun(() async {
      final res = await request.getTextResponseForUrl(url);
      // 网络请求期间界面并没有被挡住，用户完全可以按返回离开编辑器；
      // 那时 _controller 已经 dispose，再写 text 会抛。
      if (!mounted) {
        return;
      }
      _controller.text = res.data ?? '';
    }, silence: false);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isMobileView = ref.watch(isMobileViewProvider);
    final colorScheme = context.colorScheme;
    final accent = context.styleTokens.accent(colorScheme);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codeFontSize = context.textTheme.bodyLarge?.fontSize?.ap;
    return CommonPopScope(
      onPop: (context) async {
        if (widget.onPop == null) {
          return true;
        }
        final res = await widget.onPop!(
          context,
          _titleController.text,
          _controller.text,
        );
        if (res && context.mounted) {
          return true;
        }
        return false;
      },
      child: CommonScaffold(
        appBar: AppBar(
          // 标题不可改时不要留一个禁用的输入框：Material 会把它画成灰字，
          // 看起来像「这里本该能编辑但坏了」。不可改就画成普通标题。
          title: widget.titleEditable
              ? TextField(
                  maxLength: 20,
                  controller: _titleController,
                  decoration: InputDecoration(
                    border: const NoInputBorder(),
                    counter: const SizedBox(),
                    hintText: appLocalizations.unnamed,
                    hintStyle: context.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  cursorColor: accent,
                  style: context.textTheme.titleLarge,
                  autofocus: false,
                )
              : Text(
                  widget.title.isEmpty
                      ? appLocalizations.unnamed
                      : widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleLarge,
                ),
          actions: genActions([
            if (!readOnly)
              _wrapController(
                (value) => _wrapTitleController(
                  (value) => IconButton(
                    onPressed:
                        _controller.text != widget.content ||
                            _titleController.text != widget.title
                        ? () {
                            widget.onSave!(
                              context,
                              _titleController.text,
                              _controller.text,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.save),
                  ),
                ),
              ),
            _wrapController(
              (value) => CommonPopupBox(
                targetBuilder: (open) {
                  return IconButton(
                    onPressed: () {
                      final isMobile = ref.read(isMobileViewProvider);
                      open(offset: Offset(0, isMobile ? 0 : 20));
                    },
                    icon: const Icon(Icons.more_vert),
                  );
                },
                popup: CommonPopupMenu(
                  items: [
                    PopupMenuItemData(
                      icon: Icons.search,
                      label: appLocalizations.search,
                      onPressed: _handleSearch,
                    ),
                    PopupMenuItemData(
                      icon: Icons.undo,
                      label: appLocalizations.undo,
                      onPressed: _controller.canUndo ? _controller.undo : null,
                    ),
                    PopupMenuItemData(
                      icon: Icons.redo,
                      label: appLocalizations.redo,
                      onPressed: _controller.canRedo ? _controller.redo : null,
                    ),
                    if (widget.supportRemoteDownload && !readOnly)
                      PopupMenuItemData(
                        icon: Icons.arrow_downward,
                        label: appLocalizations.externalFetch,
                        subItems: [
                          PopupMenuItemData(
                            label: appLocalizations.importUrl,
                            onPressed: _handleImportFormUrl,
                          ),
                          PopupMenuItemData(
                            label: appLocalizations.importFile,
                            onPressed: _handleImportFormFile,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),
        body: Stack(
          children: [
            CodeEditor(
              readOnly: readOnly,
              autofocus: false,
              showCursorWhenReadOnly: false,
              findController: _findController,
              findBuilder: (context, controller, readOnly) => FindPanel(
                controller: controller,
                readOnly: readOnly,
                isMobileView: isMobileView,
              ),
              padding: const EdgeInsets.only(right: 16),
              autocompleteSymbols: true,
              focusNode: _focusNode,
              scrollbarBuilder: (context, child, details) {
                return CommonScrollBar(
                  controller: details.controller,
                  child: child,
                );
              },
              toolbarController: _toolbarController,
              indicatorBuilder:
                  (context, editingController, chunkController, notifier) {
                    return Row(
                      children: [
                        DefaultCodeLineNumber(
                          controller: editingController,
                          notifier: notifier,
                          // 行号默认取正文色，在纯黑底上和代码一样亮，喧宾夺主。
                          // 压到次要文字色，当前行才用正文色标出来。
                          textStyle: TextStyle(
                            fontSize: codeFontSize,
                            fontFamily: FontFamily.jetBrainsMono.value,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          focusedTextStyle: TextStyle(
                            fontSize: codeFontSize,
                            fontFamily: FontFamily.jetBrainsMono.value,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        DefaultCodeChunkIndicator(
                          width: 20,
                          controller: chunkController,
                          notifier: notifier,
                        ),
                      ],
                    );
                  },
              shortcutsActivatorsBuilder:
                  const DefaultCodeShortcutsActivatorsBuilder(),
              controller: _controller,
              style: CodeEditorStyle(
                fontSize: codeFontSize,
                fontFamily: FontFamily.jetBrainsMono.value,
                // 编辑区自己不画底色的话会露出 Material 的默认白，和纯黑的应用
                // 完全脱节；语法高亮同理，浅色配色在深色底上几乎读不出来。
                backgroundColor: colorScheme.surface,
                textColor: colorScheme.onSurface,
                cursorColor: accent,
                selectionColor: accent.opacity30,
                cursorLineColor: colorScheme.surfaceContainerLow,
                chunkIndicatorColor: colorScheme.onSurfaceVariant,
                codeTheme: CodeHighlightTheme(
                  languages: {
                    if (widget.languages.contains(Language.yaml))
                      'yaml': CodeHighlightThemeMode(mode: langYaml),
                    if (widget.languages.contains(Language.javaScript))
                      'javascript': CodeHighlightThemeMode(
                        mode: langJavascript,
                      ),
                    if (widget.languages.contains(Language.json))
                      'json': CodeHighlightThemeMode(mode: langJson),
                  },
                  theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                ),
              ),
            ),
            FadeBox(
              child: widget.content == null
                  ? Container(
                      color: context.colorScheme.surface,
                      alignment: Alignment.center,
                      child: const SizedBox.square(
                        dimension: 200,
                        child: HeroSpinner(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

const double _kDefaultFindPanelHeight = 52;

class FindPanel extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController controller;
  final bool readOnly;
  final bool isMobileView;
  final double height;

  const FindPanel({
    super.key,
    required this.controller,
    required this.readOnly,
    required this.isMobileView,
  }) : height =
           (isMobileView
               ? _kDefaultFindPanelHeight * 2
               : _kDefaultFindPanelHeight) +
           8;

  @override
  Size get preferredSize =>
      Size(double.infinity, controller.value == null ? 0 : height);

  @override
  Widget build(BuildContext context) {
    if (controller.value == null) {
      return const SizedBox(width: 0, height: 0);
    }
    final tokens = context.styleTokens;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      // 查找条浮在代码之上，用和卡片同一层的底色 + 那圈高光边把它托起来，
      // 否则它和编辑区同色，看起来像代码里凭空多出来一行控件。
      decoration: ShapeDecoration(
        color: context.colorScheme.surfaceContainerLow,
        shape: RoundedSuperellipseBorder(
          side: BorderSide(color: tokens.rim),
          borderRadius: BorderRadius.circular(tokens.cardRadius),
        ),
      ),
      alignment: Alignment.centerLeft,
      height: height,
      child: _buildFindInputView(context),
    );
  }

  Widget _buildFindInputView(BuildContext context) {
    final CodeFindValue value = controller.value!;
    final String result;
    if (value.result == null) {
      result = context.appLocalizations.none;
    } else {
      result = '${value.result!.index + 1}/${value.result!.matches.length}';
    }
    final bar = CommonMinIconButtonTheme(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isMobileView) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _buildFindInput(context, value),
            ),
            const SizedBox(width: 12),
          ],
          Text(result, style: context.textTheme.bodyMedium),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 2,
              children: [
                _buildIconButton(
                  onPressed: value.result == null
                      ? null
                      : () {
                          controller.previousMatch();
                        },
                  icon: Icons.arrow_upward,
                ),
                _buildIconButton(
                  onPressed: value.result == null
                      ? null
                      : () {
                          controller.nextMatch();
                        },
                  icon: Icons.arrow_downward,
                ),
                const SizedBox(width: 2),
                IconButton(
                  onPressed: controller.close,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        context.colorScheme.surfaceContainerHighest,
                    foregroundColor: context.colorScheme.onSurface,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(
                        context.styleTokens.controlRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (isMobileView) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          bar,
          const SizedBox(height: 12),
          _buildFindInput(context, value),
        ],
      );
    }
    return bar;
  }

  Widget _buildFindInput(BuildContext context, CodeFindValue value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: 8,
      children: [
        Flexible(
          child: _buildTextField(
            context: context,
            onSubmitted: () {
              if (value.result == null) {
                return;
              }
              controller.nextMatch();
              controller.findInputFocusNode.requestFocus();
            },
            controller: controller.findInputController,
            focusNode: controller.findInputFocusNode,
          ),
        ),
        _buildCheckText(
          context: context,
          text: 'Aa',
          isSelected: value.option.caseSensitive,
          onPressed: () {
            controller.toggleCaseSensitive();
          },
        ),
        _buildCheckText(
          context: context,
          text: '.*',
          isSelected: value.option.regex,
          onPressed: () {
            controller.toggleRegex();
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onSubmitted,
  }) {
    final tokens = context.styleTokens;
    // Material 默认的方角描边输入框一眼就能认出来，换成和其它控件同一档圆角、
    // 同一圈高光边，聚焦时才用强调色。
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.controlRadius),
      borderSide: BorderSide(color: tokens.rim),
    );
    return SizedBox(
      height: globalState.measure.bodyMediumHeight + 8 * 2,
      child: TextField(
        maxLines: 1,
        focusNode: focusNode,
        inputFormatters: TextInputLimits.limit(TextInputLimits.search),
        style: context.textTheme.bodyMedium,
        cursorColor: tokens.accent(context.colorScheme),
        decoration: InputDecoration(
          filled: true,
          fillColor: context.colorScheme.surfaceContainerHigh,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: tokens.accent(context.colorScheme)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onSubmitted: (_) {
          onSubmitted();
        },
        controller: controller,
      ),
    );
  }

  Widget _buildCheckText({
    required BuildContext context,
    required String text,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final colorScheme = context.colorScheme;
    final tokens = context.styleTokens;
    // 选中态跟卡片一个口径：整块填强调色、文字转白。原来用的 filledTonal 是
    // Material 的柔和容器色，和应用里其它「选中」长得不一样。
    return SizedBox(
      width: 28,
      height: 28,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: IconButton(
          onPressed: onPressed,
          padding: const EdgeInsets.all(2),
          style: IconButton.styleFrom(
            backgroundColor: isSelected ? tokens.accent(colorScheme) : null,
            foregroundColor: isSelected
                ? tokens.onAccent(colorScheme)
                : colorScheme.onSurfaceVariant,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(tokens.controlRadius),
            ),
          ),
          // 图标位放的是文字，取不到 IconTheme 的颜色，得自己上色。
          icon: Text(
            text,
            style: context.textTheme.bodySmall?.copyWith(
              color: isSelected
                  ? tokens.onAccent(colorScheme)
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, VoidCallback? onPressed}) {
    return IconButton(onPressed: onPressed, icon: Icon(icon, size: 16));
  }
}

class ContextMenuControllerImpl implements SelectionToolbarController {
  OverlayEntry? _overlayEntry;
  bool _isFirstRender = true;
  bool readOnly = false;

  ContextMenuControllerImpl(this.readOnly);

  void _removeOverLayEntry() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isFirstRender = true;
  }

  @override
  void hide(BuildContext context) {
    _removeOverLayEntry();
  }

  @override
  void show({
    required context,
    required controller,
    required anchors,
    renderRect,
    required layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    _removeOverLayEntry();
    _overlayEntry ??= OverlayEntry(
      builder: (context) => CodeEditorTapRegion(
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, _, child) {
            final appLocalizations = context.appLocalizations;
            final isNotEmpty = controller.selectedText.isNotEmpty;
            final isAllSelected = controller.isAllSelected;
            final hasSelected = controller.selectedText.isNotEmpty;
            final List<PopupMenuItemData> menus = [
              if (isNotEmpty)
                PopupMenuItemData(
                  label: appLocalizations.copy,
                  onPressed: controller.copy,
                ),
              if (!readOnly)
                PopupMenuItemData(
                  label: appLocalizations.paste,
                  onPressed: controller.paste,
                ),
              if (isNotEmpty && !readOnly)
                PopupMenuItemData(
                  label: appLocalizations.cut,
                  onPressed: controller.cut,
                ),
              if (hasSelected && !isAllSelected)
                PopupMenuItemData(
                  label: appLocalizations.selectAll,
                  onPressed: controller.selectAll,
                ),
            ];
            if (_isFirstRender) {
              _isFirstRender = false;
            } else if (controller.selectedText.isEmpty) {
              _removeOverLayEntry();
            }
            if (menus.isEmpty) {
              _removeOverLayEntry();
              return const SizedBox();
            }
            return TextSelectionToolbar(
              anchorAbove: anchors.primaryAnchor,
              anchorBelow: anchors.secondaryAnchor ?? Offset.zero,
              children: menus.asMap().entries.map((
                MapEntry<int, PopupMenuItemData> entry,
              ) {
                return TextSelectionToolbarTextButton(
                  padding: TextSelectionToolbarTextButton.getPadding(
                    entry.key,
                    menus.length,
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  onPressed: () {
                    if (entry.value.onPressed == null) {
                      return;
                    }
                    entry.value.onPressed!();
                    _removeOverLayEntry();
                  },
                  child: Text(entry.value.label),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }
}
