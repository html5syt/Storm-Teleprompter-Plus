part of '../home_page.dart';

class _ExitProgressContent extends StatefulWidget {
  const _ExitProgressContent({required this.onForceExit});

  final VoidCallback onForceExit;

  @override
  State<_ExitProgressContent> createState() => _ExitProgressContentState();
}

class _ExitProgressContentState extends State<_ExitProgressContent> {
  Timer? _forceExitTimer;
  bool _showForceExit = false;

  @override
  void initState() {
    super.initState();
    _forceExitTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showForceExit = true);
    });
  }

  @override
  void dispose() {
    _forceExitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Expanded(child: Text('正在关闭服务并退出应用...')),
          ],
        ),
        if (_showForceExit) ...[
          const SizedBox(height: 18),
          Text(
            '正常退出耗时较长，可以强制结束应用。未完成的数据清理将被中断。',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMutedFor(context),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onForceExit,
              icon: const Icon(Icons.power_settings_new),
              label: const Text('强制退出'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter({required this.start, required this.end});

  final Offset start;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, end);
    canvas.drawRect(
      rect,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}
