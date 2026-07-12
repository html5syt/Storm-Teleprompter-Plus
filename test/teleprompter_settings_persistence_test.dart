import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/models/article.dart';
import 'package:storm_teleprompter_plus/providers/settings_provider.dart';

void main() {
  const expectedKeys = {
    'fontSize',
    'lineHeight',
    'scrollMode',
    'wpm',
    'mirrorMode',
    'paddingX',
    'readingLineOffset',
    'highlightCurrentChar',
    'defaultBold',
    'progressInfoSizeRatio',
    'teleprompterFontFamily',
    'grayReadChars',
    'textColor',
    'letterSpacing',
    'teleprompterBgColor',
    'underlineCurrentChar',
    'readingAreaBorderWidth',
    'progressShowTime',
    'progressShowPercentage',
    'progressShowSpeed',
    'progressShowCurrentTime',
  };

  test('all manuscript teleprompter settings survive map round trip', () {
    final source = const AppSettings().copyWith(
      fontSize: 83,
      lineHeight: 2.1,
      scrollMode: ScrollMode.asr,
      wpm: 237,
      mirrorMode: true,
      paddingX: 17,
      readingLineOffset: 0.63,
      highlightCurrentChar: true,
      defaultBold: false,
      progressInfoSizeRatio: 0.75,
      teleprompterFontFamily: 'Test Font',
      grayReadChars: false,
      textColor: 0xFF123456,
      letterSpacing: 3.5,
      teleprompterBgColor: 0xFF654321,
      underlineCurrentChar: true,
      readingAreaBorderWidth: 5.5,
      progressShowTime: false,
      progressShowPercentage: false,
      progressShowSpeed: false,
      progressShowCurrentTime: false,
    );

    final data = source.toTeleprompterMap();
    final restored = const AppSettings().mergeOverrides(data);

    expect(data.keys.toSet(), expectedKeys);
    expect(restored.toTeleprompterMap(), data);
  });

  test('loading a manuscript creates a complete independent snapshot', () {
    final provider = SettingsProvider();
    addTearDown(provider.dispose);

    provider.loadArticleOverrides({'fontSize': 72});

    expect(provider.articleOverrides.keys.toSet(), expectedKeys);
    expect(provider.articleOverrides['fontSize'], 72);
  });

  test('article JSON export and import retain teleprompter settings', () {
    final now = DateTime(2026, 7, 12);
    final settings = const AppSettings()
        .copyWith(fontSize: 72, paddingX: 12, mirrorMode: true)
        .toTeleprompterMap();
    final article = Article(
      id: 'article-1',
      title: 'Test',
      content: '<p>Content</p>',
      createdAt: now,
      updatedAt: now,
      teleprompterSettings: settings,
    );

    final restored = Article.fromJson(article.toJson());

    expect(restored.teleprompterSettings, settings);
  });
}
