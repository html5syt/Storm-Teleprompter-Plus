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

  /// 选中模型名称
  final String asrModelName;

  /// 主题色（金色）
  final int uiPrimaryColor;

  /// 提词器背景色
  final int teleprompterBgColor;

  /// 水平边距百分比（0~40，对应原文 paddingX）
  final double paddingX;

  /// 阅读线位置偏移比例（0.0~1.0，默认 0.5 = 居中）
  final double readingLineOffset;

  /// 是否高亮当前字
  final bool highlightCurrentChar;

  /// 正文字体默认加粗
  final bool defaultBold;

  /// 进度条提示字号占正文比例（默认 0.6 = 60%）
  final double progressInfoSizeRatio;

  /// ASR 模型下载镜像 URL（为空则用原始地址）
  final String asrMirrorUrl;

  /// 正文字体（空字符串使用系统默认）
  final String fontFamily;

  /// 是否将已读字符变灰
  final bool grayReadChars;

  /// 字体颜色（0 表示自动根据背景色选择黑白）
  final int textColor;

  /// 字间距（像素）
  final double letterSpacing;

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
    this.uiPrimaryColor = 0xFFDB9D16,
    this.teleprompterBgColor = 0xFF0A0A0A,
    this.paddingX = 5.0,
    this.readingLineOffset = 0.5,
    this.highlightCurrentChar = false,
    this.defaultBold = false,
    this.progressInfoSizeRatio = 0.6,
    this.asrMirrorUrl = '',
    this.fontFamily = 'Noto Sans SC',
    this.grayReadChars = false,
    this.textColor = 0,
    this.letterSpacing = 0.0,
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
      uiPrimaryColor: json['uiPrimaryColor'] as int? ?? 0xFFDB9D16,
      teleprompterBgColor: json['teleprompterBgColor'] as int? ?? 0xFF0A0A0A,
      paddingX: (json['paddingX'] as num?)?.toDouble() ?? 5.0,
      readingLineOffset: (json['readingLineOffset'] as num?)?.toDouble() ?? 0.5,
      highlightCurrentChar: json['highlightCurrentChar'] as bool? ?? false,
      defaultBold: json['defaultBold'] as bool? ?? false,
      progressInfoSizeRatio:
          (json['progressInfoSizeRatio'] as num?)?.toDouble() ?? 0.6,
      asrMirrorUrl: json['asrMirrorUrl'] as String? ?? '',
      fontFamily: json['fontFamily'] as String? ?? 'Noto Sans SC',
      grayReadChars: json['grayReadChars'] as bool? ?? false,
      textColor: json['textColor'] as int? ?? 0,
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.0,
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
      'uiPrimaryColor': uiPrimaryColor,
      'teleprompterBgColor': teleprompterBgColor,
      'paddingX': paddingX,
      'readingLineOffset': readingLineOffset,
      'highlightCurrentChar': highlightCurrentChar,
      'defaultBold': defaultBold,
      'progressInfoSizeRatio': progressInfoSizeRatio,
      'asrMirrorUrl': asrMirrorUrl,
      'fontFamily': fontFamily,
      'grayReadChars': grayReadChars,
      'textColor': textColor,
      'letterSpacing': letterSpacing,
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
    int? uiPrimaryColor,
    int? teleprompterBgColor,
    double? paddingX,
    double? readingLineOffset,
    double? progressInfoSizeRatio,
    String? asrMirrorUrl,
    String? fontFamily,
    bool? grayReadChars,
    int? textColor,
    double? letterSpacing,
    bool? highlightCurrentChar,
    bool? defaultBold,
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
      uiPrimaryColor: uiPrimaryColor ?? this.uiPrimaryColor,
      teleprompterBgColor: teleprompterBgColor ?? this.teleprompterBgColor,
      paddingX: paddingX ?? this.paddingX,
      readingLineOffset: readingLineOffset ?? this.readingLineOffset,
      progressInfoSizeRatio:
          progressInfoSizeRatio ?? this.progressInfoSizeRatio,
      asrMirrorUrl: asrMirrorUrl ?? this.asrMirrorUrl,
      fontFamily: fontFamily ?? this.fontFamily,
      grayReadChars: grayReadChars ?? this.grayReadChars,
      textColor: textColor ?? this.textColor,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      highlightCurrentChar: highlightCurrentChar ?? this.highlightCurrentChar,
      defaultBold: defaultBold ?? this.defaultBold,
    );
  }
}
