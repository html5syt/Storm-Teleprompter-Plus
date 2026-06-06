import 'package:flutter/material.dart';

/// 飓风提词器色彩系统
///
/// 基于品牌色 #DB9D16 (金色) 构建的深色主题色彩方案。
/// 对应原始项目中的 Tailwind CSS 色彩变量。
class AppColors {
  AppColors._();

  // ─── 品牌色 ───────────────────────────────────────────────
  /// 品牌主色 (金色 #DB9D16)
  static const Color primary = Color(0xFFDB9D16);

  /// 品牌主色较浅变体
  static const Color primaryLight = Color(0xFFF0B840);

  /// 品牌主色较暗变体
  static const Color primaryDark = Color(0xFFB8820E);

  // ─── 背景色 ───────────────────────────────────────────────
  /// 主背景 (最深)
  static const Color background = Color(0xFF0D0D0D);

  /// 卡片/表层背景
  static const Color surface = Color(0xFF141414);

  /// 弹出层/对话框背景
  static const Color surfaceElevated = Color(0xFF1A1A1A);

  /// 提词器专用背景
  static const Color teleprompterBackground = Color(0xFF0A0A0A);

  // ─── 文字色 ───────────────────────────────────────────────
  /// 主文字
  static const Color textPrimary = Color(0xFFF2F2F2);

  /// 次要文字
  static const Color textSecondary = Color(0xFFBDBDBD);

  /// 弱化文字
  static const Color textMuted = Color(0xFF9E9E9E);

  /// 禁用文字
  static const Color textDisabled = Color(0xFF616161);

  // ─── 边框与分割 ──────────────────────────────────────────
  /// 常规边框
  static const Color border = Color(0xFF2E2E2E);

  /// 弱化边框
  static const Color borderLight = Color(0xFF1E1E1E);

  // ─── 语义色 ───────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // ─── 控制面板 ─────────────────────────────────────────────
  /// 控制面板半透明背景
  static const Color controlPanelBg = Color(0xCC141414);

  /// 阅读线指示器颜色
  static const Color readingLine = Color(0x33DB9D16);

  /// ASR 音量计量条颜色
  static const Color rmsMeter = Color(0xFFDB9D16);
}
