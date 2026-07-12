enum ScrollMode {
  /// 自动匀速滚动
  auto,

  /// ASR 语音跟随
  asr,
}

enum AppBrightnessMode { system, light, dark }

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

  /// Sherpa-Onnx worker thread count. Zero selects a device-based default.
  final int asrNumThreads;

  final double asrRule1MinTrailingSilence;
  final double asrRule2MinTrailingSilence;
  final double asrRule3MinUtteranceLength;

  final bool asrUseSystemProxy;

  /// Empty means the operating-system default input device.
  final String asrInputDeviceId;
  final String asrInputDeviceName;

  /// 应用 UI 字体（空字符串使用系统默认）
  final String appFontFamily;

  /// 提词器正文字体（空字符串使用系统默认）
  final String teleprompterFontFamily;

  /// 是否将已读字符变灰
  final bool grayReadChars;

  /// 字体颜色（0 表示自动根据背景色选择黑白）
  final int textColor;

  /// 字间距（像素）
  final double letterSpacing;

  /// 当前字加下划线
  final bool underlineCurrentChar;

  /// 阅读区域框边框粗细（像素）
  final double readingAreaBorderWidth;

  /// 进度条显示 - 已用时间
  final bool progressShowTime;

  /// 进度条显示 - 进度百分比
  final bool progressShowPercentage;

  /// 进度条显示 - 滚动速度（自动模式）
  final bool progressShowSpeed;

  /// 进度条显示 - 当前时间
  final bool progressShowCurrentTime;

  /// 应用亮暗模式（不影响提词器播放页和编辑器页）
  final AppBrightnessMode appBrightnessMode;

  const AppSettings({
    this.fontSize = 64,
    this.lineHeight = 1.5,
    this.scrollMode = ScrollMode.auto,
    this.wpm = 150,
    this.mirrorMode = false,
    this.fullScreenMode = true,
    this.autoHideUI = true,
    this.autoHideDelaySeconds = 3,
    this.asrModelId = '',
    this.asrModelName = '',
    this.uiPrimaryColor = 0xFFDB9D16,
    this.teleprompterBgColor = 0xFF000000,
    this.paddingX = 5.0,
    this.readingLineOffset = 0.5,
    this.highlightCurrentChar = false,
    this.defaultBold = true,
    this.progressInfoSizeRatio = 0.6,
    this.asrMirrorUrl = '',
    this.asrNumThreads = 0,
    this.asrRule1MinTrailingSilence = 2.4,
    this.asrRule2MinTrailingSilence = 1.2,
    this.asrRule3MinUtteranceLength = 20.0,
    this.asrUseSystemProxy = true,
    this.asrInputDeviceId = '',
    this.asrInputDeviceName = '',
    this.appFontFamily = 'Noto Sans SC',
    this.teleprompterFontFamily = 'Noto Sans SC',
    this.grayReadChars = true,
    this.textColor = 0,
    this.letterSpacing = 0.0,
    this.underlineCurrentChar = false,
    this.readingAreaBorderWidth = 3.0,
    this.progressShowTime = true,
    this.progressShowPercentage = true,
    this.progressShowSpeed = true,
    this.progressShowCurrentTime = true,
    this.appBrightnessMode = AppBrightnessMode.dark,
  });

  /// 从 JSON 反序列化
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 64,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      scrollMode: ScrollMode.values.firstWhere(
        (e) => e.name == json['scrollMode'],
        orElse: () => ScrollMode.auto,
      ),
      wpm: json['wpm'] as int? ?? 150,
      mirrorMode: json['mirrorMode'] as bool? ?? false,
      fullScreenMode: json['fullScreenMode'] as bool? ?? true,
      autoHideUI: json['autoHideUI'] as bool? ?? true,
      autoHideDelaySeconds: json['autoHideDelaySeconds'] as int? ?? 3,
      asrModelId: json['asrModelId'] as String? ?? '',
      asrModelName: json['asrModelName'] as String? ?? '',
      uiPrimaryColor: json['uiPrimaryColor'] as int? ?? 0xFFDB9D16,
      teleprompterBgColor: json['teleprompterBgColor'] as int? ?? 0xFF000000,
      paddingX: (json['paddingX'] as num?)?.toDouble() ?? 5.0,
      readingLineOffset: (json['readingLineOffset'] as num?)?.toDouble() ?? 0.5,
      highlightCurrentChar: json['highlightCurrentChar'] as bool? ?? false,
      defaultBold: json['defaultBold'] as bool? ?? true,
      progressInfoSizeRatio:
          (json['progressInfoSizeRatio'] as num?)?.toDouble() ?? 0.6,
      asrMirrorUrl: json['asrMirrorUrl'] as String? ?? '',
      asrNumThreads: (json['asrNumThreads'] as num?)?.toInt() ?? 0,
      asrRule1MinTrailingSilence:
          (json['asrRule1MinTrailingSilence'] as num?)?.toDouble() ?? 2.4,
      asrRule2MinTrailingSilence:
          (json['asrRule2MinTrailingSilence'] as num?)?.toDouble() ?? 1.2,
      asrRule3MinUtteranceLength:
          (json['asrRule3MinUtteranceLength'] as num?)?.toDouble() ?? 20.0,
      asrUseSystemProxy: json['asrUseSystemProxy'] as bool? ?? true,
      asrInputDeviceId: json['asrInputDeviceId'] as String? ?? '',
      asrInputDeviceName: json['asrInputDeviceName'] as String? ?? '',
      appFontFamily: json['appFontFamily'] as String? ?? 'Noto Sans SC',
      teleprompterFontFamily:
          json['teleprompterFontFamily'] as String? ?? 'Noto Sans SC',
      grayReadChars: json['grayReadChars'] as bool? ?? true,
      textColor: json['textColor'] as int? ?? 0,
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.0,
      underlineCurrentChar: json['underlineCurrentChar'] as bool? ?? false,
      readingAreaBorderWidth:
          (json['readingAreaBorderWidth'] as num?)?.toDouble() ?? 3.0,
      progressShowTime: json['progressShowTime'] as bool? ?? true,
      progressShowPercentage: json['progressShowPercentage'] as bool? ?? true,
      progressShowSpeed: json['progressShowSpeed'] as bool? ?? true,
      progressShowCurrentTime: json['progressShowCurrentTime'] as bool? ?? true,
      appBrightnessMode: AppBrightnessMode.values.firstWhere(
        (e) => e.name == json['appBrightnessMode'],
        orElse: () => AppBrightnessMode.dark,
      ),
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
      'asrNumThreads': asrNumThreads,
      'asrRule1MinTrailingSilence': asrRule1MinTrailingSilence,
      'asrRule2MinTrailingSilence': asrRule2MinTrailingSilence,
      'asrRule3MinUtteranceLength': asrRule3MinUtteranceLength,
      'asrUseSystemProxy': asrUseSystemProxy,
      'asrInputDeviceId': asrInputDeviceId,
      'asrInputDeviceName': asrInputDeviceName,
      'appFontFamily': appFontFamily,
      'teleprompterFontFamily': teleprompterFontFamily,
      'grayReadChars': grayReadChars,
      'textColor': textColor,
      'letterSpacing': letterSpacing,
      'underlineCurrentChar': underlineCurrentChar,
      'readingAreaBorderWidth': readingAreaBorderWidth,
      'progressShowTime': progressShowTime,
      'progressShowPercentage': progressShowPercentage,
      'progressShowSpeed': progressShowSpeed,
      'progressShowCurrentTime': progressShowCurrentTime,
      'appBrightnessMode': appBrightnessMode.name,
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
    int? asrNumThreads,
    double? asrRule1MinTrailingSilence,
    double? asrRule2MinTrailingSilence,
    double? asrRule3MinUtteranceLength,
    bool? asrUseSystemProxy,
    String? asrInputDeviceId,
    String? asrInputDeviceName,
    String? appFontFamily,
    String? teleprompterFontFamily,
    bool? grayReadChars,
    int? textColor,
    double? letterSpacing,
    bool? highlightCurrentChar,
    bool? defaultBold,
    bool? underlineCurrentChar,
    double? readingAreaBorderWidth,
    bool? progressShowTime,
    bool? progressShowPercentage,
    bool? progressShowSpeed,
    bool? progressShowCurrentTime,
    AppBrightnessMode? appBrightnessMode,
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
      asrNumThreads: asrNumThreads ?? this.asrNumThreads,
      asrRule1MinTrailingSilence:
          asrRule1MinTrailingSilence ?? this.asrRule1MinTrailingSilence,
      asrRule2MinTrailingSilence:
          asrRule2MinTrailingSilence ?? this.asrRule2MinTrailingSilence,
      asrRule3MinUtteranceLength:
          asrRule3MinUtteranceLength ?? this.asrRule3MinUtteranceLength,
      asrUseSystemProxy: asrUseSystemProxy ?? this.asrUseSystemProxy,
      asrInputDeviceId: asrInputDeviceId ?? this.asrInputDeviceId,
      asrInputDeviceName: asrInputDeviceName ?? this.asrInputDeviceName,
      appFontFamily: appFontFamily ?? this.appFontFamily,
      teleprompterFontFamily:
          teleprompterFontFamily ?? this.teleprompterFontFamily,
      grayReadChars: grayReadChars ?? this.grayReadChars,
      textColor: textColor ?? this.textColor,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      highlightCurrentChar: highlightCurrentChar ?? this.highlightCurrentChar,
      defaultBold: defaultBold ?? this.defaultBold,
      underlineCurrentChar: underlineCurrentChar ?? this.underlineCurrentChar,
      readingAreaBorderWidth:
          readingAreaBorderWidth ?? this.readingAreaBorderWidth,
      progressShowTime: progressShowTime ?? this.progressShowTime,
      progressShowPercentage:
          progressShowPercentage ?? this.progressShowPercentage,
      progressShowSpeed: progressShowSpeed ?? this.progressShowSpeed,
      progressShowCurrentTime:
          progressShowCurrentTime ?? this.progressShowCurrentTime,
      appBrightnessMode: appBrightnessMode ?? this.appBrightnessMode,
    );
  }

  /// 用稿件覆盖设置合并生成新的 AppSettings
  /// 仅覆盖提词器相关字段，全局设置（ASR、主题色等）保持当前值
  AppSettings mergeOverrides(Map<String, dynamic> overrides) {
    if (overrides.isEmpty) return this;
    return AppSettings(
      fontSize: (overrides['fontSize'] as num?)?.toDouble() ?? fontSize,
      lineHeight: (overrides['lineHeight'] as num?)?.toDouble() ?? lineHeight,
      scrollMode: overrides.containsKey('scrollMode')
          ? ScrollMode.values.firstWhere(
              (e) => e.name == overrides['scrollMode'],
              orElse: () => scrollMode,
            )
          : scrollMode,
      wpm: (overrides['wpm'] as num?)?.toInt() ?? wpm,
      mirrorMode: overrides['mirrorMode'] as bool? ?? mirrorMode,
      fullScreenMode: overrides['fullScreenMode'] as bool? ?? fullScreenMode,
      autoHideUI: overrides['autoHideUI'] as bool? ?? autoHideUI,
      autoHideDelaySeconds:
          overrides['autoHideDelaySeconds'] as int? ?? autoHideDelaySeconds,
      paddingX: (overrides['paddingX'] as num?)?.toDouble() ?? paddingX,
      readingLineOffset:
          (overrides['readingLineOffset'] as num?)?.toDouble() ??
          readingLineOffset,
      highlightCurrentChar:
          overrides['highlightCurrentChar'] as bool? ?? highlightCurrentChar,
      defaultBold: overrides['defaultBold'] as bool? ?? defaultBold,
      progressInfoSizeRatio:
          (overrides['progressInfoSizeRatio'] as num?)?.toDouble() ??
          progressInfoSizeRatio,
      teleprompterFontFamily:
          overrides['teleprompterFontFamily'] as String? ??
          teleprompterFontFamily,
      grayReadChars: overrides['grayReadChars'] as bool? ?? grayReadChars,
      textColor: overrides['textColor'] as int? ?? textColor,
      letterSpacing:
          (overrides['letterSpacing'] as num?)?.toDouble() ?? letterSpacing,
      underlineCurrentChar:
          overrides['underlineCurrentChar'] as bool? ?? underlineCurrentChar,
      readingAreaBorderWidth:
          (overrides['readingAreaBorderWidth'] as num?)?.toDouble() ??
          readingAreaBorderWidth,
      teleprompterBgColor:
          overrides['teleprompterBgColor'] as int? ?? teleprompterBgColor,
      // 以下全局设置始终使用当前值，不被稿件覆盖
      asrModelId: asrModelId,
      asrModelName: asrModelName,
      uiPrimaryColor: uiPrimaryColor,
      appFontFamily: appFontFamily,
      asrMirrorUrl: asrMirrorUrl,
      asrNumThreads: asrNumThreads,
      asrRule1MinTrailingSilence: asrRule1MinTrailingSilence,
      asrRule2MinTrailingSilence: asrRule2MinTrailingSilence,
      asrRule3MinUtteranceLength: asrRule3MinUtteranceLength,
      asrUseSystemProxy: asrUseSystemProxy,
      asrInputDeviceId: asrInputDeviceId,
      asrInputDeviceName: asrInputDeviceName,
      progressShowTime:
          overrides['progressShowTime'] as bool? ?? progressShowTime,
      progressShowPercentage:
          overrides['progressShowPercentage'] as bool? ??
          progressShowPercentage,
      progressShowSpeed:
          overrides['progressShowSpeed'] as bool? ?? progressShowSpeed,
      progressShowCurrentTime:
          overrides['progressShowCurrentTime'] as bool? ??
          progressShowCurrentTime,
      appBrightnessMode: appBrightnessMode,
    );
  }

  /// 导出提词器相关设置为 Map（用于保存到稿件）
  Map<String, dynamic> toTeleprompterMap() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'scrollMode': scrollMode.name,
      'wpm': wpm,
      'mirrorMode': mirrorMode,
      'paddingX': paddingX,
      'readingLineOffset': readingLineOffset,
      'highlightCurrentChar': highlightCurrentChar,
      'defaultBold': defaultBold,
      'progressInfoSizeRatio': progressInfoSizeRatio,
      'teleprompterFontFamily': teleprompterFontFamily,
      'grayReadChars': grayReadChars,
      'textColor': textColor,
      'letterSpacing': letterSpacing,
      'teleprompterBgColor': teleprompterBgColor,
      'underlineCurrentChar': underlineCurrentChar,
      'readingAreaBorderWidth': readingAreaBorderWidth,
      'progressShowTime': progressShowTime,
      'progressShowPercentage': progressShowPercentage,
      'progressShowSpeed': progressShowSpeed,
      'progressShowCurrentTime': progressShowCurrentTime,
    };
  }
}
