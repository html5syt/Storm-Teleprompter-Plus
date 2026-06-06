part of 'editor_page.dart';

/// 编辑器逻辑 mixin
///
/// 包含文本编辑、格式插入、保存等业务逻辑。
mixin EditorLogic on State<EditorPage> {
  late TextEditingController titleController;
  late TextEditingController contentController;
  bool isDirty = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.article?.title ?? '');
    contentController = TextEditingController(
      text: widget.article?.content ?? '',
    );

    titleController.addListener(_onChanged);
    contentController.addListener(_onChanged);
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!isDirty) {
      setState(() => isDirty = true);
    }
  }

  // ─── 文本编辑 ──────────────────────────────────────────

  /// 插入 HTML 格式标签
  void insertTag(String tag) {
    final text = contentController.text;
    final selection = contentController.selection;
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

    contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }

  /// 插入带属性的 HTML 标签
  void insertStyledTag(String tag, String attributes) {
    final text = contentController.text;
    final selection = contentController.selection;
    final selectedText = selection.textInside(text);

    String newText;
    int newCursorPos;

    if (selectedText.isNotEmpty) {
      newText = text.replaceRange(
        selection.start,
        selection.end,
        '<$tag $attributes>$selectedText</$tag>',
      );
      newCursorPos =
          selection.start +
          tag.length +
          1 +
          attributes.length +
          1 +
          selectedText.length +
          tag.length +
          3;
    } else {
      newText = text.replaceRange(
        selection.start,
        selection.end,
        '<$tag $attributes></$tag>',
      );
      newCursorPos = selection.start + tag.length + 1 + attributes.length + 1;
    }

    contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }

  // ─── 保存 ──────────────────────────────────────────────

  /// 保存稿件
  Future<void> save() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入稿件正文')));
      return;
    }

    setState(() => isSaving = true);

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
        setState(() => isDirty = false);
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
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// 未保存提示对话框
  void showUnsavedDialog() {
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
              setState(() => isDirty = false);
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
