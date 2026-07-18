import 'package:flutter/material.dart';

import '../../pages/about_page.dart';
import '../../services/app_release_service.dart';

/// 设置页中的关于入口，具体信息集中在独立页面展示。
class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key, this.versionLoader});

  final Future<AppVersionInfo> Function()? versionLoader;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('关于飓风提词器 Plus'),
      subtitle: const Text('版本、更新与开源许可'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AboutPage(versionLoader: versionLoader),
        ),
      ),
    );
  }
}
