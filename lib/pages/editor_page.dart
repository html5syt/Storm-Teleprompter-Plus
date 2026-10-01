import 'dart:async';
import 'dart:convert';

import 'package:dart_quill_delta/dart_quill_delta.dart' as qd;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
// QuillControllerConfig 尚未通过 flutter_quill 公共入口导出。
// ignore: implementation_imports
import 'package:flutter_quill/src/controller/quill_controller_config.dart'
    as quill_config;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:provider/provider.dart';
import '../backend/ws_protocol.dart';
import '../models/article.dart';
import '../providers/article_provider.dart';
import '../widgets/common/folder_picker_dialog.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/teleprompter_provider.dart';
import '../services/inline_style_parser.dart';
import '../services/text_parser.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_color_picker_dialog.dart';
import '../widgets/editor/editor_toolbar.dart';
import '../widgets/editor/editor_toolbar_style.dart';
import 'teleprompter_page.dart';

part 'editor/editor_logic.dart';
part 'editor/editor_quick_mode.dart';

/// 富文本稿件编辑器，快速模式允许仅在内存中保留草稿。
class EditorPage extends StatefulWidget {
  final Article? article;
  final String? initialFolderId;

  final bool quickMode;
  final bool autoSave;
  final bool isActive;
  final VoidCallback? onOpenLibrary;
  final Future<void> Function()? onExit;

  const EditorPage({
    super.key,
    this.article,
    this.initialFolderId,
    this.quickMode = false,
    this.autoSave = true,
    this.isActive = true,
    this.onOpenLibrary,
    this.onExit,
  });

  @override
  State<EditorPage> createState() => EditorPageState();
}

