import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Windows 原生 ShellAboutW 调用封装。
///
/// 图标从当前可执行文件的资源中提取，因此会使用 Windows 标题栏和快捷方式
/// 使用的同一份应用图标。其他平台不会加载或调用 Windows DLL。
class WindowsShellAboutService {
  WindowsShellAboutService._();

  static bool show({required String appName, required String description}) {
    if (!Platform.isWindows) return false;

    final shell32 = DynamicLibrary.open('shell32.dll');
    final user32 = DynamicLibrary.open('user32.dll');
    final extractIcon = shell32
        .lookupFunction<_ExtractIconNative, _ExtractIconDart>('ExtractIconExW');
    final shellAbout = shell32
        .lookupFunction<_ShellAboutNative, _ShellAboutDart>('ShellAboutW');
    final destroyIcon = user32
        .lookupFunction<_DestroyIconNative, _DestroyIconDart>('DestroyIcon');

    final executable = Platform.resolvedExecutable.toNativeUtf16();
    final app = appName.toNativeUtf16();
    final otherStuff = description.toNativeUtf16();
    final largeIcon = calloc<Pointer<Void>>();
    final smallIcon = calloc<Pointer<Void>>();

    try {
      extractIcon(executable, 0, largeIcon, smallIcon, 1);
      final icon = largeIcon.value.address == 0
          ? smallIcon.value
          : largeIcon.value;
      try {
        final result = shellAbout(
          Pointer<Void>.fromAddress(0),
          app,
          otherStuff,
          icon,
        );
        return result != 0;
      } finally {
        if (largeIcon.value.address != 0) destroyIcon(largeIcon.value);
        if (smallIcon.value.address != 0 &&
            smallIcon.value.address != largeIcon.value.address) {
          destroyIcon(smallIcon.value);
        }
      }
    } finally {
      calloc.free(largeIcon);
      calloc.free(smallIcon);
      calloc.free(executable);
      calloc.free(app);
      calloc.free(otherStuff);
    }
  }
}

typedef _ExtractIconNative =
    Int32 Function(
      Pointer<Utf16> fileName,
      Uint32 iconIndex,
      Pointer<Pointer<Void>> largeIcon,
      Pointer<Pointer<Void>> smallIcon,
      Uint32 iconCount,
    );
typedef _ExtractIconDart =
    int Function(
      Pointer<Utf16> fileName,
      int iconIndex,
      Pointer<Pointer<Void>> largeIcon,
      Pointer<Pointer<Void>> smallIcon,
      int iconCount,
    );

typedef _ShellAboutNative =
    Int32 Function(
      Pointer<Void> windowHandle,
      Pointer<Utf16> applicationName,
      Pointer<Utf16> otherStuff,
      Pointer<Void> icon,
    );
typedef _ShellAboutDart =
    int Function(
      Pointer<Void> windowHandle,
      Pointer<Utf16> applicationName,
      Pointer<Utf16> otherStuff,
      Pointer<Void> icon,
    );

typedef _DestroyIconNative = Int32 Function(Pointer<Void> icon);
typedef _DestroyIconDart = int Function(Pointer<Void> icon);
