/// 滚动模式枚举
enum ScrollMode {
  /// 手动滚动
  manual,

  /// 自动匀速滚动
  auto,

  /// ASR 语音跟随
  asr,
}

/// 提词器应用设置
///
/// 管理所有用户可配置的提词器参数。
class AppSettings {
  /// 字体大小（像素）
  final double fontSize;

  /// 行高倍数
  final double lineHeight;

  /// 滚动模式
  final ScrollMode scrollMode;

  /// 自动模式下的每分钟字数 (WPM)
  final int wpm;

  /// 是否启用镜像翻转（用于提词器分光镜）
  final bool mirrorMode;

  /// 是否处于全屏模式
  final bool fullScreenMode;

  /// 全屏时是否自动隐藏界面元素
  final bool autoHideUI;

  /// 全屏模式下自动隐藏的延迟秒数
  final int autoHideDelaySeconds;

  /// ASR 引擎类型标识
  final String asrModelId;

  /// 选中的 ASR 模型名称
  final String asrModelName;

  const AppSettings({
    this.fontSize = 48,
    this.lineHeight = 1.5,
    this.scrollMode = ScrollMode.manual,
    this.wpm = 150,
    this.mirrorMode = false,
    this.fullScreenMode = false,
    this.autoHideUI = true,
    this.autoHideDelaySeconds = 3,
    this.asrModelId = '',
    this.asrModelName = '',
  });

  /// 从 JSON 反序列化
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 48,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      scrollMode: ScrollMode.values.firstWhere(
        (e) => e.name == json['scrollMode'],
        orElse: () => ScrollMode.manual,
      ),
      wpm: json['wpm'] as int? ?? 150,
      mirrorMode: json['mirrorMode'] as bool? ?? false,
      fullScreenMode: json['fullScreenMode'] as bool? ?? false,
      autoHideUI: json['autoHideUI'] as bool? ?? true,
      autoHideDelaySeconds: json['autoHideDelaySeconds'] as int? ?? 3,
      asrModelId: json['asrModelId'] as String? ?? '',
      asrModelName: json['asrModelName'] as String? ?? '',
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'scrollMode': scrollMode.name,
      'wpm': wpm,
      'mirrorMode': mirrorMode,
      'fullScreenMode': fullScreenMode,
      'autoHideUI': autoHideUI,
      'autoHideDelaySeconds': autoHideDelaySeconds,
      'asrModelId': asrModelId,
      'asrModelName': asrModelName,
    };
  }

  /// 创建副本并修改部分字段
  AppSettings copyWith({
    double? fontSize,
    double? lineHeight,
    ScrollMode? scrollMode,
    int? wpm,
    bool? mirrorMode,
    bool? fullScreenMode,
    bool? autoHideUI,
    int? autoHideDelaySeconds,
    String? asrModelId,
    String? asrModelName,
  }) {
    return AppSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      scrollMode: scrollMode ?? this.scrollMode,
      wpm: wpm ?? this.wpm,
      mirrorMode: mirrorMode ?? this.mirrorMode,
      fullScreenMode: fullScreenMode ?? this.fullScreenMode,
      autoHideUI: autoHideUI ?? this.autoHideUI,
      autoHideDelaySeconds: autoHideDelaySeconds ?? this.autoHideDelaySeconds,
      asrModelId: asrModelId ?? this.asrModelId,
      asrModelName: asrModelName ?? this.asrModelName,
    );
  }
}
