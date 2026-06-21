import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'backend/backend_server.dart';
import 'providers/article_provider.dart';
import 'providers/folder_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/teleprompter_provider.dart';
import 'providers/connection_provider.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';

/// 全局 BackendServer 实例（用于多客户端检测）
late BackendServer globalBackendServer;

/// 飓风提词器 Plus 应用入口
///
/// 启动流程：
/// 1. 初始化后端服务（WebSocket 服务器）
/// 2. 初始化前端连接（连接到本机后端）
/// 3. 启动 Flutter UI
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. 启动后端服务 ──
  globalBackendServer = BackendServer();
  final port = await globalBackendServer.start(); // 自动分配端口

  // ── 2. 创建 Provider ──
  final connectionProvider = ConnectionProvider();
  final articleProvider = ArticleProvider();
  final folderProvider = FolderProvider();
  final settingsProvider = SettingsProvider();
  final teleprompterProvider = TeleprompterProvider();

  // 绑定连接到数据 Provider
  articleProvider.bindConnection(connectionProvider);
  folderProvider.bindConnection(connectionProvider);
  settingsProvider.bindConnection(connectionProvider);
  teleprompterProvider.bindConnection(connectionProvider);

  // ── 3. 连接到本机后端 ──
  await connectionProvider.connectToLocal(port);

  // ── 4. 加载初始数据 ──
  await articleProvider.init();
  await folderProvider.init();
  await settingsProvider.init();

  runApp(
    StormTeleprompterApp(
      backend: globalBackendServer,
      connectionProvider: connectionProvider,
      articleProvider: articleProvider,
      folderProvider: folderProvider,
      settingsProvider: settingsProvider,
      teleprompterProvider: teleprompterProvider,
    ),
  );
}

/// 应用根 Widget
class StormTeleprompterApp extends StatelessWidget {
  final BackendServer backend;
  final ConnectionProvider connectionProvider;
  final ArticleProvider articleProvider;
  final FolderProvider folderProvider;
  final SettingsProvider settingsProvider;
  final TeleprompterProvider teleprompterProvider;

  const StormTeleprompterApp({
    super.key,
    required this.backend,
    required this.connectionProvider,
    required this.articleProvider,
    required this.folderProvider,
    required this.settingsProvider,
    required this.teleprompterProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connectionProvider),
        ChangeNotifierProvider.value(value: articleProvider),
        ChangeNotifierProvider.value(value: folderProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: teleprompterProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final primary = AppColors.primaryFromSettings(
            settingsProvider.settings.uiPrimaryColor,
          );
          final appFont = settingsProvider.settings.appFontFamily;
          return MaterialApp(
            title: '飓风提词器 Plus',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.fromColorAndFont(primary, fontFamily: appFont),
            darkTheme: AppTheme.fromColorAndFont(primary, fontFamily: appFont),
            themeMode: ThemeMode.dark,
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
