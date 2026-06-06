import 'package:flutter/widgets.dart';

import '../models/app_models.dart';
import '../services/alignment_engine.dart';
import '../services/app_store.dart';
import '../services/app_store_base.dart';
import '../services/script_parser.dart';

class TeleprompterController extends ChangeNotifier {
  TeleprompterController({AppStore? store})
    : _store = store ?? createAppStore();

  final AppStore _store;
  final TeleprompterAlignmentEngine _alignmentEngine =
      TeleprompterAlignmentEngine();

  bool _loaded = false;
  bool _busy = false;
  List<ScriptDocument> _scripts = <ScriptDocument>[];
  TeleprompterSettings _settings = TeleprompterSettings.defaults;
  String? _selectedScriptId;
  String _selectedModelId = defaultModelId;
  TeleprompterMode _mode = TeleprompterMode.manual;
  bool _isPlaying = false;
  int _currentCharIndex = -1;
  int _currentLineIndex = 0;
  String _status = '准备就绪';

  bool get loaded => _loaded;
  bool get busy => _busy;
  List<ScriptDocument> get scripts => List.unmodifiable(_scripts);
  TeleprompterSettings get settings => _settings;
  String? get selectedScriptId => _selectedScriptId;
  String get selectedModelId => _selectedModelId;
  TeleprompterMode get mode => _mode;
  bool get isPlaying => _isPlaying;
  int get currentCharIndex => _currentCharIndex;
  int get currentLineIndex => _currentLineIndex;
  String get status => _status;

  ModelPackage get selectedModelPackage {
    final base = modelCatalog.firstWhere(
      (item) => item.id == _selectedModelId,
      orElse: () => modelCatalog.first,
    );
    if (base.id != 'custom') {
      return base;
    }
    return ModelPackage(
      id: base.id,
      name: base.name,
      description: base.description,
      fileName: base.fileName,
      downloadUrl: _settings.customModelUrl,
      mirrorUrl: _settings.customModelMirrorUrl,
      recommendedDevice: base.recommendedDevice,
      sizeLabel: base.sizeLabel,
    );
  }

  ScriptDocument? get activeScript {
    for (final script in _scripts) {
      if (script.id == _selectedScriptId) {
        return script;
      }
    }
    return _scripts.isEmpty ? null : _scripts.first;
  }

  ParsedScript get parsedActiveScript {
    final script = activeScript;
    if (script == null) {
      return const ParsedScript(lines: <ParsedLine>[], plainText: '');
    }
    return parseScript(
      script.content,
      baseStyle: TextStyle(fontSize: _settings.fontSize),
    );
  }

  Future<void> initialize() async {
    if (_loaded) {
      return;
    }
    _busy = true;
    notifyListeners();

    final loaded = await _store.load();
    if (loaded == null) {
      _scripts = demoScriptsSeed
          .map(
            (item) => ScriptDocument(
              id: item['id']!,
              title: item['title']!,
              content: item['content']!,
              lastModified: DateTime.now(),
              isTemporary: true,
            ),
          )
          .toList();
      _settings = TeleprompterSettings.defaults;
      _selectedScriptId = _scripts.first.id;
      _selectedModelId = defaultModelId;
      await _persist();
    } else {
      _scripts = loaded.scripts;
      _settings = loaded.settings;
      _selectedScriptId =
          loaded.selectedScriptId ??
          (_scripts.isEmpty ? null : _scripts.first.id);
      _selectedModelId = loaded.selectedModelId;
    }

    _alignmentEngine.setScript(activeScript?.content ?? '');
    _loaded = true;
    _busy = false;
    _status = '已加载 ${_scripts.length} 条稿件';
    notifyListeners();
  }

  Future<void> _persist() async {
    await _store.save(
      AppBundle(
        scripts: _scripts,
        settings: _settings,
        selectedScriptId: _selectedScriptId,
        selectedModelId: _selectedModelId,
      ),
    );
  }

  Future<void> selectScript(String id) async {
    _selectedScriptId = id;
    _alignmentEngine.setScript(activeScript?.content ?? '');
    _currentCharIndex = -1;
    _currentLineIndex = 0;
    _status = '已切换稿件';
    await _persist();
    notifyListeners();
  }

