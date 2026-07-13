/// 按平台选择局域网地址查询实现。
export 'system/network_info_service_stub.dart'
    if (dart.library.io) 'system/network_info_service_io.dart';
