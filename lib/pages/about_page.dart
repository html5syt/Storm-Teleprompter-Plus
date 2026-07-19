import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_release_service.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../services/windows_shell_about_service.dart';
import 'log_viewer_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.versionLoader});

  final Future<AppVersionInfo> Function()? versionLoader;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final AppReleaseService _releaseService = AppReleaseService();
  late final Future<AppVersionInfo> _version;
  Timer? _logoTapResetTimer;
  int _logoTapCount = 0;
  Timer? _chineseNameTapResetTimer;
  Timer? _englishNameTapResetTimer;
  int _chineseNameTapCount = 0;
  int _englishNameTapCount = 0;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _version = widget.versionLoader?.call() ?? AppVersionInfo.load();
  }

  @override
  void dispose() {
    _logoTapResetTimer?.cancel();
    _chineseNameTapResetTimer?.cancel();
    _englishNameTapResetTimer?.cancel();
    _releaseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.maybePop(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.backgroundFor(context),
          appBar: AppBar(title: const Text('关于')),
          body: FutureBuilder<AppVersionInfo>(
            future: _version,
            builder: (context, snapshot) {
              final version = snapshot.data?.value ?? '读取中...';
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _handleLogoTap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'lib/favicon.png',
                          width: 112,
                          height: 112,
                          cacheWidth: 224,
                          cacheHeight: 224,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleNameTap(english: false),
                    child: const Text(
                      AppConstants.displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleNameTap(english: true),
                    child: Text(
                      AppConstants.englishName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMutedFor(context),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '版本 $version',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMutedFor(context)),
                  ),
                  const SizedBox(height: 28),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('访问 GitHub 项目主页'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openUrl(githubRepositoryUrl),
                  ),
                  ListTile(
                    leading: _checkingUpdate
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.update),
                    title: const Text('检查更新'),
                    subtitle: Text('当前版本 $version'),
                    onTap: _checkingUpdate || snapshot.data == null
                        ? null
                        : () => _checkForUpdates(snapshot.data!),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('License'),
                    subtitle: const Text('MIT License'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showLicense,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleLogoTap() {
    _logoTapResetTimer?.cancel();
    _logoTapCount++;
    if (_logoTapCount >= 10) {
      _logoTapCount = 0;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LogViewerPage()));
      return;
    }
    _logoTapResetTimer = Timer(
      const Duration(seconds: 3),
      () => _logoTapCount = 0,
    );
  }

  void _handleNameTap({required bool english}) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;

    Timer? currentTimer = english
        ? _englishNameTapResetTimer
        : _chineseNameTapResetTimer;
    currentTimer?.cancel();
    if (english) {
      _englishNameTapCount++;
    } else {
      _chineseNameTapCount++;
    }

    if ((english ? _englishNameTapCount : _chineseNameTapCount) >= 5) {
      if (english) {
        _englishNameTapCount = 0;
      } else {
        _chineseNameTapCount = 0;
      }
      _showNativeAbout(english: english);
      return;
    }

    currentTimer = Timer(const Duration(seconds: 2), () {
      if (english) {
        _englishNameTapCount = 0;
      } else {
        _chineseNameTapCount = 0;
      }
    });
    if (english) {
      _englishNameTapResetTimer = currentTimer;
    } else {
      _chineseNameTapResetTimer = currentTimer;
    }
  }

  void _showNativeAbout({required bool english}) {
    try {
      WindowsShellAboutService.show(
        appName: english ? AppConstants.englishName : AppConstants.displayName,
        description: english
            ? AppConstants.englishAboutDescription
            : AppConstants.chineseAboutDescription,
      );
    } catch (error) {
      debugPrint('[About] 调用 Windows 原生关于对话框失败: $error');
    }
  }

  Future<void> _checkForUpdates(AppVersionInfo current) async {
    setState(() => _checkingUpdate = true);
    try {
      final result = await _releaseService.checkForUpdates(current.value);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(result.hasUpdate ? '发现新版本' : '版本检查完成'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(child: Text(_updateMessage(result))),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
            if (result.hasUpdate || !result.canCompare)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openUrl(result.latestRelease.pageUrl);
                },
                icon: const Icon(Icons.system_update_alt),
                label: Text(result.hasUpdate ? '前往更新' : '查看 Release'),
              ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('检查更新失败：$error');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  String _updateMessage(UpdateCheckResult result) {
    final latest = result.latestRelease;
    final heading = result.hasUpdate
        ? '当前版本：${result.currentVersion}\n最新版本：${latest.tagName}'
        : result.canCompare
        ? '当前已是最新版本：${result.currentVersion}'
        : '当前为开发版本：${result.currentVersion}\n最新发布版本：${latest.tagName}';
    final notes = latest.notes.trim();
    return notes.isEmpty ? heading : '$heading\n\n${latest.name}\n$notes';
  }

  Future<void> _showLicense() async {
    final license = await rootBundle.loadString('LICENSE');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('MIT License'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
          child: SingleChildScrollView(child: SelectableText(license)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String value) async {
    final opened = await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) _showMessage('无法打开链接');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
