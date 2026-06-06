import 'dart:convert';

enum TeleprompterMode { manual, auto, voice }

class ScriptDocument {
  const ScriptDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.lastModified,
    this.isTemporary = false,
  });

  final String id;
  final String title;
  final String content;
  final DateTime lastModified;
  final bool isTemporary;

  ScriptDocument copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? lastModified,
    bool? isTemporary,
  }) {
    return ScriptDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      isTemporary: isTemporary ?? this.isTemporary,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'content': content,
    'lastModified': lastModified.millisecondsSinceEpoch,
    'isTemporary': isTemporary,
  };

  factory ScriptDocument.fromJson(Map<String, dynamic> json) {
    return ScriptDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        (json['lastModified'] as num).toInt(),
      ),
      isTemporary: json['isTemporary'] as bool? ?? false,
    );
  }
}

class TeleprompterSettings {
  const TeleprompterSettings({
    required this.fontSize,
    required this.lineHeight,
    required this.paddingX,
    required this.speedWpm,
    required this.readingLineRatio,
    required this.mirrorMode,
    required this.autoScroll,
    required this.voiceFollow,
    required this.showControls,
    required this.customModelUrl,
    required this.customModelMirrorUrl,
  });

  final double fontSize;
  final double lineHeight;
  final double paddingX;
  final double speedWpm;
  final double readingLineRatio;
  final bool mirrorMode;
  final bool autoScroll;
  final bool voiceFollow;
  final bool showControls;
  final String customModelUrl;
  final String customModelMirrorUrl;

  TeleprompterSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? paddingX,
    double? speedWpm,
    double? readingLineRatio,
    bool? mirrorMode,
    bool? autoScroll,
    bool? voiceFollow,
    bool? showControls,
    String? customModelUrl,
    String? customModelMirrorUrl,
  }) {
    return TeleprompterSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paddingX: paddingX ?? this.paddingX,
      speedWpm: speedWpm ?? this.speedWpm,
      readingLineRatio: readingLineRatio ?? this.readingLineRatio,
      mirrorMode: mirrorMode ?? this.mirrorMode,
      autoScroll: autoScroll ?? this.autoScroll,
      voiceFollow: voiceFollow ?? this.voiceFollow,
      showControls: showControls ?? this.showControls,
      customModelUrl: customModelUrl ?? this.customModelUrl,
      customModelMirrorUrl: customModelMirrorUrl ?? this.customModelMirrorUrl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'paddingX': paddingX,
    'speedWpm': speedWpm,
    'readingLineRatio': readingLineRatio,
    'mirrorMode': mirrorMode,
    'autoScroll': autoScroll,
    'voiceFollow': voiceFollow,
    'showControls': showControls,
    'customModelUrl': customModelUrl,
    'customModelMirrorUrl': customModelMirrorUrl,
  };

  factory TeleprompterSettings.fromJson(Map<String, dynamic> json) {
    return TeleprompterSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 56,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      paddingX: (json['paddingX'] as num?)?.toDouble() ?? 24,
      speedWpm: (json['speedWpm'] as num?)?.toDouble() ?? 160,
      readingLineRatio: (json['readingLineRatio'] as num?)?.toDouble() ?? 0.28,
      mirrorMode: json['mirrorMode'] as bool? ?? false,
      autoScroll: json['autoScroll'] as bool? ?? true,
      voiceFollow: json['voiceFollow'] as bool? ?? false,
      showControls: json['showControls'] as bool? ?? true,
      customModelUrl: json['customModelUrl'] as String? ?? '',
      customModelMirrorUrl: json['customModelMirrorUrl'] as String? ?? '',
    );
  }

  static const TeleprompterSettings defaults = TeleprompterSettings(
    fontSize: 56,
    lineHeight: 1.5,
    paddingX: 24,
    speedWpm: 160,
    readingLineRatio: 0.28,
    mirrorMode: false,
    autoScroll: true,
    voiceFollow: false,
    showControls: true,
    customModelUrl: '',
    customModelMirrorUrl: '',
  );
}

class ModelPackage {
  const ModelPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.fileName,
    required this.downloadUrl,
    required this.mirrorUrl,
    required this.recommendedDevice,
    required this.sizeLabel,
  });

  final String id;
  final String name;
  final String description;
  final String fileName;
  final String downloadUrl;
  final String mirrorUrl;
  final String recommendedDevice;
  final String sizeLabel;

  String get resolvedUrl => mirrorUrl.isEmpty ? downloadUrl : mirrorUrl;
}

class AppBundle {
  const AppBundle({
    required this.scripts,
    required this.settings,
    required this.selectedScriptId,
    required this.selectedModelId,
  });

  final List<ScriptDocument> scripts;
  final TeleprompterSettings settings;
  final String? selectedScriptId;
  final String selectedModelId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'scripts': scripts.map((item) => item.toJson()).toList(),
    'settings': settings.toJson(),
    'selectedScriptId': selectedScriptId,
    'selectedModelId': selectedModelId,
  };

  factory AppBundle.fromJson(Map<String, dynamic> json) {
    final scripts = (json['scripts'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => ScriptDocument.fromJson(item as Map<String, dynamic>))
        .toList();
    return AppBundle(
      scripts: scripts,
      settings: TeleprompterSettings.fromJson(
        (json['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      selectedScriptId: json['selectedScriptId'] as String?,
      selectedModelId: json['selectedModelId'] as String? ?? defaultModelId,
    );
  }
}

const String defaultModelId =
    'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20';

const List<ModelPackage> modelCatalog = <ModelPackage>[
  ModelPackage(
    id: 'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20',
    name: 'Bilingual Zipformer Streaming',
    description: '中文和英文双语流式识别，带 ITN 规则示例。',
    fileName:
        'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20.tar.bz2',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20.tar.bz2',
    mirrorUrl:
        'https://hf-mirror.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20.tar.bz2',
    recommendedDevice: '中文提词、双语场景',
    sizeLabel: '约 50 MB',
  ),
  ModelPackage(
    id: 'sherpa-onnx-streaming-zipformer-en-2023-06-26',
    name: 'English Zipformer Streaming',
    description: '英文流式识别模型，适合桌面和中高端设备。',
    fileName: 'sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2',
    mirrorUrl:
        'https://hf-mirror.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2',
    recommendedDevice: '英文提词、桌面端',
    sizeLabel: '约 90 MB',
  ),
  ModelPackage(
    id: 'custom',
    name: '自定义模型',
    description: '填写任意可访问的模型地址，适配自有部署或镜像源。',
    fileName: 'custom-model.tar.bz2',
    downloadUrl: '',
    mirrorUrl: '',
    recommendedDevice: '按需选择',
    sizeLabel: '自定义',
  ),
];

const List<Map<String, String>> demoScriptsSeed = <Map<String, String>>[
  <String, String>{
    'id': 'script-welcome',
    'title': '开场白',
    'content':
        '各位观众大家好，欢迎来到 Storm Teleprompter Plus。\n今天我们用 Flutter 重建一套跨平台提词器。',
  },
  <String, String>{
    'id': 'script-demo',
    'title': '产品介绍',
    'content':
        '<p><strong>Storm Teleprompter Plus</strong> 支持 <em>自动滚动</em>、<u>语音跟随</u> 和 <strong>模型下载</strong>。</p><p>你可以直接编辑稿件，然后一键进入提词模式。</p>',
  },
];

String encodeBundle(AppBundle bundle) => jsonEncode(bundle.toJson());
