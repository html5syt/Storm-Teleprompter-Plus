# 2026-06-21 Feature Sync, Editor, Home, Fonts

## Scope

Implemented the second batch of user-reported issues:

- Show the top progress bar when auto mode is paused.
- Keep the teleprompter text layer readable while preserving the recent visual-row centering algorithm.
- Improve home article selection behavior, view switching, large-icon previews, and small-icon mode.
- Start and synchronize remote child teleprompter clients from the local backend owner.
- Introduce a plugin-backed WYSIWYG editor.
- Add HEX input to the main color picker.
- Enumerate/search system fonts from more complete OS sources.

## Changes

- `TeleprompterPage`
  - Top progress bar condition now includes paused auto mode.

- `TeleprompterTextLayer`
  - Extracted repeated text-width calculation into `_textWidthForViewport`.
  - Reused the existing line `TextPainter` creation helper for tap hit testing.
  - Removed a redundant empty-line guard inside the tap handler. Scroll behavior was not changed.

- Home page
  - Replaced the old grid/list/details cycle with `largeIcons -> smallIcons -> list -> details`.
  - Large icon cards show a cleaned article preview.
  - Small icon mode uses compact cells.
  - Empty short click clears selection; Escape/back behavior also clears selection before navigation.
  - Selection animation duration reduced to 90 ms.

- Backend/client teleprompter session sync
  - Added `WsServer.broadcastExcept`.
  - `TeleprompterSession` now broadcasts start/end/sync/settings messages to all other clients.
  - Owner opening a teleprompter sends `teleprompter:start_session` with article ID, current index, play state, and merged teleprompter settings.
  - Remote clients listen for session start, fetch the article by ID, apply session settings, open the teleprompter route, and follow realtime current-index/play-state sync.
  - Remote clients apply sync without running their own auto-scroll ticker, so the master remains authoritative.
  - Master play/pause now syncs state immediately.
  - Settings changes in local/master mode broadcast `teleprompter:settings_update`; remote clients apply without saving or echoing.
  - Remote child clients skip the teleprompter page's article-settings save-on-dispose path.

- Editor
  - Added `flutter_quill`, `dart_quill_delta`, and `flutter_quill_delta_from_html`.
  - WYSIWYG mode is now the default editor surface.
  - Source mode remains available for direct HTML/plain text editing.
  - Existing HTML/plain text imports into Quill Delta; Quill edits save back to the current simple HTML format supported by the teleprompter parser.

- Color picker
  - Main settings color picker now has HEX input.
  - Accepts `#RRGGBB` and `#AARRGGBB`; invalid input is shown inline.

- Fonts
  - `FontService` now reads Windows HKLM/HKCU font registry keys plus system and per-user font directories.
  - macOS/Linux enumeration paths were kept and normalized.
  - Results are cleaned, case-deduplicated, sorted with common fallbacks first, and searchable from the same cache.

## Validation

- `flutter analyze --no-pub`
  - No errors.
  - Remaining output is existing info/warning class issues: curly-brace style, async context lints, unused legacy home handlers, one settings search variable warning, null-aware style suggestions, and `parse_mindmap.dart` print.
- `flutter build windows --debug --no-pub`
  - Passed.
  - Built `build\windows\x64\runner\Debug\storm_teleprompter_plus.exe`.

## Notes

- The remote sync path assumes the master is the local client connected to its own backend. Child clients must be connected in remote-backend mode to that backend.
- The WYSIWYG exporter intentionally keeps to simple inline HTML tags because the existing teleprompter parser supports that subset.
