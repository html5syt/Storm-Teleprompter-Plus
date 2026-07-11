part of 'home_page.dart';

class _MoveDestination {
  const _MoveDestination({
    required this.folderId,
    required this.label,
    required this.enabled,
  });

  final String? folderId;
  final String label;
  final bool enabled;
}

Future<_MoveDestination?> _showMoveToFolderDialog({
  required BuildContext context,
  required List<_MoveDestination> destinations,
}) {
  return showDialog<_MoveDestination>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('移动到文件夹'),
      content: SizedBox(
        width: 380,
        height: 360,
        child: ListView.builder(
          itemCount: destinations.length,
          itemBuilder: (context, index) {
            final destination = destinations[index];
            return ListTile(
              leading: Icon(
                destination.folderId == null ? Icons.home : Icons.folder,
                size: 20,
                color: destination.enabled ? AppColors.primary : null,
              ),
              title: Text(
                destination.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              enabled: destination.enabled,
              dense: true,
              onTap: destination.enabled
                  ? () => Navigator.pop(dialogContext, destination)
                  : null,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}
