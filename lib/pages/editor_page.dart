import 'dart:async';
import 'dart:convert';

import 'package:dart_quill_delta/dart_quill_delta.dart' as qd;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../providers/article_provider.dart';
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
              child: FilledButton.icon(
                onPressed: isSaving ? null : quickStartTeleprompter,
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始提词'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                controller: titleController,
                style: const TextStyle(
                  fontSize: 22,
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
                ),
                maxLines: 1,
                textInputAction: TextInputAction.next,
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: _buildFormatTools(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildQuillEditor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatTools() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFormatButton(
            Icons.vertical_align_top,
            '删除空行',
            removeEmptyLines,
          ),
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
      ),
    );
  }

  Widget _buildFormatButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(tooltip),
        ),
      ),
    );
  }

  Widget _buildQuillEditor() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          quill.QuillSimpleToolbar(
            controller: quillController,
            config: const quill.QuillSimpleToolbarConfig(
              showDividers: false,
              showFontFamily: false,
              showFontSize: true,
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
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Expanded(
            child: quill.QuillEditor.basic(
              controller: quillController,
              config: const quill.QuillEditorConfig(
                padding: EdgeInsets.all(18),
                placeholder: '请输入稿件正文',
                expands: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
