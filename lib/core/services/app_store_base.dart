import '../models/app_models.dart';

abstract class AppStore {
  Future<AppBundle?> load();

  Future<void> save(AppBundle bundle);
}
