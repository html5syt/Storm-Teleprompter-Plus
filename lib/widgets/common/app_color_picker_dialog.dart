import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

abstract final class AppColorHex {
  AppColorHex._();

  static Color? parse(String value) {
    final normalized = value.trim().replaceFirst('#', '');
    if (normalized.length != 6 && normalized.length != 8) return null;
    final argb = normalized.length == 6 ? 'FF$normalized' : normalized;
    final parsed = int.tryParse(argb, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static String format(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// 应用统一使用的颜色选择对话框。
///
/// 支持颜色面板、ARGB/RGB HEX 输入以及可选的恢复默认颜色操作。
class AppColorPickerDialog extends StatefulWidget {
  const AppColorPickerDialog({
    super.key,
    required this.title,
    required this.currentColor,
    this.resetColor,
    this.resetLabel = '恢复默认',
    this.onReset,
  });

  final String title;
  final Color currentColor;
  final Color? resetColor;
  final String resetLabel;
  final VoidCallback? onReset;

  static Future<Color?> show(
    BuildContext context, {
    required String title,
    required Color currentColor,
    Color? resetColor,
    String resetLabel = '恢复默认',
    VoidCallback? onReset,
  }) {
    return showDialog<Color>(
      context: context,
      builder: (_) => AppColorPickerDialog(
        title: title,
        currentColor: currentColor,
        resetColor: resetColor,
        resetLabel: resetLabel,
        onReset: onReset,
      ),
    );
  }

  @override
  State<AppColorPickerDialog> createState() => _AppColorPickerDialogState();
}

class _AppColorPickerDialogState extends State<AppColorPickerDialog> {
  late Color _pickerColor;
  late final TextEditingController _hexController;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _pickerColor = widget.currentColor;
    _hexController = TextEditingController(
      text: AppColorHex.format(_pickerColor),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 80;
    final dialogWidth = availableWidth.clamp(0.0, 420.0).toDouble();
    final pickerWidth = dialogWidth.clamp(0.0, 360.0).toDouble();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.title),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: ColorPicker(
                  pickerColor: _pickerColor,
                  onColorChanged: (color) => setState(() {
                    _pickerColor = color;
                    _hexError = null;
                    _syncHex(color);
                  }),
                  enableAlpha: true,
                  displayThumbColor: true,
                  colorPickerWidth: pickerWidth,
                  pickerAreaHeightPercent: 0.62,
                  labelTypes: const [],
                  hexInputBar: false,
                  portraitOnly: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextField(
                  controller: _hexController,
                  decoration: InputDecoration(
                    labelText: 'HEX 颜色值',
                    hintText: '#AARRGGBB 或 #RRGGBB',
                    errorText: _hexError,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    counterText: '',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
                  ],
                  maxLength: 9,
                  onChanged: _updateFromHex,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        if (widget.resetColor != null || widget.onReset != null)
          TextButton(
            onPressed: () {
              widget.onReset?.call();
              Navigator.pop(
                context,
                widget.onReset == null ? widget.resetColor : null,
              );
            },
            child: Text(widget.resetLabel),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _pickerColor),
          child: const Text('确定'),
        ),
      ],
    );
  }

  void _updateFromHex(String value) {
    final parsed = AppColorHex.parse(value);
    setState(() {
      _hexError = parsed == null ? '请输入 6 或 8 位十六进制颜色' : null;
      if (parsed != null) _pickerColor = parsed;
    });
  }

  void _syncHex(Color color) {
    final text = AppColorHex.format(color);
    _hexController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
