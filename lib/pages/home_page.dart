import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../backend/ws_protocol.dart';
import '../providers/article_provider.dart';
import '../providers/folder_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/teleprompter_provider.dart';
import '../providers/connection_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/app_exit.dart';
import '../models/article.dart';
import '../models/app_settings.dart';
import '../models/folder.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../main.dart';
import 'teleprompter_page.dart';
import 'editor_page.dart';
import 'settings_page.dart';

part 'home/home_logic.dart';
part 'home/home_breadcrumb_bar.dart';
part 'home/home_move_dialog.dart';
part 'home/home_auxiliary_widgets.dart';
part 'home/home_import_overlay.dart';

enum ViewMode { largeIcons, smallIcons, list, details }

enum SortBy { name, date }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with HomeLogic, WindowListener {
  bool _isClosingWindow = false;

  bool get _isDesktopPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

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

  @override
  void initState() {
    super.initState();
    if (_isDesktopPlatform) {
      unawaited(_initWindowCloseGuard());
    }
  }

  Future<void> _initWindowCloseGuard() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (_isDesktopPlatform) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    if (_isClosingWindow) return;
    final shouldClose = await _confirmLocalBackendShutdown(
      context,
      actionLabel: '关闭服务端',
    );
    if (!shouldClose || !mounted) return;

