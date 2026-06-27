# 2026-06-27 Home and Editor Interaction Fixes

## Scope

Follow-up fixes for file-management interaction and rich-text editor playback consistency.

## Changes

- Home file manager
  - Small-icon grid height/padding/icon size adjusted to avoid bottom `RenderFlex overflow`.
  - Selection feedback duration reduced and selection is applied on tap-down, so switching from one selected item to another feels immediate.
  - Short hold starts drag; longer stationary hold opens the context menu.
  - Files/folders can be dropped onto folders to move them into that folder.
  - Folder drag prevents moving a folder into itself or its descendants.
  - Home `Focus` now wires `_handleKeyEvent`, enabling arrow-key selection plus `Ctrl+C/X/V`.
  - Keyboard selection follows the current view: grid Up/Down steps by the grid column count; list/details step by one.
  - Copy-pasted article duplicates now land in the current folder.

- Connection info
  - Added `ConnectionProvider.connectionDetailText`.
  - Connection UI now shows mode, status, WebSocket address, client ID, local/remote role, remote client count, and last error when present.

- Rich-text editor
  - Added a stable editor `FocusNode` and `autoFocus` to improve keyboard shortcut handling.
  - Added Quill clipboard paste cleaning for plain-text and rich-text paste.
  - Removes `sourceURL` / `Source URL` lines from pasted content and saved HTML.
  - Formatting actions now reload through a storage-HTML-to-Delta parser that preserves paragraph breaks.
  - Editor background and default text color follow the current teleprompter playback colors.
  - Editor font size and line height are fixed for editing readability and do not follow playback size/spacing.
  - Default unset text color now uses pure white in both editor and playback.
  - Quill inline `color` style is exported, parsed, and rendered in the teleprompter.

## Validation

- `dart format` on touched files: passed.
- `flutter analyze --no-pub`: no errors.
  - Remaining output includes Quill experimental clipboard warnings, one implementation-import info for Quill controller config, and existing project lint/info items.
- `flutter build windows --debug --no-pub`: passed.

## Follow-up Update

- Home file manager
  - Grid marquee selection now starts only after pointer movement passes a small threshold, so holding an item for drag no longer paints a selection rectangle.
  - Item hold behavior now separates short hold drag from longer stationary hold menu. Moving cancels the menu timer and keeps drag behavior.
  - Small-icon grid item height was increased again to avoid compact-mode bottom overflow.

- Rich-text editor
  - Editor font size and line height are fixed for editing comfort and no longer follow teleprompter playback size/spacing.
  - Editor background and default text color still follow the teleprompter playback colors.
  - Formatting tools are compact icon buttons in the same row as the Quill toolbar.
  - Added `Ctrl+Alt+S` quick-start shortcut and exposed it in the quick-start tooltip.
  - Reduced title/editor padding so the editing area has more usable space.

- Teleprompter playback
  - Removed the two legacy top-right jump-to-start/end buttons.
  - Added tooltips to the previous/next buttons around the play button.
  - Added visual-line Up/Down navigation through the text layer, including paused/zero-speed auto mode.
  - Auto scroll speed can now be set to `0`, has no practical upper limit, and Ctrl/Shift increases wheel and Up/Down speed adjustment steps.
  - Added settings controls for custom scroll speed and text side margin.

- Validation
  - `dart format` on touched files: passed.
  - `flutter analyze --no-pub`: no errors; remaining output is warnings/info for Quill experimental APIs, Quill implementation import, and existing lint items.
  - `flutter build windows --debug --no-pub`: passed.

## Layout Regression Fix

- Editor
  - Fixed the editor runtime layout crash by removing the unbounded horizontal scroll wrapper around `QuillSimpleToolbar`.
  - Kept formatting tools and Quill controls on the same row using a bounded `Row` with the Quill toolbar inside `Expanded`.
  - Added `test/editor_page_layout_test.dart` to pump the editor page with Quill localization delegates and catch this class of layout regression.

- Teleprompter speed
  - `SettingsProvider.setWpm` now clamps negative input to `0`.
  - The teleprompter provider now refreshes the active auto-scroll ticker when WPM or scroll mode changes, so speed changes from the settings panel, preset sheet, wheel, or keyboard take effect while playing.
  - Speed `0` no longer locks the text layer scroll physics; it keeps the timer running but behaves like a non-advancing auto mode for navigation.

- Home drag/selection
  - Added an extra guard for item-originated pointer events so grid marquee selection is cancelled even if the parent listener sees the pointer down before the item listener.

- Validation
  - `flutter test test/editor_page_layout_test.dart --no-pub`: passed.
  - `flutter build windows --debug --no-pub`: passed.
  - `flutter analyze --no-pub`: no errors; same remaining warnings/info as above.

## Teleprompter Navigation and Rendering Follow-up

- Speed `0`
  - Mouse wheel now matches Up/Down behavior in auto-play with WPM `0`: it moves by visual display line instead of changing speed.
  - The outer teleprompter wheel handler is disabled while the settings panel is open, so panel scrolling does not adjust teleprompter speed.

- Keyboard navigation
  - Replaced duplicate shortcut handling with a single `Focus.onKeyEvent` path to avoid Up/Down/Left/Right double-triggering or being lost through focus changes.
  - Left arrow at the start/no-current-word state is now a no-op instead of resetting to the `-1` start marker.

- Current-word alignment
  - Removed the default line-snap scroll physics that could pull programmatic current-word alignment onto a nominal line-height grid.
  - Visual-line movement and current-word scrolling now use the actual glyph box center from `TextPainter`, reducing offset with large line spacing, letter spacing, and narrow text widths.

- Rich text consistency
  - Playback parsing now supports `rgb()` / `rgba()` CSS colors exported by Quill, so editor inline text colors render consistently in the teleprompter.
  - Quote normalization now handles straight quotes plus already-curly Chinese single/double quotes and normalizes them into alternating opening/closing pairs.

- End jump
  - Long-press "to end" now sets the final character and also directly animates to the scroll extent as a second guard against stopping midway.

- Validation
  - `flutter test test/editor_page_layout_test.dart test/text_parser_test.dart --no-pub`: passed.
  - `flutter build windows --debug --no-pub`: passed.
  - `flutter analyze --no-pub`: no errors; same remaining warnings/info as above.

## Remote Backend and Font Size Follow-up

- Font size
  - Rich-text inline `font-size` is preserved as an absolute px value and rendered per character in the teleprompter.
  - Added a compact editor font-size input for selected Quill text.
  - Added a teleprompter settings input for arbitrary base body font size.

- Backend lifecycle
  - Connection state now reacts to unexpected WebSocket disconnects.
  - Disconnecting a remote backend can restart and reconnect the bundled local backend.
  - Disconnected state clears article/folder runtime caches and blocks the main file manager/settings entry points.
  - Backend restart no longer disposes the teleprompter session stream or stacks duplicate ping handlers.

- Remote teleprompter behavior
  - Editor quick-start now broadcasts `teleprompter:start_session`, matching the home-page start path.
  - Master teleprompter exit broadcasts `teleprompter:end_session`.
  - Slave clients keep display settings independent while only applying remote WPM updates after session start.
  - Slave clients do not send teleprompter sync messages back to the backend.

- Validation
  - `flutter test test/text_parser_test.dart --no-pub`: passed.
  - `flutter test test/editor_page_layout_test.dart --no-pub`: passed.
  - `flutter build windows --debug --no-pub`: passed.
  - `flutter analyze --no-pub`: no errors; remaining output is the existing Quill experimental warnings, Quill implementation-import info, and project lint/info items.
