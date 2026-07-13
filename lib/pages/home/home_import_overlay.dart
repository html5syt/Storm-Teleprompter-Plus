part of '../home_page.dart';

class _HomeImportOverlay extends StatelessWidget {
  const _HomeImportOverlay({
    required this.isImporting,
    required this.progress,
    required this.statusText,
  });

  final bool isImporting;
  final double? progress;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        color: AppColors.primary.withValues(alpha: isImporting ? 0.12 : 0.09),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(context).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    isImporting
                        ? Icons.inventory_2_outlined
                        : Icons.folder_copy,
                    key: ValueKey(isImporting),
                    color: AppColors.primary,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isImporting ? statusText : '释放以导入文件和文件夹',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isImporting ? '正在保留原目录层级' : '支持批量拖放 · 保留目录层级 · TXT / DOCX',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMutedFor(context),
                  ),
                ),
                if (isImporting) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 320,
                    child: LinearProgressIndicator(value: progress),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
