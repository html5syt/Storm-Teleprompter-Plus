import 'dart:async';
import 'dart:convert';

import 'package:dart_quill_delta/dart_quill_delta.dart' as qd;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/src/controller/quill_controller_config.dart'
    as quill_config;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:provider/provider.dart';
import '../backend/ws_protocol.dart';
import '../models/article.dart';
import '../providers/article_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/teleprompter_provider.dart';
import '../services/text_parser.dart';
import '../theme/app_colors.dart';
import 'teleprompter_page.dart';

part 'editor_logic.dart';

class EditorPage extends StatefulWidget {
  final Article? article;
  final String? initialFolderId;

  const EditorPage({super.key, this.article, this.initialFolderId});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with EditorLogic {
  @override
  Widget build(BuildContext context) {
    final isEditing = currentArticle != null;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, _) => flushAutosave(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? '编辑稿件' : '新建稿件'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '$plainTextLength 字',
                  style: const TextStyle(
                    color: AppColors.textMuted,
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
                        ? AppColors.textMuted
                        : AppColors.success,
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
                  onPressed: isSaving ? null : quickStartTeleprompter,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始提词'),
                ),
              ),
            ),
          ],
        ),
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              flushAutosave();
              unawaited(Navigator.maybePop(context));
            },
            const SingleActivator(
              LogicalKeyboardKey.keyS,
              control: true,
              alt: true,
            ): () =>
                unawaited(quickStartTeleprompter()),
          },
          child: Focus(
            autofocus: true,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                  child: TextField(
                    controller: titleController,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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
                const Divider(height: 1, color: AppColors.borderLight),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: _buildQuillEditor(),
                  ),
                ),
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

  Widget _buildFormatButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: const Size(34, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: AppColors.textSecondary,
            backgroundColor: AppColors.surface.withValues(alpha: 0.55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
          ),
        ),
      ),
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
    final toolbar = quill.QuillSimpleToolbar(
      controller: quillController,
      config: const quill.QuillSimpleToolbarConfig(
        showDividers: false,
        showFontFamily: false,
        showFontSize: false,
        showSmallButton: false,
        showInlineCode: false,
        showAlignmentButtons: false,
        showHeaderStyle: false,
        showListNumbers: false,
        showListBullets: false,
        showListCheck: false,
        showCodeBlock: false,
        showQuote: false,
        showIndent: false,
        showLink: false,
        showDirection: false,
        showSearchButton: false,
        showSubscript: false,
        showSuperscript: false,
        multiRowsDisplay: false,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: editorBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildFormatTools(),
                  const SizedBox(width: 8),
                  _buildFontSizeInput(),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 26, color: AppColors.borderLight),
                  const SizedBox(width: 6),
                  Expanded(child: toolbar),
                ],
              ),
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

  Widget _buildFontSizeInput() {
    return Tooltip(
      message: '选中文字字号，输入任意 px 数值后回车',
      child: SizedBox(
        width: 78,
        height: 34,
        child: TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: '字号',
            suffixText: 'px',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 8,
            ),
            filled: true,
            fillColor: AppColors.surface.withValues(alpha: 0.55),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.6),
              ),
            ),
          ),
          onSubmitted: applyFontSize,
        ),
      ),
    );
  }
}
