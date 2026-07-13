import 'dart:io';

/// 立即终止原生进程，仅用于正常退出流程超时后的用户主动强制退出。
Never forceExitApplication() => exit(0);
