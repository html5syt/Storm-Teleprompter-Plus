import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 最大化但保留边距的快速稿件管理面板，内部页面共用独立导航栈。
class QuickLibraryOverlay extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget library;
  final VoidCallback onClose;

  const QuickLibraryOverlay({
    super.key,
    required this.navigatorKey,
    required this.library,
    required this.onClose,
  });

  /// 系统返回先退出设置等子页面，再关闭面板，不退出背景中的编辑器。
  void _handleBack() {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.maybePop();
    } else {
      onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final margin = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 24.0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Stack(
        children: [
          ModalBarrier(
            color: Colors.black.withValues(
              alpha: AppColors.isLight(context) ? 0.24 : 0.52,
            ),
            dismissible: true,
            onDismiss: onClose,
            semanticsLabel: '回到编辑器',
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(margin),
              child: Material(
                key: const ValueKey('quick-library-panel'),
                elevation: 20,
                color: AppColors.backgroundFor(context),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: constraints.biggest,
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                    ),
                    child: HeroControllerScope.none(
                      child: Navigator(
                        key: navigatorKey,
                        pages: [
                          MaterialPage<void>(
                            key: const ValueKey('quick-library-root'),
                            child: library,
                          ),
                        ],
                        onDidRemovePage: (_) => onClose(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
