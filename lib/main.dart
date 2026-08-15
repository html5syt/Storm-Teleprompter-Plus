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
import 'widgets/common/startup_update_checker.dart';

late BackendServer globalBackendServer;
AppLifecycleListener? appLifecycleListener;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appLog = AppLogService.instance;
  appLog.install();
  await appLog.startSession();
  appLog.info('[Main] Application startup began');

  try {
    await _startApplication(appLog);
  } catch (error, stackTrace) {
    appLog.error(
      '[Main] Application startup failed',
      error: error,
      stackTrace: stackTrace,
    );
    runApp(StartupFailureApp(error: error));
  }
}

Future<void> _startApplication(AppLogService appLog) async {
  if (!kIsWeb) {
    appLog.info('[Main] Configuring system UI');
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    appLog.info('[Main] System UI configured');
  }

  appLog.info('[Main] Creating bundled backend');
  globalBackendServer = BackendServer();
  appLog.info('[Main] Starting bundled backend');
  final port = kIsWeb ? 0 : await globalBackendServer.start(); 
  appLog.info('[Main] Bundled backend ready on port $port');
  if (!kIsWeb) {
    appLifecycleListener = AppLifecycleListener(
      onDetach: () {
        appLog.info('[Main] Application detach requested');
        unawaited(globalBackendServer.shutdownApplication());
      },
    );
  }

  appLog.info('[Main] Creating application providers');
  final connectionProvider = ConnectionProvider();
  final articleProvider = ArticleProvider();
  final folderProvider = FolderProvider();
  final settingsProvider = SettingsProvider();
  final teleprompterProvider = TeleprompterProvider();

  connectionProvider.bindLocalBackend(globalBackendServer);
  articleProvider.bindConnection(connectionProvider);
  folderProvider.bindConnection(connectionProvider);
  settingsProvider.bindConnection(connectionProvider);
  teleprompterProvider.bindConnection(connectionProvider);
  appLog.info('[Main] Application providers ready');

  if (!kIsWeb) {
    appLog.info('[Main] Connecting to bundled backend');
    await connectionProvider.connectToLocal(port);
    appLog.info(
      '[Main] Bundled backend connection completed: '
      '${connectionProvider.isConnected}',
    );
  } else {
    debugPrint('[Main] Web build skips the bundled local backend.');
  }

  appLog.info('[Main] Loading articles');
  await articleProvider.init();
  appLog.info('[Main] Articles loaded');
  appLog.info('[Main] Loading folders');
  await folderProvider.init();
  appLog.info('[Main] Folders loaded');
  appLog.info('[Main] Loading settings');
  await settingsProvider.init();
  appLog.info('[Main] Settings loaded');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    appLog.info('[Main] First Flutter frame rendered');
  });
  appLog.info('[Main] Installing Flutter widget tree');
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
  appLog.info('[Main] Flutter widget tree installed');
}

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
            home: const StartupUpdateChecker(child: HomePage()),
          );
        },
      ),
    );
  }
}

class StartupFailureApp extends StatelessWidget {
  final Object error;

  const StartupFailureApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.displayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 40,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '无法启动本地服务',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text('请检查系统权限后重新打开应用。详细信息已写入启动日志。'),
                    const SizedBox(height: 20),
                    SelectableText(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
