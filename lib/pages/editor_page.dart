import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../providers/article_provider.dart';
import '../theme/app_colors.dart';

/// 稿件编辑页面
///
/// 用于新建或编辑稿件的富文本编辑页面。
/// 支持标题和正文编辑、AI 优化（占位）。
class EditorPage extends StatefulWidget {
  final Article? article;

  const EditorPage({super.key, this.article});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isDirty = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.article?.title ?? '');
    _contentController = TextEditingController(
      text: widget.article?.content ?? '',
    );

    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.article != null;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showUnsavedDialog();
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
                  '${_contentController.text.length} 字',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            // 保存按钮
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
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
                controller: _titleController,
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

              // 工具栏
              _buildToolbar(),
              const SizedBox(height: 12),

              // 正文输入
              Container(
                constraints: const BoxConstraints(minHeight: 400),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: TextField(
                  controller: _contentController,
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
              ),

              const SizedBox(height: 16),

              // 格式帮助提示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        const Text(
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
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 格式工具栏
  Widget _buildToolbar() {
    return Wrap(
      spacing: 8,
      children: [
        _buildFormatButton(Icons.format_bold, '粗体', () {
          _insertTag('b');
        }),
        _buildFormatButton(Icons.format_italic, '斜体', () {
          _insertTag('i');
        }),
        _buildFormatButton(Icons.format_underlined, '下划线', () {
          _insertTag('u');
        }),
        _buildFormatButton(Icons.format_strikethrough, '删除线', () {
          _insertTag('s');
        }),
        _buildFormatButton(Icons.wrap_text, '段落', () {
          _insertTag('p');
        }),
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

  /// 插入 HTML 标签
  void _insertTag(String tag) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final selectedText = selection.textInside(text);

    String newText;
    int newCursorPos;

    if (selectedText.isNotEmpty) {
      newText = text.replaceRange(
        selection.start,
        selection.end,
        '<$tag>$selectedText</$tag>',
      );
      newCursorPos =
          selection.start +
          tag.length +
          2 +
          selectedText.length +
          tag.length +
          3;
    } else {
      newText = text.replaceRange(
        selection.start,
        selection.end,
        '<$tag></$tag>',
      );
      newCursorPos = selection.start + tag.length + 2;
    }

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }

  /// 保存稿件
  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入稿件正文')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = context.read<ArticleProvider>();

      if (widget.article != null) {
        // 更新
        await provider.updateArticle(
          widget.article!.id,
          title: title,
          content: content,
        );
      } else {
        // 创建
        await provider.createArticle(title: title, content: content);
      }

      if (mounted) {
        setState(() => _isDirty = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.article != null ? '稿件已更新' : '稿件已创建'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 未保存提示对话框
  void _showUnsavedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('未保存的更改'),
        content: const Text('当前有未保存的更改，是否放弃？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // 关闭对话框
              setState(() => _isDirty = false);
              Navigator.pop(context); // 返回上一页
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('放弃更改'),
          ),
        ],
      ),
    );
  }
}
