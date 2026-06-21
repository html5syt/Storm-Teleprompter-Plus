import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../backend/ws_protocol.dart';
import '../providers/article_provider.dart';
import '../providers/folder_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/teleprompter_provider.dart';
import '../providers/connection_provider.dart';
import '../services/import_service.dart';
import '../models/article.dart';
import '../models/folder.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import 'teleprompter_page.dart';
import 'editor_page.dart';
import 'settings_page.dart';

part 'home_logic.dart';

/// 视图模式
enum ViewMode { largeIcons, smallIcons, list, details }

/// 排序方式
enum SortBy { name, date }

/// 首页 — 资源管理器风格稿件管理
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with HomeLogic {
  IconData get _viewModeIcon {
    switch (_viewMode) {
      case ViewMode.largeIcons:
        return Icons.view_comfy_alt;
      case ViewMode.smallIcons:
        return Icons.grid_view;
      case ViewMode.list:
        return Icons.view_list;
      case ViewMode.details:
        return Icons.table_rows;
    }
  }

  String get _viewModeTooltip {
    switch (_viewMode) {
      case ViewMode.largeIcons:
        return '切换到小图标';
      case ViewMode.smallIcons:
        return '切换到列表';
      case ViewMode.list:
        return '切换到详细信息';
      case ViewMode.details:
        return '切换到大图标';
    }
  }

  ViewMode get _nextViewMode {
    switch (_viewMode) {
      case ViewMode.largeIcons:
        return ViewMode.smallIcons;
      case ViewMode.smallIcons:
        return ViewMode.list;
      case ViewMode.list:
        return ViewMode.details;
      case ViewMode.details:
        return ViewMode.largeIcons;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connection, _) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_selectedItems.isNotEmpty) {
                setState(() => _selectedItems.clear());
              }
            },
          },
          child: Focus(
            autofocus: true,
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                if (_selectedItems.isNotEmpty) {
                  setState(() => _selectedItems.clear());
                } else if (_currentFolderId != null) {
                  _navigateUp();
                } else {
                  await _checkMultiClientBeforeExit(context);
                }
              },
              child: Scaffold(
                appBar: _buildCommandBar(context, connection),
                body: DropTarget(
                  onDragEntered: _handleImportDragEntered,
                  onDragExited: _handleImportDragExited,
                  onDragDone: _handleImportDrop,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _buildBreadcrumbBar(),
                          _buildSearchBar(),
                          Expanded(child: _buildContentPane()),
                          _buildStatusBar(),
                        ],
                      ),
                      if (_isDraggingImport || _isImporting)
                        Positioned.fill(child: _buildImportOverlay()),
                    ],
                  ),
                ),
                floatingActionButton: _buildFabMenu(context, connection),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildCommandBar(
    BuildContext context,
    ConnectionProvider connection,
  ) {
    return AppBar(
      leadingWidth: 120,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: _canGoBack ? _navigateBack : null,
            tooltip: '后退',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 18),
            onPressed: _canGoForward ? _navigateForward : null,
            tooltip: '前进',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            onPressed: _currentFolderId != null ? _navigateUp : null,
            tooltip: '上级',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
      title: const Text(
        '飓风提词器',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      titleSpacing: 0,
      actions: [
        // 排序
        PopupMenuButton<SortBy>(
          icon: const Icon(Icons.sort, size: 20),
          tooltip: '排序',
          onSelected: _toggleSort,
          itemBuilder: (_) => [
            const PopupMenuItem(value: SortBy.name, child: Text('按名称')),
            const PopupMenuItem(value: SortBy.date, child: Text('按日期')),
          ],
        ),
        // 视图切换
        IconButton(
          icon: Icon(_viewModeIcon, size: 20),
          onPressed: () => setState(() => _viewMode = _nextViewMode),
          tooltip: _viewModeTooltip,
        ),
        // 连接状态
        PopupMenuButton<String>(
          icon: Icon(
            connection.isRemote
                ? Icons.cloud_done
                : connection.isConnected
                ? Icons.cloud
                : Icons.cloud_off,
            size: 20,
            color: connection.isConnected
                ? (connection.isRemote ? AppColors.info : AppColors.success)
                : AppColors.textMuted,
          ),
          tooltip: '连接信息',
          onSelected: (value) {
            if (value == 'remote')
              _showRemoteConnectDialog(context, connection);
            else if (value == 'disconnect')
              connection.disconnect();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Text(
                connection.connectionInfoText,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'remote', child: Text('连接到远程后端')),
            if (connection.isRemote)
              const PopupMenuItem(value: 'disconnect', child: Text('断开远程连接')),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 20),
          onPressed: () => _openSettings(context),
          tooltip: '设置',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ─── 面包屑导航栏 ─────────────────────────────────────
  Widget _buildBreadcrumbBar() {
    // 直接使用 _currentFolderId（State 变量）而非 FolderProvider，
    // 因为导航状态由 HomePage 管理，setState 会触发重建
    final folderProvider = context.watch<FolderProvider>();
    final breadcrumb = folderProvider.getBreadcrumbFrom(_currentFolderId);
    final isRoot = _currentFolderId == null;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          // 根目录入口
          GestureDetector(
            onTap: isRoot ? null : () => _navigateToFolder(null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home,
                    size: 14,
                    color: isRoot ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '稿件',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isRoot ? FontWeight.w600 : FontWeight.normal,
                      color: isRoot
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 路径段
          for (int i = 0; i < breadcrumb.length; i++) ...[
            Icon(Icons.chevron_right, size: 14, color: AppColors.textDisabled),
            GestureDetector(
              onTap: () => _navigateToFolder(breadcrumb[i].id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  breadcrumb[i].name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: i == breadcrumb.length - 1
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: i == breadcrumb.length - 1
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 搜索栏 ──────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: SizedBox(
        height: 32,
        child: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: '在当前文件夹中搜索...',
            hintStyle: const TextStyle(fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: clearSearch,
                    padding: EdgeInsets.zero,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            isDense: true,
            fillColor: AppColors.surface,
            filled: true,
          ),
          onChanged: onSearchChanged,
        ),
      ),
    );
  }

  // ─── 内容窗格 ────────────────────────────────────────
  Widget _buildContentPane() {
    return Consumer3<ArticleProvider, FolderProvider, ConnectionProvider>(
      builder: (context, articleProvider, folderProvider, connection, _) {
        if (connection.isRemote) return _buildRemotePlaceholder(connection);

        // 获取当前目录内容
        final currentId = _currentFolderId;
        List<Folder> subFolders;
        List<Article> allArticles;

        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          final descendantFolderIds = _descendantFolderIds(
            currentId,
            folderProvider.folders,
          );
          final articleFolderScope = <String?>{
            currentId,
            ...descendantFolderIds,
          };
          subFolders = folderProvider.folders
              .where(
                (f) =>
                    (currentId == null || descendantFolderIds.contains(f.id)) &&
                    f.name.toLowerCase().contains(query),
              )
              .toList();
          allArticles = articleProvider.articles
              .where(
                (a) =>
                    articleFolderScope.contains(a.folderId) &&
                    (a.title.toLowerCase().contains(query) ||
                        a.content.toLowerCase().contains(query)),
              )
              .toList();
        } else {
          subFolders = folderProvider.folders
              .where((f) => f.parentId == currentId)
              .toList();
          allArticles = articleProvider.articles
              .where((a) => a.folderId == currentId)
              .toList();
        }

        final sortedFolders = _sortFolders(subFolders);
        final sortedArticles = _sortArticles(allArticles);

        if (sortedFolders.isEmpty && sortedArticles.isEmpty)
          return _buildEmptyState();

        final items = <_ContentItem>[
          ...sortedFolders.map((f) => _ContentItem.folder(f)),
          ...sortedArticles.map((a) => _ContentItem.article(a)),
        ];

        if (_viewMode == ViewMode.details) return _buildDetailsView(items);
        if (_viewMode == ViewMode.list) return _buildListView(items);
        return _buildGridView(items, compact: _viewMode == ViewMode.smallIcons);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          Text(
            searchQuery.isNotEmpty ? '没有找到匹配的项目' : '此文件夹为空',
            style: const TextStyle(fontSize: 18, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击工具栏新建稿件或文件夹',
            style: TextStyle(fontSize: 13, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }

  Widget _buildRemotePlaceholder(ConnectionProvider connection) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_done,
            size: 64,
            color: AppColors.info.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          const Text(
            '远程后端模式',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            connection.connectionInfoText,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => connection.disconnect(),
            icon: const Icon(Icons.cloud_off),
            label: const Text('断开连接'),
          ),
        ],
      ),
    );
  }

  // ─── 网格视图 ────────────────────────────────────────
  Widget _buildGridView(List<_ContentItem> items, {required bool compact}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = compact
            ? (constraints.maxWidth / 120).floor().clamp(3, 10)
            : constraints.maxWidth > 1200
            ? 6
            : constraints.maxWidth > 800
            ? 4
            : 3;
        const padding = 16.0;
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth -
                padding * 2 -
                (crossAxisCount - 1) * spacing) /
            crossAxisCount;
        final itemHeight = compact ? 96.0 : itemWidth * 1.16;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            setState(() {
              _isSelecting = true;
              _selectionStart = e.localPosition;
              _selectionEnd = e.localPosition;
            });
          },
          onPointerMove: (e) {
            if (_isSelecting) {
              setState(() {
                _selectionEnd = e.localPosition;
              });
            }
          },
          onPointerUp: (e) {
            if (_isSelecting &&
                _selectionStart != null &&
                _selectionEnd != null) {
              final rawRect = Rect.fromPoints(_selectionStart!, _selectionEnd!);
              if (rawRect.width > 5 || rawRect.height > 5) {
                final scrollOffset = _gridScrollController.hasClients
                    ? _gridScrollController.offset
                    : 0.0;
                // Listener localPosition 是相对于 Stack 的，减去 GridView padding，加上滚动偏移
                final selRect = Rect.fromPoints(
                  _selectionStart! -
                      const Offset(padding, padding) +
                      Offset(0, scrollOffset),
                  _selectionEnd! -
                      const Offset(padding, padding) +
                      Offset(0, scrollOffset),
                );
                final selected = <String>{};
                for (int i = 0; i < items.length; i++) {
                  final row = i ~/ crossAxisCount;
                  final col = i % crossAxisCount;
                  final itemLeft = col * (itemWidth + spacing);
                  final itemTop = row * (itemHeight + spacing);
                  final itemRect = Rect.fromLTWH(
                    itemLeft,
                    itemTop,
                    itemWidth,
                    itemHeight,
                  );
                  if (selRect.overlaps(itemRect)) {
                    selected.add(items[i].id);
                  }
                }
                setState(() {
                  if (HardwareKeyboard.instance.isControlPressed) {
                    _selectedItems.addAll(selected);
                  } else {
                    _selectedItems.clear();
                    _selectedItems.addAll(selected);
                  }
                });
              } else if (!HardwareKeyboard.instance.isControlPressed &&
                  !HardwareKeyboard.instance.isShiftPressed &&
                  _selectedItems.isNotEmpty) {
                setState(() => _selectedItems.clear());
              }
            }
            setState(() {
              _isSelecting = false;
              _selectionStart = null;
              _selectionEnd = null;
            });
          },
          child: Stack(
            children: [
              GridView.builder(
                controller: _gridScrollController,
                padding: const EdgeInsets.all(padding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: itemWidth / itemHeight,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _buildItemCard(items[index], compact: compact),
              ),
              if (_isSelecting &&
                  _selectionStart != null &&
                  _selectionEnd != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SelectionPainter(
                        start: _selectionStart!,
                        end: _selectionEnd!,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemCard(_ContentItem item, {required bool compact}) {
    final isSelected = _selectedItems.contains(item.id);
    return GestureDetector(
      onTap: () => _handleItemTap(item),
      onDoubleTap: () => _handleItemDoubleTap(item),
      onLongPressStart: (details) =>
          _handleItemLongPress(item, details.globalPosition),
      onSecondaryTapUp: (details) => _showContextMenu(details, item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: AppColors.border.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.isFolder ? Icons.folder : Icons.article,
              size: compact ? 32 : 48,
              color: item.isFolder
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              item.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!compact && !item.isFolder && item.article != null) ...[
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  _articlePreview(item.article!),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 列表视图 ────────────────────────────────────────
  String _articlePreview(Article article) {
    final text = article.content
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? '暂无正文预览' : text;
  }

  Widget _buildListView(List<_ContentItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedItems.contains(item.id);
        return GestureDetector(
          onLongPressStart: (details) =>
              _handleItemLongPress(item, details.globalPosition),
          child: Material(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: () => _handleItemTap(item),
              onDoubleTap: () => _handleItemDoubleTap(item),
              onSecondaryTapUp: (details) => _showContextMenu(details, item),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.isFolder ? Icons.folder : Icons.article,
                      size: 20,
                      color: item.isFolder
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.isFolder ? '文件夹' : _formatDate(item.updatedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── 详细信息视图 ────────────────────────────────────
  Widget _buildDetailsView(List<_ContentItem> items) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                flex: 3,
                child: Text(
                  '名称',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const Expanded(
                flex: 1,
                child: Text(
                  '类型',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  '修改日期',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = _selectedItems.contains(item.id);
              return GestureDetector(
                onLongPressStart: (details) =>
                    _handleItemLongPress(item, details.globalPosition),
                child: Material(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    onTap: () => _handleItemTap(item),
                    onDoubleTap: () => _handleItemDoubleTap(item),
                    onSecondaryTapUp: (details) =>
                        _showContextMenu(details, item),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Icon(
                                  item.isFolder ? Icons.folder : Icons.article,
                                  size: 18,
                                  color: item.isFolder
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              item.isFolder ? '文件夹' : '稿件',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatDate(item.updatedAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── FAB 菜单 ────────────────────────────────────────
  Widget _buildFabMenu(BuildContext context, ConnectionProvider connection) {
    return FloatingActionButton(
      onPressed: () => _showFabMenu(context, connection),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.background,
      child: const Icon(Icons.add),
    );
  }

  void _showFabMenu(BuildContext context, ConnectionProvider connection) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!connection.isRemote) ...[
              ListTile(
                leading: const Icon(Icons.note_add),
                title: const Text('新建稿件'),
                onTap: () {
                  Navigator.pop(ctx);
                  _createArticle(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text('新建文件夹'),
                onTap: () {
                  Navigator.pop(ctx);
                  _createFolderDialog(context);
                },
              ),
            ],
            if (_selectedItems.isNotEmpty) ...[
              const Divider(),
              if (_selectedItems.length == 1)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('重命名'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _renameSelected();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text(
                  '删除',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteSelected();
                },
              ),
            ],
            if (_clipboard.isNotEmpty) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.content_paste),
                title: const Text('粘贴'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pasteItems();
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('取消'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 状态栏 ──────────────────────────────────────────
  Widget _buildStatusBar() {
    return Consumer3<ArticleProvider, FolderProvider, ConnectionProvider>(
      builder: (context, articleProvider, folderProvider, connection, _) {
        final currentId = _currentFolderId;
        final fCount = folderProvider.folders
            .where((f) => f.parentId == currentId)
            .length;
        final aCount = articleProvider.articles
            .where((a) => a.folderId == currentId)
            .length;
        final total = fCount + aCount;
        final selected = _selectedItems.length;
        final folderName = currentId != null
            ? (folderProvider.getFolderById(currentId)?.name ?? '')
            : '';

        return Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              Text(
                '$total 个项目',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              if (selected > 0) ...[
                const SizedBox(width: 16),
                Text(
                  '已选 $selected 项',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ],
              const Spacer(),
              if (folderName.isNotEmpty)
                Text(
                  '正在查看: $folderName',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 框选矩形绘制器
class _SelectionPainter extends CustomPainter {
  final Offset start;
  final Offset end;

  _SelectionPainter({required this.start, required this.end});

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
