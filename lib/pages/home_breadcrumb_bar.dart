part of 'home_page.dart';

class _HomeBreadcrumbBar extends StatelessWidget {
  const _HomeBreadcrumbBar({
    required this.controller,
    required this.breadcrumb,
    required this.currentFolderId,
    required this.onNavigate,
    required this.canDrop,
    required this.onDrop,
  });

  final ScrollController controller;
  final List<Folder> breadcrumb;
  final String? currentFolderId;
  final ValueChanged<String?> onNavigate;
  final bool Function(_ContentItem item, String? folderId) canDrop;
  final Future<void> Function(_ContentItem item, String? folderId) onDrop;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderFor(context).withValues(alpha: 0.5),
          ),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTarget(
              context,
              folderId: null,
              active: currentFolderId == null,
              onTap: currentFolderId == null ? null : () => onNavigate(null),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home, size: 14),
                  SizedBox(width: 4),
                  Text('稿件'),
                ],
              ),
            ),
            for (var index = 0; index < breadcrumb.length; index++) ...[
              Icon(
                Icons.chevron_right,
                size: 14,
                color: AppColors.textDisabledFor(context),
              ),
              _buildTarget(
                context,
                folderId: breadcrumb[index].id,
                active: index == breadcrumb.length - 1,
                onTap: () => onNavigate(breadcrumb[index].id),
                child: Text(breadcrumb[index].name),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTarget(
    BuildContext context, {
    required String? folderId,
    required bool active,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return DragTarget<_ContentItem>(
      onWillAcceptWithDetails: (details) => canDrop(details.data, folderId),
      onAcceptWithDetails: (details) =>
          unawaited(onDrop(details.data, folderId)),
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        final color = active || hovering
            ? AppColors.primary
            : AppColors.textSecondaryFor(context);
        return Material(
          color: hovering
              ? AppColors.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: IconTheme(
                data: IconThemeData(color: color),
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: color,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
