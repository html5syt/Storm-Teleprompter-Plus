import 'dart:io';
import 'package:flutter/foundation.dart';

/// Enumerates system font families for font pickers.
class FontService {
  static final FontService _instance = FontService._internal();

  factory FontService() => _instance;

  FontService._internal();

  List<String>? _cachedSystemFonts;

  static const List<String> _fallbackFonts = [
    'Noto Sans SC',
    'Noto Serif SC',
    'Microsoft YaHei',
    'SimHei',
    'SimSun',
    'KaiTi',
    'FangSong',
    'Arial',
    'Courier New',
    'Times New Roman',
    'Georgia',
    'Consolas',
    'Calibri',
    'Segoe UI',
    'Cambria',
    'Tahoma',
    'Verdana',
  ];

  Future<List<String>> getAvailableFonts({bool refresh = false}) async {
    if (!refresh && _cachedSystemFonts != null) return _cachedSystemFonts!;

    try {
      if (Platform.isWindows) {
        _cachedSystemFonts = await _getWindowsFonts();
      } else if (Platform.isMacOS) {
        _cachedSystemFonts = await _getMacOSFonts();
      } else if (Platform.isLinux) {
        _cachedSystemFonts = await _getLinuxFonts();
      } else {
        _cachedSystemFonts = _sortFonts(_fallbackFonts);
      }
    } catch (e) {
      debugPrint('[FontService] Failed to enumerate fonts: $e');
      _cachedSystemFonts = _sortFonts(_fallbackFonts);
    }

    return _cachedSystemFonts!;
  }

  Future<List<String>> _getWindowsFonts() async {
    final fonts = <String>[];

    fonts.addAll(
      await _readWindowsFontRegistry(
        r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
      ),
    );
    fonts.addAll(
      await _readWindowsFontRegistry(
        r'HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
      ),
    );

    final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
    fonts.addAll(await _readFontDirectory(Directory('$windir\\Fonts')));

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      fonts.addAll(
        await _readFontDirectory(
          Directory('$localAppData\\Microsoft\\Windows\\Fonts'),
        ),
      );
    }

    return _sortFonts([..._fallbackFonts, ...fonts]);
  }

  Future<List<String>> _readWindowsFontRegistry(String key) async {
    try {
      final result = await Process.run('reg', ['query', key]);
      if (result.exitCode != 0) return const [];

      final fonts = <String>[];
      final output = (result.stdout as String?) ?? '';
      final linePattern = RegExp(r'^\s+(.+?)\s+REG_\w+\s+.+$');
      for (final line in output.split(RegExp(r'\r?\n'))) {
        final match = linePattern.firstMatch(line);
        if (match == null) continue;
        final family = _cleanFontName(match.group(1)!);
        if (family.isNotEmpty) fonts.add(family);
      }
      return fonts;
    } catch (e) {
      debugPrint('[FontService] Failed to read registry key $key: $e');
      return const [];
    }
  }

  Future<List<String>> _readFontDirectory(Directory directory) async {
    if (!await directory.exists()) return const [];

    final fonts = <String>[];
    const extensions = {'.ttf', '.ttc', '.otf'};
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final lower = name.toLowerCase();
        if (!extensions.any(lower.endsWith)) continue;

        final base = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
        final family = _cleanFontName(base);
        if (family.isNotEmpty) fonts.add(family);
      }
    } catch (e) {
      debugPrint('[FontService] Failed to read ${directory.path}: $e');
    }
    return fonts;
  }

  Future<List<String>> _getMacOSFonts() async {
    try {
      final result = await Process.run('system_profiler', [
        'SPFontsDataType',
        '-detailLevel',
        'minimal',
      ]);
      if (result.exitCode != 0) return _getLinuxFonts();
      final output = result.stdout as String;
      final fonts = <String>[];
      for (final line in output.split('\n')) {
        final match = RegExp(r'^\s+(.+?):$').firstMatch(line);
        if (match == null) continue;
        final name = _cleanFontName(match.group(1)!);
        if (name.isNotEmpty && !name.contains('/')) fonts.add(name);
      }
      return fonts.isEmpty ? _getLinuxFonts() : _sortFonts(fonts);
    } catch (e) {
      debugPrint('[FontService] Failed to enumerate macOS fonts: $e');
      return _sortFonts(_fallbackFonts);
    }
  }

  Future<List<String>> _getLinuxFonts() async {
    try {
      final result = await Process.run('fc-list', [':', 'family', 'sort']);
      if (result.exitCode != 0) return _sortFonts(_fallbackFonts);
      final output = result.stdout as String;
      final fonts = <String>[];
      for (final line in output.split('\n')) {
        for (final family in line.split(',')) {
          final name = _cleanFontName(family);
          if (name.isNotEmpty) fonts.add(name);
        }
      }
      return fonts.isEmpty ? _sortFonts(_fallbackFonts) : _sortFonts(fonts);
    } catch (e) {
      debugPrint('[FontService] Failed to enumerate Linux fonts: $e');
      return _sortFonts(_fallbackFonts);
    }
  }

  Future<List<String>> searchFonts(String query) async {
    final fonts = await getAvailableFonts();
    final lowerQuery = query.trim().toLowerCase();
    if (lowerQuery.isEmpty) return fonts;
    return fonts.where((f) => f.toLowerCase().contains(lowerQuery)).toList();
  }

  List<String> getPresetFonts() => _fallbackFonts;

  String? buildFontFamily(String fontName) {
    if (fontName.isEmpty) return null;
    return fontName;
  }

  static String _cleanFontName(String raw) {
    var name = raw
        .replaceAll(
          RegExp(
            r'\s+\((TrueType|OpenType|Collection)\)$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s+(Regular|Bold|Italic|Oblique|Light|Medium|'
            r'Semibold|SemiBold|DemiBold|Black|Thin|ExtraLight|ExtraBold|'
            r'Condensed|Narrow)$',
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'[-_](Regular|Bold|Italic|Oblique|Light|Medium|'
            r'Semibold|SemiBold|DemiBold|Black|Thin|ExtraLight|ExtraBold|'
            r'Condensed|Narrow)$',
          ),
          '',
        )
        .replaceAll('_', ' ')
        .trim();

    name = name.replaceAll(RegExp(r'\s+'), ' ');
    return name;
  }

  static List<String> _sortFonts(Iterable<String> fonts) {
    final byLowercase = <String, String>{};
    for (final font in fonts) {
      final cleaned = _cleanFontName(font);
      if (cleaned.isEmpty) continue;
      byLowercase.putIfAbsent(cleaned.toLowerCase(), () => cleaned);
    }

    final sorted = byLowercase.values.toList();
    sorted.sort((a, b) {
      final aIndex = _fallbackFonts.indexWhere(
        (f) => f.toLowerCase() == a.toLowerCase(),
      );
      final bIndex = _fallbackFonts.indexWhere(
        (f) => f.toLowerCase() == b.toLowerCase(),
      );
      if (aIndex >= 0 && bIndex >= 0) return aIndex.compareTo(bIndex);
      if (aIndex >= 0) return -1;
      if (bIndex >= 0) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return sorted;
  }
}
