# 2026-06-21 Editor, Import, Search Follow-up

## Scope

Follow-up fixes for the latest user test report:

- Auto mode before start or while paused supports Up/Down line movement.
- Left key at the first visible character no longer jumps to the end.
- Quill editor API errors are resolved against `flutter_quill 11.5.1`.
- Source mode was removed; the editor is Quill-only.
- Editor autosaves and has a quick-start teleprompter button.
- Current-folder search now includes descendant folders.
- External `.txt` and `.docx` files can be dragged onto the home page and imported.

## Changes

- `TeleprompterProvider`
  - `rewind()` clamps to the first visible character when already at the start.

- `TeleprompterPage`
  - Left key from an unselected start state resets to start instead of end.
  - Up/Down uses line navigation unless auto mode is actively playing.
  - When no current character is selected, line navigation starts from line 0.

- `EditorPage` / `EditorLogic`
  - Removed source editor mode and manual save flow.
  - Added Quill-only editing, debounced autosave, save status text, and quick-start teleprompter action.
  - Autosave now rereads title/content on each queued save pass, so typing during an in-flight save is not lost.
  - Failed create/update attempts keep the editor dirty instead of showing a saved state.
  - Root `MaterialApp` now registers `FlutterQuillLocalizations.localizationsDelegates` and `supportedLocales`, fixing `MissingFlutterQuillLocalizationException` from toolbar buttons.
  - Kept formatting tools: remove empty lines, remove paragraph indent, add paragraph indent, normalize quote pairs.
  - Quill exports to the existing simple HTML subset used by the teleprompter parser.

- Home page
  - Search in a folder now scopes results to the current folder plus all descendants.
  - Matching descendant folders are shown alongside matching articles.
  - Added `desktop_drop` integration over the whole home body.
  - Dropped files import into the current folder.

- `ImportService`
  - Added `.txt` import as paragraph HTML.
  - Added `.docx` import using `archive` and `xml`.
  - Preserves compatible inline styles: bold, italic, underline, strike, font size, and highlight/shading background.

## Dependencies

- Added `desktop_drop`.
- Added `xml`.
- Reused existing transitive `archive` package for `.docx` ZIP parsing.

## Validation

- `dart format lib\pages\editor_page.dart lib\pages\home_page.dart lib\pages\home_logic.dart`
  - Passed, no changes after final formatting.
- `flutter analyze --no-pub`
  - No errors.
  - Remaining output is existing info/warning class issues in home/settings/providers/parse_mindmap.
- `flutter build windows --debug --no-pub`
  - Passed.
  - Built `build\windows\x64\runner\Debug\storm_teleprompter_plus.exe`.
