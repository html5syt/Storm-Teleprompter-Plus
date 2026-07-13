import '../../models/app_backup.dart';

/// Web 平台占位实现；设置页不会在 Web 上展示本地备份入口。
class BackupFileService {
  Future<bool> save(AppBackup backup) async => false;
  Future<AppBackup?> open() async => null;
}
