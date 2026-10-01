import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';

/// 统一速度单位，避免工具栏和进度条显示不同模式的数值。
String autoSpeedUnit(AppSettings settings) =>
    settings.isContinuousScroll ? '像素/秒' : '字/分';

/// 保留小数输入的精度，整数速度不显示无意义的小数位。
String autoSpeedText(AppSettings settings) =>
    formatAutoSpeed(settings.autoSpeed);

/// 浮点调速显示最多三位小数，仍以原始值参与帧积分。
String formatAutoSpeed(double speed) =>
    speed.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

/// 显示带符号的预设及自由输入；预设沿用当前滚动方向。
Future<void> showAutoSpeedPicker(
  BuildContext context,
  SettingsProvider provider,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _AutoSpeedPicker(provider: provider),
  );
}

/// 输入控制器随弹层一起销毁，避免退场动画访问已释放资源。
class _AutoSpeedPicker extends StatefulWidget {
  final SettingsProvider provider;
  const _AutoSpeedPicker({required this.provider});
  @override
  State<_AutoSpeedPicker> createState() => _AutoSpeedPickerState();
}

/// 自由速度输入与十档像素速度选择。
class _AutoSpeedPickerState extends State<_AutoSpeedPicker> {
  late final AppSettings _settings = widget.provider.mergedSettings;
  late final TextEditingController _controller = TextEditingController(
    text: autoSpeedText(_settings),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 拒绝无效和非有限数值；按行模式保持整数 WPM，匀速允许小数。
  void _apply(String value) {
    final speed = double.tryParse(value.trim());
    if (speed == null || !speed.isFinite) {
      setState(() => _error = '请输入有效速度');
      return;
    }
    widget.provider.setAutoSpeed(speed);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final presets = _settings.isContinuousScroll
        ? TeleprompterConstants.pixelSpeedPresets
        : TeleprompterConstants.speedPresets;
    final direction = _settings.autoSpeed < 0 ? -1 : 1;
    final unit = autoSpeedUnit(_settings);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择速度',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: '自定义速度',
                          suffixText: unit,
                          errorText: _error,
                        ),
                        onSubmitted: _apply,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => _apply(_controller.text),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              for (final preset in presets)
                ListTile(
                  title: Text('${preset * direction} $unit'),
                  trailing: preset * direction == _settings.autoSpeed
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => _apply('${preset * direction}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
