import 'package:flutter/material.dart';

import '../../core/controllers/teleprompter_controller.dart';
import '../../core/models/app_models.dart';

class ScriptEditorPage extends StatefulWidget {
  const ScriptEditorPage({
    super.key,
    required this.controller,
    required this.scriptId,
  });

  final TeleprompterController controller;
  final String scriptId;

  @override
  State<ScriptEditorPage> createState() => _ScriptEditorPageState();
}

class _ScriptEditorPageState extends State<ScriptEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final FocusNode _contentFocusNode = FocusNode();

  ScriptDocument? get _script {
    for (final script in widget.controller.scripts) {
      if (script.id == widget.scriptId) {
        return script;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final script = _script;
    _titleController = TextEditingController(text: script?.title ?? '未命名稿件');
    _contentController = TextEditingController(text: script?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _wrapSelection(String prefix, String suffix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      final insertion = '$prefix$suffix';
      final nextText = text.replaceRange(
        selection.start,
        selection.end,
        insertion,
      );
      _contentController.text = nextText;
      _contentController.selection = TextSelection.collapsed(
        offset: selection.start + prefix.length,
      );
      return;
    }
    final selected = text.substring(selection.start, selection.end);
    final replaced = text.replaceRange(
      selection.start,
      selection.end,
      '$prefix$selected$suffix',
    );
    _contentController.text = replaced;
    _contentController.selection = TextSelection.collapsed(
      offset: selection.end + prefix.length + suffix.length,
    );
  }

  Future<void> _save() async {
    final script = _script;
    if (script == null) {
      return;
    }
    await widget.controller.upsertScript(
      script.copyWith(
        title: _titleController.text.trim().isEmpty
            ? '未命名稿件'
            : _titleController.text.trim(),
        content: _contentController.text,
        lastModified: DateTime.now(),
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('脚本编辑器'),
        actions: <Widget>[
          IconButton(
            tooltip: '保存',
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: '稿件标题'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _save, child: const Text('保存并返回')),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _FormatChip(
                  label: '粗体',
                  onTap: () => _wrapSelection('<strong>', '</strong>'),
                ),
                _FormatChip(
                  label: '斜体',
                  onTap: () => _wrapSelection('<em>', '</em>'),
                ),
                _FormatChip(
                  label: '下划线',
                  onTap: () => _wrapSelection('<u>', '</u>'),
                ),
                _FormatChip(
                  label: '删除线',
                  onTap: () => _wrapSelection('<s>', '</s>'),
                ),
                _FormatChip(label: '换行', onTap: () => _wrapSelection('\n', '')),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: '正文内容',
                  alignLabelWithHint: true,
                  hintText:
                      '支持简单 HTML 风格标记，例如 <strong>加粗</strong>、<em>斜体</em>、<u>下划线</u>。',
                  helperText: '提词器会自动解析段落、换行和基础格式。',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}
