# 2026-06-21 Codex 协同记录：正文滚动算法重构

## 任务来源

- 已读取 `notes/chat.json` 的历史对话，确认 Copilot 前序已将正文层改为 `CustomScrollView + SliverList.builder`。
- 已读取 `notes/Storm Teleprompter Plus/content.json` 思维导图，本轮只围绕“提词器页面 / 正文容器 / 大型稿件性能优化 / 阅读区域框 / 输入操作”推进。
- notes 下其他架构文档仅作为背景，未作为本次实现依据。

## 思维导图约束摘录

- 正文容器要支持点击某个字设置为当前字。
- 上下滑动、键盘上下键、鼠标滚轮：未开始时应相对当前字上下移动 n 行；自动滚动开始后用于调速。
- 左右滑动、键盘左右键：移动当前字选择到前后 n 个字。
- 大型稿件性能优化：组件数量懒加载、渲染方法优化、计算方法优化，特别注意计算正确性。
- 阅读区域框默认约屏幕 50%，框住当前字所在整行及上下各 1 行；当前字所处屏幕位置应实时跟随阅读区域框中心行。

## 发现的问题

1. `lib/widgets/teleprompter_text_layer.dart` 原算法使用 `targetLine / (totalLines - 1)` 比例映射滚动位置。该算法不测量实际渲染高度，长行自动换行、富文本字号差异、空行都会导致当前字无法对齐阅读区域框中心行。
2. `TeleprompterProvider.currentIndex` 注释和 UI 使用的是原稿 `rawIndex`，但自动滚动、左右键和进度计算按“可见字符序号”推进。纯文本换行和 HTML 标签会造成高亮、进度、滚动行定位错位。
3. 页面层上下键移动原先通过累计 `line.characters.length` 计算新索引，同样会把可见字符序号误当 rawIndex。
4. 点击定位原先用 `fontSize * 0.6` 粗估字符宽度，长行换行、字体和字间距变化时会点错字。

## 已完成修改

### `lib/widgets/teleprompter_text_layer.dart`

- 保留 `SliverList.builder` 懒加载渲染。
- 用 `TextPainter` 按当前文本宽度和样式缓存每个逻辑行的实际高度，维护 `_lineHeights` 和 `_lineTops`。
- 当前字滚动目标改为按当前字符所在视觉行计算：

  ```text
  targetOffset = topPad + logicalLineTop + currentCharVisualRowCenter - readingLineY
  ```

  `currentCharVisualRowCenter` 由 `TextPainter.getOffsetForCaret` 和 `computeLineMetrics()` 推导，长段落自动换行时不会错误对齐到整个逻辑段落中心。
- 增加基于累计实际高度的二分查找 `_findLineForContentOffset`，用户手动滚动时可反推阅读框中心线所在的逻辑行，再用 `TextPainter.getPositionForOffset` 定位该视觉行上的字符 rawIndex。
- 增加 `onReadingLineChanged` 回调，用户手动滚动后将阅读框中心行同步为当前字。
- 点击定位改为 `TextPainter.getPositionForOffset`，不再用固定字符宽度估算。

### `lib/providers/teleprompter_provider.dart`

- 增加 `_charRawIndices`，建立“可见字符序号 -> 原稿 rawIndex”映射。
- `progress`、自动滚动、前进/后退、重置到结尾均通过该映射运行，`currentIndex` 保持 rawIndex 语义。
- `setCurrentIndex` 会归一化到最近的可见字符 rawIndex，并同步后端。
- 空可见字符稿件不启动播放；自动播放到末尾时同步一次后端状态。

### `lib/pages/teleprompter_page.dart`

- 上下键移动改为使用 `teleprompter.getCharPosition(currentIndex)` 获取真实行号和行内偏移，再跳到目标行的对应 rawIndex。
- 左右键改为调用 provider 的 `forward/rewind/resetToEnd`，避免页面层自行构造错误索引。
- 文本层接入 `onReadingLineChanged`，非自动播放阻塞状态下手动滚动会更新当前字。

## 验证结果

- 已执行 `dart format lib/widgets/teleprompter_text_layer.dart lib/providers/teleprompter_provider.dart lib/pages/teleprompter_page.dart`；视觉行中心补强后又单独格式化了 `lib/widgets/teleprompter_text_layer.dart`。
- 已执行 `flutter analyze --no-pub`：
  - 没有 error。
  - 输出 22 个既有 info/warning，集中在 `home_logic.dart`、`home_page.dart`、`settings_page.dart`、`article_provider.dart`、`folder_provider.dart`、`parse_mindmap.dart`。
  - 本次触及的 `teleprompter_text_layer.dart`、`teleprompter_provider.dart`、`teleprompter_page.dart` 未出现 analyzer 问题。
- 已执行 `flutter build windows --debug --no-pub` 两次，最新一次构建通过，输出 `build/windows/x64/runner/Debug/storm_teleprompter_plus.exe`。

## 后续建议

- 当前仓库没有 `test/` 目录，本轮未添加 widget 测试。若继续增强，可新增针对 rawIndex 映射、纯文本换行、HTML 标签、长行换行的单元/Widget 测试。
- 建议 Copilot 后续不要再恢复比例映射算法；正文滚动定位应以实际渲染高度或可证明等价的布局度量为准。

## 2026-06-21 测试反馈后修正

用户测试反馈：

1. 自动滚动停止状态下无法滚动页面，停止滚动后会滚回开头。
2. 当前字所在行不在阅读框中心，而是在阅读框底部。

修正内容：

- `lib/widgets/teleprompter_text_layer.dart`
  - 手动滚动触发 `onReadingLineChanged` 前，先把 `_lastScrolledToIndex` 设置为该 rawIndex，并递增 `_scrollRequestId`、清理 `_isProgrammaticScroll`。这样由手动滚动同步出来的 `currentIndex` 不会在 `didUpdateWidget` 中再次触发 `_scrollToCurrentChar()`，避免暂停/停止状态下的回弹。
  - 当前字视觉行中心改为优先使用 `TextPainter.getBoxesForSelection()` 取得当前字符所在 selection box，再用 `computeLineMetrics()` 反推该视觉行的 line box 中心；这比仅用 caret offset 更稳定，避免当前行落在阅读框偏下位置。

重新验证：

- 已执行 `dart format lib/widgets/teleprompter_text_layer.dart`。
- 已执行 `flutter analyze --no-pub`，仍无 error；剩余 22 个既有 info/warning 与本次触及文件无关。
- 已执行 `flutter build windows --debug --no-pub`，构建通过。
