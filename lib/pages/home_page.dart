import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/article_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/teleprompter_provider.dart';
import '../models/article.dart';
import '../theme/app_colors.dart';
import 'teleprompter_page.dart';
import 'editor_page.dart';

/// 首页 — 稿件管理
///
/// 展示稿件卡片列表，支持新建、编辑、删除稿件。
/// 对应原始项目的 Home 页面。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 初始化数据加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleProvider>().init();
      context.read<SettingsProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部 AppBar
          _buildAppBar(),
          // 搜索栏
          _buildSearchBar(),
          // 稿件列表
          _buildArticleGrid(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新建稿件'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
      ),
    );
  }

  /// 构建顶部 AppBar
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      snap: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.bolt,
                color: AppColors.background,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '飓风提词器',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => _showSettingsPage(context),
          tooltip: '设置',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索稿件...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
      ),
    );
  }

  /// 构建稿件网格
  Widget _buildArticleGrid() {
    return Consumer<ArticleProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final articles = _searchQuery.isEmpty
            ? provider.articles
            : provider.searchArticles(_searchQuery);

        if (articles.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: AppColors.textMuted.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty ? '还没有稿件' : '没有找到匹配的稿件',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 16,
                    ),
                  ),
                  if (_searchQuery.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '点击右下角按钮创建第一篇稿件',
                      style: TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _getCardMaxWidth(context),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildArticleCard(context, articles[index]),
              childCount: articles.length,
            ),
          ),
        );
      },
    );
  }

  /// 根据屏幕宽度决定卡片最大宽度
  double _getCardMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return double.infinity; // 手机：单列
    if (width < 900) return 400; // 平板：双列
    return 380; // 桌面：三列
  }

  /// 构建稿件卡片
  Widget _buildArticleCard(BuildContext context, Article article) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openTeleprompter(context, article),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 品牌氛围光晕
              Positioned(
                right: -30,
                bottom: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.05),
                  ),
                ),
              ),

              // 主要内容
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 文件图标 + 操作按钮
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.description,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editArticle(context, article);
                            } else if (value == 'delete') {
                              _deleteArticle(context, article);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 12),
                                  Text('编辑'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    '删除',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 标题
                    Text(
                      article.title.isEmpty ? '无标题' : article.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 10),

                    // 正文预览
                    Expanded(
                      child: Text(
                        article.getPreview(maxLength: 100),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.6,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // 底部信息
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(article.updatedAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textDisabled,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '开始提词',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开提词器
  void _openTeleprompter(BuildContext context, Article article) {
    final teleprompterProvider = context.read<TeleprompterProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    teleprompterProvider.loadScript(article.id, article.content);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: teleprompterProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(
              value: context.read<ArticleProvider>(),
            ),
          ],
          child: TeleprompterPage(article: article),
        ),
      ),
    );
  }

  /// 编辑稿件
  void _editArticle(BuildContext context, Article article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: context.read<ArticleProvider>(),
            ),
          ],
          child: EditorPage(article: article),
        ),
      ),
    );
  }

  /// 删除稿件确认
  void _deleteArticle(BuildContext context, Article article) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除稿件'),
        content: Text(
          '确定要删除「${article.title.isEmpty ? "无标题" : article.title}」吗？此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ArticleProvider>().deleteArticle(article.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 新建稿件对话框
  void _showCreateDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: context.read<ArticleProvider>(),
            ),
          ],
          child: const EditorPage(),
        ),
      ),
    );
  }

  /// 打开设置页面
  void _showSettingsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: context.read<SettingsProvider>(),
            ),
          ],
          child: const _SettingsPage(),
        ),
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 设置页面
class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, _) {
          final settings = provider.settings;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 提词器设置分组
              _buildSectionHeader('提词器设置'),
              const SizedBox(height: 12),

              _buildSliderTile(
                context,
                icon: Icons.format_size,
                title: '字体大小',
                value: settings.fontSize,
                min: 24,
                max: 120,
                divisions: 96,
                suffix: 'px',
                onChanged: (v) => provider.setFontSize(v.roundToDouble()),
              ),

              _buildSliderTile(
                context,
                icon: Icons.format_line_spacing,
                title: '行高',
                value: settings.lineHeight,
                min: 1.0,
                max: 2.5,
                divisions: 15,
                suffix: 'x',
                onChanged: (v) =>
                    provider.setLineHeight(double.parse(v.toStringAsFixed(1))),
              ),

              _buildSliderTile(
                context,
                icon: Icons.speed,
                title: '自动滚动速度',
                value: settings.wpm.toDouble(),
                min: 30,
                max: 450,
                divisions: 84,
                suffix: ' 字/分',
                onChanged: (v) => provider.setWpm(v.round()),
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('显示设置'),
              const SizedBox(height: 12),

              // 镜像模式
              SwitchListTile(
                secondary: const Icon(Icons.flip),
                title: const Text('镜像翻转'),
                subtitle: const Text('用于提词器分光镜场景'),
                value: settings.mirrorMode,
                onChanged: (_) => provider.toggleMirrorMode(),
              ),

              // 全屏自动隐藏
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off),
                title: const Text('全屏自动隐藏界面'),
                subtitle: const Text('全屏模式下自动隐藏控制面板'),
                value: settings.autoHideUI,
                onChanged: (_) => provider.toggleAutoHideUI(),
              ),

              if (settings.autoHideUI)
                _buildSliderTile(
                  context,
                  icon: Icons.timer,
                  title: '自动隐藏延迟',
                  value: settings.autoHideDelaySeconds.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  suffix: ' 秒',
                  onChanged: (v) => provider.setAutoHideDelay(v.round()),
                ),

              const SizedBox(height: 24),
              _buildSectionHeader('ASR 语音识别'),
              const SizedBox(height: 12),

              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('语音识别模型'),
                subtitle: Text(
                  settings.asrModelName.isEmpty
                      ? '未选择模型'
                      : settings.asrModelName,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAsrModelSelector(context, provider),
              ),

              const SizedBox(height: 32),

              // 关于
              _buildSectionHeader('关于'),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('飓风提词器 Plus'),
                subtitle: Text('版本 1.0.0\n基于 Flutter 构建的智能提词器'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: '${value.round()}$suffix',
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${value.round()}$suffix',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ASR 模型选择对话框
  void _showAsrModelSelector(BuildContext context, SettingsProvider provider) {
    // TODO: 实现完整的模型选择和下载界面
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择 ASR 模型'),
        content: const Text(
          'ASR 语音识别模型需要在设备端下载后使用。\n\n'
          '支持的模型：\n'
          '• Paraformer 中文 - 适合大多数中文场景\n'
          '• 流式 Paraformer - 实时性更好\n'
          '• Whisper Tiny - 适合低性能设备\n\n'
          '下载支持国内镜像加速。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
