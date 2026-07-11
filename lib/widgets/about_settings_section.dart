import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_release_service.dart';

class AboutSettingsSection extends StatefulWidget {
  const AboutSettingsSection({super.key, this.versionLoader});

  final Future<AppVersionInfo> Function()? versionLoader;

  @override
  State<AboutSettingsSection> createState() => _AboutSettingsSectionState();
}

class _AboutSettingsSectionState extends State<AboutSettingsSection> {
  final AppReleaseService _releaseService = AppReleaseService();
  late final Future<AppVersionInfo> _version;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _version = widget.versionLoader?.call() ?? AppVersionInfo.load();
  }

  @override
  void dispose() {
    _releaseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppVersionInfo>(
      future: _version,
      builder: (context, snapshot) {
        final version = snapshot.data?.value ?? '读取中...';
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('飓风提词器 Plus'),
              subtitle: Text('版本 $version\n基于 Flutter 构建的智能提词器'),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('帮助'),
              subtitle: const Text('打开 GitHub 项目主页'),
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
              onTap: _showLicense,
            ),
          ],
        );
      },
    );
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('检查更新失败：$error')));
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
    final uri = Uri.parse(value);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }
}
