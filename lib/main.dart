import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/article_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/teleprompter_provider.dart';
import 'pages/home_page.dart';

/// 飓风提词器 Plus 应用入口
///
/// 基于 Flutter 框架构建的智能提词器应用。
/// 从原始 React + NestJS 项目完整移植，去除飞书 API 依赖，
/// 使用 sherpa-onnx 原生插件实现本地语音识别。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const StormTeleprompterApp());
}

/// 应用根 Widget
class StormTeleprompterApp extends StatelessWidget {
  const StormTeleprompterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ArticleProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
      ],
      child: MaterialApp(
        title: '飓风提词器 Plus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const HomePage(),
      ),
    );
  }
}
