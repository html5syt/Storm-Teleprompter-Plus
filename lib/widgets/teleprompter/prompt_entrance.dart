import 'package:flutter/material.dart';

/// 正文从视口底部滑入，使用缓出曲线先快后慢，工具栏不参与位移。
class PromptEntrance extends StatefulWidget {
  final Widget child;
  const PromptEntrance({super.key, required this.child});

  @override
  State<PromptEntrance> createState() => _PromptEntranceState();
}

/// 动画仅在进入页面时播放一次，设置刷新和暂停恢复不会重播。
class _PromptEntranceState extends State<PromptEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _position = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(_curve);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: SlideTransition(position: _position, child: widget.child),
  );
}
