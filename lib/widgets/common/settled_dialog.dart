import 'package:flutter/material.dart';

/// 等待对话框退场结束后再返回，避免退场期间的新请求叠加第二个确认框。
Future<T?> showSettledDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}
