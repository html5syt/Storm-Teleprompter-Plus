import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._(this._preferences);

  final SharedPreferences _preferences;

  static Future<AppPreferences>? _instance;

  static Future<AppPreferences> getInstance() {
    return _instance ??= SharedPreferences.getInstance().then(AppPreferences._);
  }

  String? getString(String key) => _preferences.getString(key);

  Future<bool> setString(String key, String value) {
    return _preferences.setString(key, value);
  }
}
