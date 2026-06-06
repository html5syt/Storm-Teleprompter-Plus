part of 'home_page.dart';

/// 首页逻辑 mixin
///
/// 包含稿件列表管理、搜索、导航等业务逻辑。
mixin HomeLogic on State<HomePage> {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleProvider>().init();
      context.read<SettingsProvider>().init();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ─── 搜索 ─────────────────────────────────────────────

  void onSearchChanged(String value) {
    setState(() => searchQuery = value);
  }

  void clearSearch() {
    searchController.clear();
    setState(() => searchQuery = '');
  }

  // ─── 过滤文章列表 ─────────────────────────────────────

  List<Article> getFilteredArticles(List<Article> articles) {
    if (searchQuery.isEmpty) return articles;
    return articles
        .where(
          (a) =>
              a.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              a.content.toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();
  }

  // ─── 导航操作 ──────────────────────────────────────────

  /// 打开提词器
  void openTeleprompter(BuildContext context, Article article) {
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
  void editArticle(BuildContext context, Article article) {
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
  void deleteArticle(BuildContext context, Article article) {
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
  void showCreateDialog(BuildContext context) {
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
  void showSettingsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: context.read<SettingsProvider>(),
            ),
          ],
          child: const SettingsPage(),
        ),
      ),
    );
  }

  // ─── 工具 ─────────────────────────────────────────────

  /// 格式化日期
  String formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 根据屏幕宽度决定卡片最大宽度
  double getCardMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return double.infinity; // 手机：单列
    if (width < 900) return 400; // 平板：双列
    return 380; // 桌面：三列
  }
}
