import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'backend/backend_server.dart';
import 'models/app_settings.dart';
import 'providers/article_provider.dart';
import 'providers/folder_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/teleprompter_provider.dart';
import 'providers/connection_provider.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'services/system/app_log_service.dart';
import 'utils/constants.dart';

/// 全局 BackendServer 实例（用于多客户端检测）
late BackendServer globalBackendServer;
AppLifecycleListener? appLifecycleListener;

/// 飓风提词器 Plus 应用入口
///
/// 启动流程：
/// 1. 初始化后端服务（WebSocket 服务器）
/// 2. 初始化前端连接（连接到本机后端）
/// 3. 启动 Flutter UI
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogService.instance.install();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  // ── 1. 启动后端服务 ──
  globalBackendServer = BackendServer();
  final port = kIsWeb ? 0 : await globalBackendServer.start(); // 自动分配端口
  if (!kIsWeb) {
    appLifecycleListener = AppLifecycleListener(
      onDetach: () => unawaited(globalBackendServer.shutdownApplication()),
    );
  }

  // ── 2. 创建 Provider ──
  final connectionProvider = ConnectionProvider();
  final articleProvider = ArticleProvider();
  final folderProvider = FolderProvider();
  final settingsProvider = SettingsProvider();
  final teleprompterProvider = TeleprompterProvider();

  // 绑定连接到数据 Provider
  connectionProvider.bindLocalBackend(globalBackendServer);
  articleProvider.bindConnection(connectionProvider);
  folderProvider.bindConnection(connectionProvider);
  settingsProvider.bindConnection(connectionProvider);
  teleprompterProvider.bindConnection(connectionProvider);

  // ── 3. 连接到本机后端 ──
  if (!kIsWeb) {
    await connectionProvider.connectToLocal(port);
  } else {
    debugPrint('[Main] Web build skips the bundled local backend.');
  }

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
          final themeMode =
              switch (settingsProvider.settings.appBrightnessMode) {
                AppBrightnessMode.system => ThemeMode.system,
                AppBrightnessMode.light => ThemeMode.light,
                AppBrightnessMode.dark => ThemeMode.dark,
              };
          return MaterialApp(
            title: AppConstants.displayName,
            debugShowCheckedModeBanner: false,
            localizationsDelegates:
                quill.FlutterQuillLocalizations.localizationsDelegates,
            supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
            darkTheme: AppTheme.fromColorAndFont(primary, fontFamily: appFont),
            theme: AppTheme.lightFromColorAndFont(primary, fontFamily: appFont),
            themeMode: themeMode,
            themeAnimationDuration: const Duration(milliseconds: 260),
            themeAnimationCurve: Curves.easeOutCubic,
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
