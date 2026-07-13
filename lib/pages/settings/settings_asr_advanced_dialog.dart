part of '../settings_page.dart';

/// ASR 高级设置对话框的不可变返回值。
class _AsrAdvancedSettingsResult {
  const _AsrAdvancedSettingsResult({
    required this.mirrorUrl,
    required this.numThreads,
    required this.rule1MinTrailingSilence,
    required this.rule2MinTrailingSilence,
    required this.rule3MinUtteranceLength,
    required this.useSystemProxy,
  });

  final String mirrorUrl;
  final int numThreads;
  final double rule1MinTrailingSilence;
  final double rule2MinTrailingSilence;
  final double rule3MinUtteranceLength;
  final bool useSystemProxy;
}

class _AsrAdvancedSettingsDialog extends StatefulWidget {
  const _AsrAdvancedSettingsDialog({required this.settings});

  final AppSettings settings;

  @override
  State<_AsrAdvancedSettingsDialog> createState() =>
      _AsrAdvancedSettingsDialogState();
}

class _AsrAdvancedSettingsDialogState
    extends State<_AsrAdvancedSettingsDialog> {
  late final TextEditingController _mirrorController;
  late final TextEditingController _threadsController;
  late final TextEditingController _rule1Controller;
  late final TextEditingController _rule2Controller;
  late final TextEditingController _rule3Controller;
  late bool _useSystemProxy;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _mirrorController = TextEditingController(text: settings.asrMirrorUrl);
    _threadsController = TextEditingController(
      text: settings.asrNumThreads.toString(),
    );
    _rule1Controller = TextEditingController(
      text: settings.asrRule1MinTrailingSilence.toString(),
    );
    _rule2Controller = TextEditingController(
      text: settings.asrRule2MinTrailingSilence.toString(),
    );
    _rule3Controller = TextEditingController(
      text: settings.asrRule3MinUtteranceLength.toString(),
    );
    _useSystemProxy = settings.asrUseSystemProxy;
  }

  @override
  void dispose() {
    _mirrorController.dispose();
    _threadsController.dispose();
    _rule1Controller.dispose();
    _rule2Controller.dispose();
    _rule3Controller.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _AsrAdvancedSettingsResult(
        mirrorUrl: _mirrorController.text.trim(),
        numThreads: int.tryParse(_threadsController.text.trim()) ?? 0,
        rule1MinTrailingSilence:
            double.tryParse(_rule1Controller.text.trim()) ?? 2.4,
        rule2MinTrailingSilence:
            double.tryParse(_rule2Controller.text.trim()) ?? 1.2,
        rule3MinUtteranceLength:
            double.tryParse(_rule3Controller.text.trim()) ?? 20,
        useSystemProxy: _useSystemProxy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('下载与高级设置'),
      content: SizedBox(
        width: 520,
        height: (MediaQuery.sizeOf(context).height * 0.7).clamp(320.0, 560.0),
        child: ListView(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('使用系统代理下载'),
              subtitle: const Text('自动读取操作系统或环境中的 HTTP/HTTPS 代理'),
              value: _useSystemProxy,
              onChanged: (value) => setState(() => _useSystemProxy = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mirrorController,
              decoration: const InputDecoration(
                labelText: '自定义下载镜像',
                hintText: '留空使用模型原始下载地址',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _threadsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '识别线程数',
                helperText: '0 表示根据处理器核心数自动选择',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rule1Controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '规则 1 尾部静音（秒）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rule2Controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '规则 2 尾部静音（秒）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rule3Controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '规则 3 最长语句（秒）'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
