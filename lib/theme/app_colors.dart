import 'package:flutter/material.dart';

/// 飓风提词器色彩系统
///
/// 基于品牌色 #DB9D16 (金色) 构建的深色主题色彩方案。
class AppColors {
  AppColors._();

  // ─── 品牌色 ───────────────────────────────────────────────
  static const Color primary = Color(0xFFDB9D16);
  static const Color primaryLight = Color(0xFFF0B840);
  static const Color primaryDark = Color(0xFFB8820E);

  // ─── 背景色 ───────────────────────────────────────────────
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF141414);
  static const Color surfaceElevated = Color(0xFF1A1A1A);
  static const Color teleprompterBackground = Color(0xFF0A0A0A);

  // ─── 文字色 ───────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF2F2F2);
  static const Color textSecondary = Color(0xFFBDBDBD);
  static const Color textMuted = Color(0xFF9E9E9E);
  static const Color textDisabled = Color(0xFF616161);

  // ─── 边框与分割 ──────────────────────────────────────────
  static const Color border = Color(0xFF2E2E2E);
  static const Color borderLight = Color(0xFF1E1E1E);

  // ─── 语义色 ───────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // ─── 控制面板 ─────────────────────────────────────────────
  static const Color controlPanelBg = Color(0xCC141414);
  static const Color readingLine = Color(0x33DB9D16);
  static const Color rmsMeter = Color(0xFFDB9D16);

  // ─── 动态主题色 ───────────────────────────────────────────
  /// 根据用户设置获取主题色
  static Color primaryFromSettings(int hexColor) => Color(hexColor);

  /// 根据用户设置获取提词器背景色
  static Color teleprompterBgFromSettings(int hexColor) => Color(hexColor);

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color backgroundFor(BuildContext context) =>
      isLight(context) ? const Color(0xFFF5F6F8) : background;

  static Color surfaceFor(BuildContext context) =>
      isLight(context) ? const Color(0xFFFFFFFF) : surface;

  static Color surfaceElevatedFor(BuildContext context) =>
      isLight(context) ? const Color(0xFFFFFFFF) : surfaceElevated;

  static Color textPrimaryFor(BuildContext context) =>
      isLight(context) ? const Color(0xFF202124) : textPrimary;

  static Color textSecondaryFor(BuildContext context) =>
      isLight(context) ? const Color(0xFF5F6670) : textSecondary;

  static Color textMutedFor(BuildContext context) =>
      isLight(context) ? const Color(0xFF7A808A) : textMuted;

  static Color textDisabledFor(BuildContext context) =>
      isLight(context) ? const Color(0xFFA5ABB3) : textDisabled;

  static Color borderFor(BuildContext context) =>
      isLight(context) ? const Color(0xFFD7D9DE) : border;

  static Color borderLightFor(BuildContext context) =>
      isLight(context) ? const Color(0xFFE7E9EE) : borderLight;
}