/// 暴露离开确认供稿件管理和系统退出入口复用。
class EditorPageState extends State<EditorPage>
    with EditorLogic, EditorQuickMode {
  @override
  Widget build(BuildContext context) {
    final isEditing = currentArticle != null;

    return PopScope(
      canPop: !widget.quickMode || !widget.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!widget.isActive) return;
        if (didPop) {
          flushAutosave();
          return;
        }
        unawaited(requestExit());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        floatingActionButton: widget.onOpenLibrary == null
            ? null
            : FloatingActionButton(
                heroTag: 'quick-library',
                tooltip: '稿件管理',
                onPressed: widget.onOpenLibrary,
                child: const Icon(Icons.folder_open),
              ),
        backgroundColor: AppColors.backgroundFor(context),
        appBar: AppBar(
          title: Text(isEditing ? '编辑稿件' : '新建稿件'),
          automaticallyImplyLeading: !widget.quickMode,
          actions: [
            if (!autoSaveEnabled)
              IconButton(
                tooltip: '保存',
                onPressed: isSaving ? null : manualSave,
                icon: const Icon(Icons.save_outlined),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '$plainTextLength 字',
                  style: TextStyle(
                    color: AppColors.textMutedFor(context),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  saveStatusText,
                  style: TextStyle(
                    color: isSaving
                        ? AppColors.warning
                        : isDirty
                        ? (autoSaveEnabled
                              ? AppColors.textMutedFor(context)
                              : AppColors.error)
                        : (!autoSaveEnabled && currentArticle == null
                              ? AppColors.error
                              : AppColors.success),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: '开始提词 (Ctrl+Alt+S)',
                child: FilledButton.icon(
                  onPressed: canStartTeleprompter
                      ? quickStartTeleprompter
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始提词'),
                ),
              ),
            ),
          ],
        ),
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
              if (autoSaveEnabled) {
                flushAutosave();
              } else {
                unawaited(manualSave());
              }
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (isFindReplaceVisible) {
                closeFindReplaceBar();
              } else {
                unawaited(requestExit());
              }
            },
            const SingleActivator(
              LogicalKeyboardKey.keyS,
              control: true,
              alt: true,
            ): () =>
                unawaited(quickStartTeleprompter()),
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
                showFindReplaceDialog(replaceMode: false),
            const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
                showFindReplaceDialog(replaceMode: true),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                      child: TextField(
                        controller: titleController,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryFor(context),
                        ),
                        decoration: const InputDecoration(
                          hintText: '稿件标题',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          filled: true,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        maxLines: 1,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppColors.borderLightFor(context),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          isFindReplaceVisible ? 92 : 12,
                        ),
                        child: _buildQuillEditor(),
                      ),
                    ),
                  ],
                ),
                if (isFindReplaceVisible) _buildFindReplaceBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatTools() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFormatButton(Icons.vertical_align_top, '删除空行', removeEmptyLines),
        _buildFormatButton(
          Icons.format_indent_decrease,
          '删除段首缩进',
          removeParagraphIndentation,
        ),
        _buildFormatButton(
          Icons.format_indent_increase,
          '段首缩进',
          addParagraphIndentation,
        ),
        _buildFormatButton(Icons.format_quote, '规范引号配对', normalizeQuotePairs),
      ],
    );
  }

  /// 文本清理和查找按钮复用统一工具栏样式。
  Widget _buildFormatButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    bool selected = false,
  }) {
    return EditorToolbarButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      selected: selected,
    );
  }

  Widget _buildQuillEditor() {
    final settings = context.watch<SettingsProvider>().mergedSettings;
    final editorBackground = Color(settings.teleprompterBgColor);
    final editorTextColor = settings.textColor != 0
        ? Color(settings.textColor)
        : const Color(0xFFFFFFFF);
    final editorTextStyle = TextStyle(
      color: editorTextColor,
      fontSize: 18,
      height: 1.45,
      fontFamily: settings.teleprompterFontFamily.isNotEmpty
          ? settings.teleprompterFontFamily
          : null,
    );
    final paragraphStyle = quill.DefaultTextBlockStyle(
      editorTextStyle,
      quill.HorizontalSpacing.zero,
      quill.VerticalSpacing.zero,
      quill.VerticalSpacing.zero,
      null,
    );

    return Container(
      decoration: BoxDecoration(
        color: editorBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Theme(
            data: AppTheme.fromColorAndFont(
              AppColors.primaryFromSettings(settings.uiPrimaryColor),
              fontFamily: settings.appFontFamily,
            ),
            child: EditorToolbar(
              controller: quillController,
              tools: [
                _buildFormatTools(),
                const SizedBox(width: EditorToolbarStyle.spacing),
                _buildFontSizeInput(),
                const SizedBox(width: EditorToolbarStyle.spacing),
                _buildEditorColorTools(editorTextColor, editorBackground),
                const SizedBox(width: EditorToolbarStyle.spacing),
                _buildFindButton(),
                _buildReplaceButton(),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Expanded(
            child: quill.QuillEditor.basic(
              controller: quillController,
              focusNode: editorFocusNode,
              config: quill.QuillEditorConfig(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                placeholder: '请输入稿件正文',
                expands: true,
                autoFocus: true,
                customStyles: quill.DefaultStyles(
                  paragraph: paragraphStyle,
                  placeHolder: quill.DefaultTextBlockStyle(
                    editorTextStyle.copyWith(
                      color: editorTextColor.withValues(alpha: 0.46),
                    ),
                    quill.HorizontalSpacing.zero,
                    quill.VerticalSpacing.zero,
                    quill.VerticalSpacing.zero,
                    null,
                  ),
                  color: editorTextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 字号输入与所有工具按钮等高，颜色由工具栏主题统一提供。
  Widget _buildFontSizeInput() {
    return Builder(
      builder: (context) => Tooltip(
        message: '选中文字字号，输入任意 px 数值后回车',
        child: SizedBox(
          width: 86,
          height: EditorToolbarStyle.buttonSize,
          child: TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            decoration: EditorToolbarStyle.fontSizeDecoration(context),
            onSubmitted: applyFontSize,
          ),
        ),
      ),
    );
  }

  Widget _buildEditorColorTools(
    Color defaultTextColor,
    Color defaultBackgroundColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildEditorColorButton(
          icon: Icons.format_color_text,
          tooltip: '字体颜色',
          attributeKey: quill.Attribute.color.key,
          fallbackColor: defaultTextColor,
        ),
        _buildEditorColorButton(
          icon: Icons.format_color_fill,
          tooltip: '文字背景色',
          attributeKey: quill.Attribute.background.key,
          fallbackColor: defaultBackgroundColor,
        ),
      ],
    );
  }

  Widget _buildEditorColorButton({
    required IconData icon,
    required String tooltip,
    required String attributeKey,
    required Color fallbackColor,
  }) {
    final color = _selectionColor(attributeKey, fallbackColor);
    return EditorToolbarButton(
      tooltip: tooltip,
      onPressed: () => _chooseEditorColor(
        title: tooltip,
        attributeKey: attributeKey,
        fallbackColor: fallbackColor,
      ),
      icon: SizedBox.square(
        dimension: EditorToolbarStyle.iconSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: EditorToolbarStyle.iconSize),
            Positioned(
              bottom: 0,
              child: Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _selectionColor(String attributeKey, Color fallbackColor) {
    final value = quillController
        .getSelectionStyle()
        .attributes[attributeKey]
        ?.value;
    return value is String
        ? AppColorHex.parse(value) ?? fallbackColor
        : fallbackColor;
  }

  Future<void> _chooseEditorColor({
    required String title,
    required String attributeKey,
    required Color fallbackColor,
  }) async {
    final selected = await AppColorPickerDialog.show(
      context,
      title: title,
      currentColor: _selectionColor(attributeKey, fallbackColor),
      resetLabel: '清除颜色',
      onReset: () => _clearEditorColor(attributeKey),
    );
    if (!mounted || selected == null) return;
    quillController.formatSelection(
      quill.Attribute.fromKeyValue(attributeKey, AppColorHex.format(selected))!,
    );
    _onQuillContentChanged();
  }

  void _clearEditorColor(String attributeKey) {
    if (!mounted) return;
    quillController.formatSelection(
      quill.Attribute.fromKeyValue(attributeKey, null)!,
    );
    _onQuillContentChanged();
  }

  Widget _buildFindButton() {
    return _buildFormatButton(
      Icons.search,
      '查找 (Ctrl+F)',
      () => showFindReplaceDialog(replaceMode: false),
      selected: isFindReplaceVisible && !isReplaceMode,
    );
  }

  Widget _buildReplaceButton() {
    return _buildFormatButton(
      Icons.find_replace,
      '替换 (Ctrl+H)',
      () => showFindReplaceDialog(replaceMode: true),
      selected: isFindReplaceVisible && isReplaceMode,
    );
  }

  Widget _buildFindReplaceBar() {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < (isReplaceMode ? 980 : 760);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bar = Material(
      elevation: 10,
      color: AppColors.surfaceElevatedFor(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: isNarrow ? _buildFindReplaceCompact() : _buildFindReplaceWide(),
      ),
    );

    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomInset + 12,
      child: bar,
    );
  }

  Widget _buildFindReplaceCompact() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _buildFindField()),
            IconButton(
              tooltip: '关闭',
              onPressed: closeFindReplaceBar,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        if (isReplaceMode) ...[const SizedBox(height: 6), _buildReplaceField()],
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildFindReplaceStatus()),
            _buildFindReplaceActions(),
          ],
        ),
      ],
    );
  }

  Widget _buildFindReplaceWide() {
    return Row(
      children: [
        SizedBox(width: 280, child: _buildFindField()),
        if (isReplaceMode) ...[
          const SizedBox(width: 8),
          SizedBox(width: 320, child: _buildReplaceField()),
        ],
        const SizedBox(width: 8),
        Expanded(child: _buildFindReplaceStatus()),
        _buildFindReplaceActions(),
        IconButton(
          tooltip: '关闭',
          onPressed: closeFindReplaceBar,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildFindField() {
    return TextField(
      controller: findController,
      focusNode: findFocusNode,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        labelText: '查找',
        isDense: true,
      ),
      onSubmitted: (_) => findNextMatch(),
    );
  }

  Widget _buildReplaceField() {
    return TextField(
      controller: replaceController,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.find_replace),
        labelText: '替换为',
        isDense: true,
      ),
      onSubmitted: (_) => replaceCurrentMatch(),
    );
  }

  Widget _buildFindReplaceStatus() {
    return Text(
      findReplaceStatus,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: AppColors.textMutedFor(context)),
    );
  }

  Widget _buildFindReplaceActions() {
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          tooltip: '查找下一个',
          onPressed: findNextMatch,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        if (isReplaceMode)
          IconButton(
            tooltip: '替换',
            onPressed: replaceCurrentMatch,
            icon: const Icon(Icons.find_replace),
          ),
        if (isReplaceMode)
          TextButton(onPressed: replaceAllMatches, child: const Text('全部替换')),
      ],
    );
  }
}
