import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_preferences.dart';
import '../../services/app_release_service.dart';
import '../../utils/constants.dart';

typedef AppVersionLoader = Future<AppVersionInfo> Function();
typedef AppUpdateChecker =
    Future<UpdateCheckResult> Function(String currentVersion);
typedef IgnoredUpdateLoader = Future<String?> Function();
typedef IgnoredUpdateSaver = Future<void> Function(String version);
typedef ReleaseLauncher = Future<void> Function(String url);

/// 首帧后静默检查 GitHub Release，仅在发现未屏蔽的新版本时提示。
class StartupUpdateChecker extends StatefulWidget {
  const StartupUpdateChecker({
    super.key,
    required this.child,
    this.versionLoader,
    this.updateChecker,
    this.ignoredVersionLoader,
    this.ignoredVersionSaver,
    this.releaseLauncher,
  });

  final Widget child;
  final AppVersionLoader? versionLoader;
  final AppUpdateChecker? updateChecker;
  final IgnoredUpdateLoader? ignoredVersionLoader;
  final IgnoredUpdateSaver? ignoredVersionSaver;
  final ReleaseLauncher? releaseLauncher;

  @override
  State<StartupUpdateChecker> createState() => _StartupUpdateCheckerState();
}

class _StartupUpdateCheckerState extends State<StartupUpdateChecker> {
  final AppReleaseService _releaseService = AppReleaseService();
  bool _checkStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_checkForUpdates());
    });
  }

  @override
  void dispose() {
    _releaseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _checkForUpdates() async {
    if (_checkStarted) return;
    _checkStarted = true;
    try {
      final current = await (widget.versionLoader ?? AppVersionInfo.load)();
      if (!current.isRelease) return;

      final result =
          await (widget.updateChecker ?? _releaseService.checkForUpdates)(
            current.value,
          );
      if (!mounted || !result.hasUpdate) return;

      final ignoredVersion =
          await (widget.ignoredVersionLoader ?? _loadIgnoredVersion)();
      if (!mounted || ignoredVersion == result.latestRelease.tagName) return;

      final action = await _showUpdateDialog(result);
      if (!mounted || action == null) return;
      switch (action) {
        case _UpdateAction.ignore:
          await (widget.ignoredVersionSaver ?? _saveIgnoredVersion)(
            result.latestRelease.tagName,
          );
        case _UpdateAction.openRelease:
          await _openRelease(result.latestRelease.pageUrl);
        case _UpdateAction.later:
          break;
      }
    } catch (error) {
      // 启动检查不能干扰应用使用，错误只进入应用日志。
      debugPrint('[StartupUpdate] 检查更新失败: $error');
    }
  }

  Future<_UpdateAction?> _showUpdateDialog(UpdateCheckResult result) {
    final release = result.latestRelease;
    final notes = release.notes.trim();
    return showDialog<_UpdateAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('发现新版本 ${release.tagName}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 380),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前版本：${result.currentVersion}'),
                if (release.name.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    release.name.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText(notes),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _UpdateAction.ignore),
            child: const Text('忽略本次更新'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _UpdateAction.later),
            child: const Text('稍后更新'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(dialogContext, _UpdateAction.openRelease),
            icon: const Icon(Icons.system_update_alt),
            label: const Text('前往更新'),
          ),
        ],
      ),
    );
  }

  Future<String?> _loadIgnoredVersion() async {
    final preferences = await AppPreferences.getInstance();
    return preferences.getString(StorageConstants.ignoredUpdateVersionKey);
  }

  Future<void> _saveIgnoredVersion(String version) async {
    final preferences = await AppPreferences.getInstance();
    await preferences.setString(
      StorageConstants.ignoredUpdateVersionKey,
      version,
    );
  }

  Future<void> _openRelease(String url) async {
    try {
      final launcher = widget.releaseLauncher;
      if (launcher != null) {
        await launcher(url);
        return;
      }
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('无法打开更新页面');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开更新页面：$error')));
    }
  }
}

enum _UpdateAction { ignore, later, openRelease }
