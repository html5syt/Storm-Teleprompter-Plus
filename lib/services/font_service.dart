/// 按平台选择系统字体枚举实现。
export 'system/font_service_stub.dart'
    if (dart.library.io) 'system/font_service_io.dart';
