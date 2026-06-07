import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../models/script_character.dart';
import '../providers/article_provider.dart';
import '../services/text_parser.dart';
import '../theme/app_colors.dart';

part 'editor_logic.dart';

/// 稿件编辑页面
///
/// 用于新建或编辑稿件的富文本编辑页面。
/// UI 布局文件，业务逻辑由 [EditorLogic] mixin 提供。
class EditorPage extends StatefulWidget {
  final Article? article;

  const EditorPage({super.key, this.article});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with EditorLogic {
  bool _wysiwygMode = false;

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.article != null;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          showUnsavedDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? '编辑稿件' : '新建稿件'),
          actions: [
            // 字数统计
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${contentController.text.length} 字',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            // WYSIWYG / 源码切换
            IconButton(
              icon: Icon(
                _wysiwygMode ? Icons.code : Icons.visibility,
                color: _wysiwygMode
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.textSecondary,
              ),
              tooltip: _wysiwygMode ? '源码模式' : '预览模式',
              onPressed: () {
                setState(() => _wysiwygMode = !_wysiwygMode);
              },
            ),
            // 保存按钮
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: isSaving ? null : save,
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('保存'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题输入
              TextField(
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

              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 16),

              // WYSIWYG 模式下隐藏工具栏和源输入，显示预览
              if (!_wysiwygMode) ...[
                // 工具栏
                _buildToolbar(),
                const SizedBox(height: 12),

                // 正文输入（源码模式）
                _buildContentInput(),
              ] else
                // WYSIWYG 预览
                _buildWysiwygPreview(),

              const SizedBox(height: 16),

              // 格式帮助提示（仅源码模式显示）
              if (!_wysiwygMode) _buildFormatHelp(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 格式工具栏 ──────────────────────────────────────

  Widget _buildToolbar() {
    return Wrap(
      spacing: 8,
      children: [
        _buildFormatButton(Icons.format_bold, '粗体', () => insertTag('b')),
        _buildFormatButton(Icons.format_italic, '斜体', () => insertTag('i')),
        _buildFormatButton(
          Icons.format_underlined,
          '下划线',
          () => insertTag('u'),
        ),
        _buildFormatButton(
          Icons.format_strikethrough,
          '删除线',
          () => insertTag('s'),
        ),
        _buildFormatButton(Icons.wrap_text, '段落', () => insertTag('p')),
        _buildBgColorButton(),
        const SizedBox(width: 8),
        _buildFormatButton(Icons.vertical_align_top, '清除空行', removeEmptyLines),
        _buildFormatButton(
          Icons.format_indent_increase,
          '段首缩进',
          indentParagraphs,
        ),
      ],
    );
  }

  /// 背景色按钮
  Widget _buildBgColorButton() {
    return Tooltip(
      message: '背景色',
      child: InkWell(
        onTap: () => _showBgColorPicker(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.format_color_fill,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 显示背景色选择器
  void _showBgColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final colors = [
            null, // 无颜色
            0xFFFFEB3B, // 黄色
            0xFF4CAF50, // 绿色
            0xFF2196F3, // 蓝色
            0xFFFF5722, // 橙色
            0xFFE91E63, // 粉色
            0xFF9C27B0, // 紫色
            0xFF00BCD4, // 青色
          ];
          return AlertDialog(
            title: const Text('选择背景色'),
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(colors.length, (i) {
                final c = colors[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    if (c != null) {
                      insertStyledTag(
                        'span',
                        'style="background-color: #${c.toRadixString(16).padLeft(8, '0')}"',
                      );
                    } else {
                      insertStyledTag(
                        'span',
                        'style="background-color: transparent"',
                      );
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c != null ? Color(c) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.border,
                        width: c == null ? 2 : 1,
                      ),
                    ),
                    child: c == null
                        ? const Icon(
                            Icons.close,
                            size: 18,
                            color: AppColors.textSecondary,
                          )
                        : null,
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormatButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  // ─── WYSIWYG 预览 ──────────────────────────────────

  Widget _buildWysiwygPreview() {
    final content = contentController.text;
    if (content.trim().isEmpty) {
      return Container(
        constraints: const BoxConstraints(minHeight: 400),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Center(
          child: Text(
            '暂无内容，切换到源码模式输入文本',
            style: TextStyle(color: AppColors.textDisabled),
          ),
        ),
      );
    }

    final lines = TextParser.isHtml(content)
        ? TextParser.parse(content)
        : TextParser.parsePlainText(content);

    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          if (line.characters.isEmpty) {
            return const SizedBox(height: 16);
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildRichLine(line),
          );
        }).toList(),
      ),
    );
  }

  /// 渲染带格式的行
  Widget _buildRichLine(ScriptLine line) {
    return RichText(
      text: TextSpan(
        children: line.characters.map((char) {
          final baseStyle = TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            height: 1.8,
            fontWeight: char.bold ? FontWeight.w700 : FontWeight.w400,
            fontStyle: char.italic ? FontStyle.italic : FontStyle.normal,
            decoration: TextDecoration.combine([
              if (char.underline) TextDecoration.underline,
              if (char.strikeThrough) TextDecoration.lineThrough,
            ]),
            background: char.backgroundColor != null
                ? (Paint()..color = Color(char.backgroundColor!))
                : null,
          );
          return TextSpan(text: char.char, style: baseStyle);
        }).toList(),
      ),
    );
  }

  // ─── 正文输入 ────────────────────────────────────────

  Widget _buildContentInput() {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: TextField(
        controller: contentController,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
          height: 1.8,
        ),
        decoration: const InputDecoration(
          hintText:
              '在这里输入稿件正文...\n\n支持 HTML 标签来添加格式：\n<b>粗体</b> <i>斜体</i> <u>下划线</u>',
          hintStyle: TextStyle(
            color: AppColors.textDisabled,
            fontSize: 14,
            height: 1.8,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          fillColor: Colors.transparent,
          filled: true,
          contentPadding: EdgeInsets.all(16),
        ),
        maxLines: null,
        minLines: 20,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
      ),
    );
  }

  // ─── 格式帮助 ────────────────────────────────────────

  Widget _buildFormatHelp() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.help_outline, size: 16, color: AppColors.textMuted),
              SizedBox(width: 8),
              Text(
                '格式提示',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• 直接输入纯文本即可正常使用\n'
            '• 支持 HTML 标签: <b>粗体</b> <i>斜体</i> <u>下划线</u> <s>删除线</s>\n'
            '• 使用 <p> 或换行来分段\n'
            '• 建议每次输入一个完整段落，便于提词器滚动',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