    await _shutdownAndExitApplication();
  }

  @override
  Future<void> _shutdownAndExitApplication() async {
    if (_isClosingWindow || !mounted) return;
    _isClosingWindow = true;
    final connection = context.read<ConnectionProvider>();
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text('正在退出'),
            content: _ExitProgressContent(onForceExit: forceExitApplication),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await connection.stopLocalAndDisconnect();
    await globalBackendServer.shutdownApplication();
    if (_isDesktopPlatform) {
      await windowManager.destroy();
    } else if (!kIsWeb) {
      await SystemNavigator.pop();
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
            onKeyEvent: _handleKeyEvent,
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
                backgroundColor: AppColors.backgroundFor(context),
                appBar: _buildCommandBar(context, connection),
                body: connection.isLocal && connection.isConnected
                    ? DropTarget(
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
                              Positioned.fill(
                                child: _HomeImportOverlay(
                                  isImporting: _isImporting,
                                  progress: _importProgress,
                                  statusText: _importStatusText,
                                ),
                              ),
                          ],
                        ),
                      )
                    : _buildContentPane(),
                floatingActionButton:
                    connection.isLocal && connection.isConnected
                    ? _buildFabMenu(context, connection)
                    : null,
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
    final isNarrow =
        MediaQuery.sizeOf(context).width < LayoutConstants.compactBreakpoint;

    return AppBar(
      leadingWidth: 120,
      leading: SizedBox(
        width: 120,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: _canGoBack ? _navigateBack : null,
              tooltip: '后退',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18),
              onPressed: _canGoForward ? _navigateForward : null,
              tooltip: '前进',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 18),
              onPressed: _currentFolderId != null ? _navigateUp : null,
              tooltip: '上级',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
      title: isNarrow
          ? null
          : const Text(
              AppConstants.displayName,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
      titleSpacing: 0,
      actions: [
        Consumer<SettingsProvider>(
          builder: (context, settingsProvider, _) {
            final mode = settingsProvider.settings.appBrightnessMode;
            final nextMode = _nextBrightnessMode(mode);
            return IconButton(
              tooltip:
                  '${_brightnessModeLabel(mode)}，点击切换为${_brightnessModeLabel(nextMode)}',
              onPressed: () => settingsProvider.setAppBrightnessMode(nextMode),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween<double>(begin: -0.12, end: 0).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  _brightnessModeIcon(mode),
                  key: ValueKey(mode),
                  size: 20,
                ),
              ),
            );
          },
        ),
        PopupMenuButton<SortBy>(
          icon: const Icon(Icons.sort, size: 20),
          tooltip: '排序',
          onSelected: _toggleSort,
          itemBuilder: (_) => [
            const PopupMenuItem(value: SortBy.name, child: Text('按名称')),
            const PopupMenuItem(value: SortBy.date, child: Text('按日期')),
          ],
        ),
        IconButton(
          icon: Icon(_viewModeIcon, size: 20),
          onPressed: () => setState(() => _viewMode = _nextViewMode),
          tooltip: _viewModeTooltip,
        ),
        PopupMenuButton<String>(
          onOpened: () {
            if (connection.isLocal) unawaited(connection.refreshLocalLanIps());
          },
          icon: Icon(
            connection.isRemote
                ? Icons.cloud_done
                : connection.isConnected
                ? Icons.cloud
                : Icons.cloud_off,
            size: 20,
            color: connection.isConnected
                ? (connection.isRemote ? AppColors.info : AppColors.success)
                : AppColors.textMutedFor(context),
          ),
          tooltip: '服务连接',
          onSelected: (value) async {
            if (value == 'remote') {
              _showRemoteConnectDialog(context, connection);
            } else if (value == 'disconnect') {
              await _disconnectRemoteAndRestoreLocal(connection);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '服务端连接信息',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryFor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      connection.connectionDetailBodyText,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutedFor(context),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'remote', child: Text('连接服务端')),
            if (connection.isRemote)
              const PopupMenuItem(value: 'disconnect', child: Text('断开服务端')),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 20),
          onPressed: connection.isConnected
              ? () => _openSettings(context)
              : null,
          tooltip: '设置',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  IconData _brightnessModeIcon(AppBrightnessMode mode) {
    return switch (mode) {
      AppBrightnessMode.system => Icons.brightness_auto_outlined,
      AppBrightnessMode.light => Icons.light_mode_outlined,
      AppBrightnessMode.dark => Icons.dark_mode_outlined,
    };
  }

  AppBrightnessMode _nextBrightnessMode(AppBrightnessMode mode) {
    return switch (mode) {
      AppBrightnessMode.light => AppBrightnessMode.dark,
      AppBrightnessMode.dark => AppBrightnessMode.system,
      AppBrightnessMode.system => AppBrightnessMode.light,
    };
  }

  String _brightnessModeLabel(AppBrightnessMode mode) {
    return switch (mode) {
      AppBrightnessMode.light => '白天模式',
      AppBrightnessMode.dark => '夜间模式',
      AppBrightnessMode.system => '自动模式',
    };
  }

  Widget _buildBreadcrumbBar() {
    final folderProvider = context.watch<FolderProvider>();
    final breadcrumb = folderProvider.getBreadcrumbFrom(_currentFolderId);
    return _HomeBreadcrumbBar(
      controller: _breadcrumbScrollController,
      breadcrumb: breadcrumb,
      currentFolderId: _currentFolderId,
      onNavigate: _navigateToFolder,
      canDrop: _canDropDraggedItemsOnFolder,
      onDrop: _moveDraggedItemsToFolder,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderFor(context).withValues(alpha: 0.5),
          ),
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
              borderSide: BorderSide(color: AppColors.borderFor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColors.borderFor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            isDense: true,
            fillColor: AppColors.surfaceFor(context),
            filled: true,
          ),
          onChanged: onSearchChanged,
        ),
      ),
    );
  }

  Widget _buildContentPane() {
    return Consumer3<ArticleProvider, FolderProvider, ConnectionProvider>(
      builder: (context, articleProvider, folderProvider, connection, _) {
        if (!connection.isConnected) {
          return _buildDisconnectedPlaceholder(connection);
        }
        if (connection.isRemote) return _buildRemotePlaceholder(connection);

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

        if (sortedFolders.isEmpty && sortedArticles.isEmpty) {
          return _buildEmptyState();
        }

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 80,
              color: AppColors.textMutedFor(context).withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              searchQuery.isNotEmpty ? '没有找到匹配的项目' : '此文件夹为空',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textMutedFor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '点击工具栏新建稿件或文件夹',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textDisabledFor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemotePlaceholder(ConnectionProvider connection) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_done,
              size: 64,
              color: AppColors.info.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              '已连接服务端',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              connection.connectionDetailText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMutedFor(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _disconnectRemoteAndRestoreLocal(connection),
              icon: const Icon(Icons.cloud_off),
              label: const Text('断开服务端'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedPlaceholder(ConnectionProvider connection) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: AppColors.warning.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 16),
            Text(
              '未连接服务端',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              connection.connectionDetailText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMutedFor(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _restoreLocalBackend(connection),
              icon: const Icon(Icons.restart_alt),
              label: const Text('启动本机服务'),
            ),
          ],
        ),
      ),
    );
  }

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
        _lastGridCrossAxisCount = crossAxisCount;
        const padding = 16.0;
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth -
                padding * 2 -
                (crossAxisCount - 1) * spacing) /
            crossAxisCount;
        final itemHeight = compact ? 118.0 : itemWidth * 1.16;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if (_suppressNextGridSelection || _isItemDragActive) {
              _suppressNextGridSelection = false;
              return;
            }
            _selectionPointer = e.pointer;
            _selectionStart = e.localPosition;
            _selectionEnd = e.localPosition;
            _isSelecting = false;
          },
          onPointerMove: (e) {
            if (_suppressNextGridSelection) {
              if (_selectionPointer == e.pointer) {
                setState(_clearGridSelectionGesture);
              }
              return;
            }
            if (_selectionPointer != e.pointer || _selectionStart == null) {
              return;
            }
            if (_isItemDragActive) {
              setState(_clearGridSelectionGesture);
              return;
            }
            final moved = (e.localPosition - _selectionStart!).distance;
            if (!_isSelecting && moved < _selectionDragThreshold) return;
            setState(() {
              _isSelecting = true;
              _selectionEnd = e.localPosition;
            });
          },
          onPointerUp: (e) {
            if (_selectionPointer == e.pointer &&
                _isSelecting &&
                _selectionStart != null &&
                _selectionEnd != null) {
              final rawRect = Rect.fromPoints(_selectionStart!, _selectionEnd!);
              if (rawRect.width > 5 || rawRect.height > 5) {
                final scrollOffset = _gridScrollController.hasClients
                    ? _gridScrollController.offset
                    : 0.0;
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
            if (_selectionPointer == e.pointer) {
              setState(_clearGridSelectionGesture);
            }
          },
          onPointerCancel: (e) {
            if (_selectionPointer == e.pointer) {
              setState(_clearGridSelectionGesture);
            }
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
                itemBuilder: (context, index) => _buildDraggableItem(
                  items[index],
                  _buildItemCard(items[index], compact: compact),
                ),
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

  Widget _buildDraggableItem(_ContentItem item, Widget child) {
    Widget targetChild = child;
    if (item.isFolder) {
      targetChild = DragTarget<_ContentItem>(
        onWillAcceptWithDetails: (details) =>
            _canDropDraggedItemsOnFolder(details.data, item.id),
        onAcceptWithDetails: (details) =>
            _moveDraggedItemsToFolder(details.data, item.id),
        builder: (context, candidateItems, rejectedItems) {
          final hovering = candidateItems.isNotEmpty;
          return AnimatedScale(
            scale: hovering ? 1.025 : 1,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hovering ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: hovering
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.26),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          );
        },
      );
    }

    final tooltipChild = Tooltip(
      message: _itemTooltip(item),
      waitDuration: const Duration(milliseconds: 450),
      child: targetChild,
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _suppressGridSelectionForItem();
        _startItemHoldMenuTimer(item, event.position);
      },
      onPointerMove: (event) => _updateItemHoldPosition(event.position),
      onPointerUp: (_) {
        _cancelItemHoldMenuTimer();
        _suppressNextGridSelection = false;
      },
      onPointerCancel: (_) {
        _cancelItemHoldMenuTimer();
        _suppressNextGridSelection = false;
      },
      child: LongPressDraggable<_ContentItem>(
        data: item,
        delay: const Duration(milliseconds: 260),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedbackOffset: const Offset(14, 14),
        onDragStarted: () => _beginItemDrag(item),
        onDragCompleted: _endItemDrag,
        onDraggableCanceled: (_, _) => _endItemDrag(),
        onDragEnd: (_) => _endItemDrag(),
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevatedFor(
                  context,
                ).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isFolder ? Icons.folder : Icons.article,
                      size: 18,
                      color: item.isFolder
                          ? AppColors.primary
                          : AppColors.textSecondaryFor(context),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _selectedItems.length > 1 &&
                                _selectedItems.contains(item.id)
                            ? '${_selectedItems.length} 个项目'
                            : item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimaryFor(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.32, child: targetChild),
        child: tooltipChild,
      ),
    );
  }

  Widget _buildItemCard(_ContentItem item, {required bool compact}) {
    final isSelected = _selectedItems.contains(item.id);
    return GestureDetector(
      onTapDown: (_) => _selectSingleItem(item),
      onTap: () => _completeItemTap(item),
      onDoubleTap: () => _handleItemDoubleTap(item),
      onSecondaryTapUp: (details) => _showContextMenu(details, item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 35),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(
                  color: AppColors.borderFor(context).withValues(alpha: 0.3),
                ),
        ),
        padding: EdgeInsets.all(compact ? 6 : 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.isFolder ? Icons.folder : Icons.article,
              size: compact ? 28 : 48,
              color: item.isFolder
                  ? AppColors.primary
                  : AppColors.textSecondaryFor(context),
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              item.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textPrimaryFor(context),
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
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.textMutedFor(context),
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
      separatorBuilder: (_, _) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedItems.contains(item.id);
        return _buildDraggableItem(
          item,
          GestureDetector(
            child: Material(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTapDown: (_) => _selectSingleItem(item),
                onTap: () => _completeItemTap(item),
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
                            : AppColors.textSecondaryFor(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimaryFor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.isFolder
                                  ? '文件夹'
                                  : _formatDate(item.updatedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMutedFor(context),
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
          ),
        );
      },
    );
  }

  Widget _buildDetailsView(List<_ContentItem> items) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceFor(context),
            border: Border(
              bottom: BorderSide(
                color: AppColors.borderFor(context).withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '名称',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedFor(context),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  '类型',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedFor(context),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '修改日期',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedFor(context),
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
            separatorBuilder: (_, _) => const SizedBox(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = _selectedItems.contains(item.id);
              return _buildDraggableItem(
                item,
                GestureDetector(
                  child: Material(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      onTapDown: (_) => _selectSingleItem(item),
                      onTap: () => _completeItemTap(item),
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
                                    item.isFolder
                                        ? Icons.folder
                                        : Icons.article,
                                    size: 18,
                                    color: item.isFolder
                                        ? AppColors.primary
                                        : AppColors.textSecondaryFor(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimaryFor(
                                          context,
                                        ),
                                      ),
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMutedFor(context),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _formatDate(item.updatedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMutedFor(context),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildFabMenu(BuildContext context, ConnectionProvider connection) {
    return FloatingActionButton(
      onPressed: () => _showFabMenu(context, connection),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
    );
  }

  @override
  void _showFabMenu(BuildContext context, ConnectionProvider connection) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('导入文件'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_importFilesFromMenu());
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_copy),
                title: const Text('导入文件夹'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_importFoldersFromMenu());
                },
              ),
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
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('导出所选'),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_exportSelectedItems());
                  },
                ),
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
                    unawaited(_pasteItems());
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
      ),
    );
  }

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
            color: AppColors.surfaceFor(context),
            border: Border(
              top: BorderSide(
                color: AppColors.borderFor(context).withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '$total 个项目',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedFor(context),
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
              const SizedBox(width: 8),
              if (folderName.isNotEmpty)
                Expanded(
                  child: Text(
                    '正在查看: $folderName',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabledFor(context),
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        );
      },
    );
  }
}
