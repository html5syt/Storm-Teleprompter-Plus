import '../../models/app_backup.dart';

class BackupFileService {
  Future<bool> save(AppBackup backup) async => false;
  Future<AppBackup?> open() async => null;
}