  Future<void> upsertScript(ScriptDocument script) async {
    final index = _scripts.indexWhere((item) => item.id == script.id);
    if (index >= 0) {
      _scripts[index] = script;
    } else {
      _scripts = <ScriptDocument>[script, ..._scripts];
      _selectedScriptId = script.id;
    }
    if (_selectedScriptId == script.id) {
      _alignmentEngine.setScript(script.content);
    }
    await _persist();
    notifyListeners();
  }

  Future<ScriptDocument> createScript() async {
    final now = DateTime.now();
    final script = ScriptDocument(
      id: 'script-${now.millisecondsSinceEpoch}',
      title: '未命名稿件',
      content: '在这里输入你的提词稿。',
      lastModified: now,
      isTemporary: true,
    );
    _scripts = <ScriptDocument>[script, ..._scripts];
    _selectedScriptId = script.id;
    _alignmentEngine.setScript(script.content);
    await _persist();
    notifyListeners();
    return script;
  }

  Future<void> deleteScript(String id) async {
    _scripts = _scripts.where((item) => item.id != id).toList();
    if (_selectedScriptId == id) {
      _selectedScriptId = _scripts.isEmpty ? null : _scripts.first.id;
      _alignmentEngine.setScript(activeScript?.content ?? '');
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateScriptContent(String id, String content) async {
    _scripts = _scripts
        .map(
          (item) => item.id == id
              ? item.copyWith(content: content, lastModified: DateTime.now())
              : item,
        )
        .toList();
    if (_selectedScriptId == id) {
      _alignmentEngine.setScript(content);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateScriptTitle(String id, String title) async {
    _scripts = _scripts
        .map(
          (item) => item.id == id
              ? item.copyWith(title: title, lastModified: DateTime.now())
              : item,
        )
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> setSettings(TeleprompterSettings settings) async {
    _settings = settings;
    await _persist();
    notifyListeners();
  }

  Future<void> setCustomModelConfig({String? url, String? mirrorUrl}) async {
    _settings = _settings.copyWith(
      customModelUrl: url ?? _settings.customModelUrl,
      customModelMirrorUrl: mirrorUrl ?? _settings.customModelMirrorUrl,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> setSelectedModel(String modelId) async {
    _selectedModelId = modelId;
    await _persist();
    notifyListeners();
  }

  Future<void> setMode(TeleprompterMode mode) async {
    _mode = mode;
    _status = mode == TeleprompterMode.voice
        ? '语音跟随已准备'
        : mode == TeleprompterMode.auto
        ? '自动滚动中'
        : '手动模式';
    notifyListeners();
  }

  Future<void> setPlaying(bool value) async {
    _isPlaying = value;
    _status = value ? '播放中' : '已暂停';
    notifyListeners();
  }

  void setCurrentIndex(int index) {
    _currentCharIndex = index;
    if (index < 0) {
      _currentLineIndex = 0;
    } else {
      _currentLineIndex = _lineIndexForCharIndex(index);
    }
    notifyListeners();
  }

  void consumeAsrFrame(String text, {required bool isFinal}) {
    final result = _alignmentEngine.consumeTranscript(text, isFinal: isFinal);
    _currentCharIndex = result.index;
    _currentLineIndex = _lineIndexForCharIndex(result.index);
    _status = isFinal ? '识别完成' : '识别中';
    notifyListeners();
  }

  int _lineIndexForCharIndex(int charIndex) {
    if (charIndex < 0) {
      return 0;
    }
    final script = activeScript;
    if (script == null) {
      return 0;
    }
    final parsed = parseScript(script.content);
    var charOffset = 0;
    for (var i = 0; i < parsed.lines.length; i += 1) {
      final line = parsed.lines[i];
      final lineLength = line.text.length;
      if (charIndex < charOffset + lineLength) {
        return i;
      }
      charOffset += lineLength + 1;
    }
    return parsed.lines.isEmpty ? 0 : parsed.lines.length - 1;
  }
}

class AsrFrame {
  const AsrFrame({required this.text, required this.isFinal});

  final String text;
  final bool isFinal;
}
