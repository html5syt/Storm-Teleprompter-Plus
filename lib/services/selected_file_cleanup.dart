/// 按平台选择文件选择器临时文件清理实现。
export 'files/selected_file_cleanup_stub.dart'
    if (dart.library.io) 'files/selected_file_cleanup_io.dart';
