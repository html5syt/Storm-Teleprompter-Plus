import 'app_store_base.dart';
import 'app_store_io.dart' if (dart.library.html) 'app_store_web.dart' as impl;

AppStore createAppStore() => impl.createAppStore();
