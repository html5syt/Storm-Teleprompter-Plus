import 'dart:convert';

import 'package:web/web.dart' as web;

import '../models/app_models.dart';
import 'app_store_base.dart';

class LocalStorageAppStore implements AppStore {
  LocalStorageAppStore();

  static const String _storageKey = 'storm_teleprompter_plus_data';

  @override
  Future<void> save(AppBundle bundle) async {
    final json = jsonEncode(bundle.toJson());
    web.window.localStorage.setItem(_storageKey, json);
  }

  @override
  Future<AppBundle?> load() async {
    final json = web.window.localStorage.getItem(_storageKey);
    if (json == null) {
      return null;
    }
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return AppBundle.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

AppStore createAppStore() => LocalStorageAppStore();
