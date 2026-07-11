# 飓风提词器 — 技术实现报告

> 本文档详细解析飓风提词器的全部技术实现细节，包括系统架构、核心算法、UI 设计、功能实现等，供开发团队和 AI 智能体学习参考。

---

## 目录

- [1. 系统概览](#1-系统概览)
- [2. 技术栈](#2-技术栈)
- [3. 项目结构](#3-项目结构)
- [4. 路由与页面架构](#4-路由与页面架构)
- [5. 核心算法：对齐引擎](#5-核心算法对齐引擎)
- [6. 提词器主视图](#6-提词器主视图)
- [7. 文本渲染层](#7-文本渲染层)
- [8. ASR 语音识别架构](#8-asr-语音识别架构)
- [9. 飞书代理后端](#9-飞书代理后端)
- [10. UI 设计与主题系统](#10-ui-设计与主题系统)
- [11. 稿件管理](#11-稿件管理)
- [12. AI 优化能力](#12-ai-优化能力)
- [13. 数据库模型](#13-数据库模型)
- [14. 性能优化策略](#14-性能优化策略)
- [15. 边界情况与容错](#15-边界情况与容错)
- [16. 核心调用链路](#16-核心调用链路)

---

## 1. 系统概览

飓风提词器是一个**基于 React + NestJS 的全栈应用**，核心功能是**跟随语音自动对齐滚动的提词器**。主播朗读稿件时，系统通过语音识别（ASR）实时捕捉朗读内容，与原文稿进行字符级对齐，自动滚动文本使当前朗读行始终停留在固定阅读线位置。

### 核心特性

| 特性 | 说明 |
|------|------|
| **语音跟随** | 支持本地 Sherpa-Onnx ASR 和飞书云 ASR 双引擎 |
| **流式对齐** | 双指针字符级匹配，3 字双向跳字容错 |
| **三种模式** | 手动滚动 / 自动匀速滚动 / 语音跟随 |
| **富文本支持** | 保留粗体、斜体、下划线、删除线、自定义字号 |
| **镜像翻转** | 支持提词器分光镜场景的水平翻转 |
| **响应式设计** | 自动适配移动端和桌面端 |
| **AI 优化** | 流式 AI 优化正文，实时预览 |
| **混合存储** | 云端持久化 + 浏览器本地临时稿件 |

---

## 2. 技术栈

### 前端

| 技术 | 版本 | 用途 |
|------|------|------|
| React | 19 | UI 框架 |
| TypeScript | - | 类型安全 |
| React Router DOM | v6 | 路由管理 |
| Tailwind CSS | v4 | 样式系统 |
| styled-jsx | - | 复杂 CSS/动画 |
| shadcn/ui | - | UI 组件库 |
| Framer Motion | - | 动画与可见性检测 |
| Lucide React | - | 图标库 |
| dayjs | - | 日期处理 |
| Tiptap | - | 富文本编辑器 |
| Sherpa-Onnx | - | 本地 ASR 引擎（WASM） |

### 后端

| 技术 | 版本 | 用途 |
|------|------|------|
| NestJS | 10.x | 后端框架 |
| Drizzle ORM | - | 数据库操作 |
| PostgreSQL | - | 关系型数据库 |
| @nestjs/axios | - | HTTP 客户端 |

### 构建工具

| 工具 | 用途 |
|------|------|
| Rspack | 前端构建 |
| NestJS CLI | 后端开发 |

---

## 3. 项目结构

```
├── client/src/
│   ├── api/                          # API 接口层
│   ├── components/
│   │   ├── teleprompter/             # 提词器核心组件
│   │   │   ├── TeleprompterView.tsx  # 提词器主视图
│   │   │   ├── TeleprompterTextLayer.tsx  # 文本渲染层
│   │   │   ├── ScriptEditor.tsx      # 脚本编辑器
│   │   │   ├── GlobalSettingsDialog.tsx  # 全局设置对话框
│   │   │   ├── LatencyPanel.tsx      # ASR 延迟统计面板
│   │   │   └── types.ts              # 组件类型定义
│   │   ├── business-ui/              # 业务通用组件
│   │   ├── ui/                       # shadcn/ui 基础组件
│   │   └── Layout.tsx                # 全局布局
│   ├── hooks/                        # 自定义 React Hooks
│   ├── lib/teleprompter/             # 提词器核心逻辑库
│   │   ├── alignment/
│   │   │   ├── engine.ts             # 对齐引擎核心算法
│   │   │   └── index.ts              # 单例导出
│   │   ├── asr-client.ts             # ASR 客户端接口定义
│   │   ├── sherpa-asr-client.ts      # Sherpa-Onnx 本地 ASR 实现
│   │   └── temp-script-store.ts      # 浏览器临时稿件存储
│   ├── pages/
│   │   ├── Home/
│   │   │   ├── Home.tsx              # 首页主容器
│   │   │   ├── ArticleCardList.tsx   # 稿件卡片列表
│   │   │   ├── ArticleCreateDialog.tsx  # 新建稿件弹窗
│   │   │   ├── ArticleEditDialog.tsx    # 编辑稿件弹窗
│   │   │   └── ArticleDeleteDialog.tsx  # 删除确认弹窗
│   │   ├── ScriptEditor/
│   │   │   └── ScriptEditorPage.tsx  # 脚本编辑器页面
│   │   └── NotFound/
│   │       └── NotFound.tsx          # 404 页面
│   ├── types/                        # 通用类型定义
│   ├── utils/                        # 工具函数
│   ├── app.tsx                       # 路由配置
│   ├── index.tsx                     # 应用入口
│   ├── tailwind-theme.css            # Tailwind 主题变量
│   └── index.css                     # 全局样式
├── server/
│   ├── modules/
│   │   ├── article/                  # 稿件 CRUD 模块
│   │   ├── feishu-proxy/             # 飞书 API 代理模块
│   │   ├── system-settings/          # 系统设置模块
│   │   └── view/                     # 视图渲染模块
│   ├── database/
│   │   └── schema.ts                 # Drizzle ORM 表结构
│   └── capabilities/                 # 插件实例配置
└── shared/
    └── api.interface.ts              # 前后端共享类型
```

---

## 4. 路由与页面架构

### 路由配置

```tsx
// client/src/app.tsx
const RoutesComponent = () => {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Home />} />
      </Route>
      <Route path="/editor/:id" element={<ScriptEditorPage />} />
      <Route path="*" element={<NotFound />} />
    </Routes>
  );
};
```

| 路由 | 组件 | 说明 |
|------|------|------|
| `/` | Home | 首页（稿件列表 + 提词器） |
| `/editor/:id` | ScriptEditorPage | 脚本编辑器 |
| `*` | NotFound | 404 页面 |

### 首页视图预挂载架构

首页采用**同时挂载 + CSS 显隐切换**策略，而非条件渲染：

```tsx
// Home.tsx
{activeScriptId && (
  <div className={view === 'prompter' ? 'block' : 'hidden'}>
    <TeleprompterView script={activeScript} ... />
  </div>
)}

<div className={view === 'manager' ? '...' : 'hidden'}>
  {/* 稿件列表 */}
</div>
```

**优势**：
- 切换到提词器视图时无需重新挂载组件
- 避免重复初始化 ASR、对齐引擎等重型资源
- 进入提词器的延迟从 ~500ms 降至 ~50ms

### 初始化副作用拆分

首页拆分为 5 个独立 `useEffect`，避免相互阻塞：

| 副作用 | 职责 | 触发时机 |
|--------|------|----------|
| 滚动监听 | 更新 header 透明度 | 滚动事件 |
| 临时脚本订阅 | 订阅本地存储变化 | 挂载一次 |
| ASR 预热 | `preloadSherpaAsr()` | 挂载一次，后台执行 |
| 加载应用设置 | `getGlobalSettings()` | 挂载一次 |
| 加载稿件 | `listArticles()` | 挂载一次 |

---

## 5. 核心算法：对齐引擎

对齐引擎是提词器语音跟随的核心算法，位于 `client/src/lib/teleprompter/alignment/engine.ts`。

### 5.1 设计目标

将流式 ASR 识别结果与原稿文本进行**字符级对齐**，支持 ASR 吞字和幻觉容错，确保正确定位当前朗读位置。

### 5.2 双指针算法

```
anchorIndex    → 已确认匹配完成的最后位置（稳定锚点）
currentIndex   → 当前最佳匹配位置（实时游标）
```

**核心规则**：
- 非 final 结果：始终从 `anchorIndex` 重算，不移动锚点
- final 结果：提交锚点 `anchorIndex = currentIndex`
- 游标只前进不后退：`currentIndex = max(currentIndex, nextCurrentIndex)`

### 5.3 算法伪代码

```
初始化:
  anchorIndex = -1
  currentIndex = -1

每次消费 ASR 文本:
  1. anchorStart = max(0, anchorIndex + 1)
  2. 在窗口内找到最佳匹配结果
  3. nextCurrentIndex = anchorStart + match.scriptAdvance - 1
  4. currentIndex = max(currentIndex, nextCurrentIndex)  // 只前进
  5. 如果是 final 结果:
       anchorIndex = currentIndex  // 提交锚点
  6. 返回映射后的原稿索引
```

### 5.4 字符级匹配（跳字容错）

ASR 识别可能吞字（漏识别）或产生幻觉（多识别），算法允许**双向最多跳过 3 个字符**进行容错匹配：

```typescript
private charLevelMatch(scriptStart: number, transcript: string): MatchResult {
  let scriptIndex = scriptStart;
  let transcriptIndex = 0;
  let lastMatchedScriptIndex = scriptStart - 1;
  let matchedLength = 0;

  while (scriptIndex < this.cleanScript.length && transcriptIndex < transcript.length) {
    if (this.cleanScript[scriptIndex] === transcript[transcriptIndex]) {
      // 匹配成功，双方前进
      lastMatchedScriptIndex = scriptIndex;
      matchedLength += 1;
      scriptIndex += 1;
      transcriptIndex += 1;
      continue;
    }

    // 尝试跳原稿（ASR 吞字）
    for (let skip = 1; skip <= 3; skip++) {
      if (this.cleanScript[scriptIndex + skip] === transcript[transcriptIndex]) {
        scriptIndex += skip;
        continue outer;
      }
    }

    // 尝试跳 ASR（ASR 幻觉）
    for (let skip = 1; skip <= 3; skip++) {
      if (this.cleanScript[scriptIndex] === transcript[transcriptIndex + skip]) {
        transcriptIndex += skip;
        continue outer;
      }
    }

    // 都不匹配，双方各进一步
    scriptIndex += 1;
    transcriptIndex += 1;
  }

  return { matchedLength, scriptAdvance: ..., transcriptAdvance: ... };
}
```

**设计权衡**：
- 限制跳字数为 3：避免匹配漂移，同时解决大部分识别错误
- 优先跳原稿再跳 ASR：更符合实际 ASR 错误分布（吞字比幻觉更常见）

### 5.5 标点过滤与索引映射

对齐只在**有效字符**（中文、英文、数字）上进行，忽略所有标点符号：

```typescript
const CLEAN_CHAR_REGEX = /[a-zA-Z0-9\u4e00-\u9fa5]/u;

// 构建干净文本和索引映射
setScript(content: string) {
  this.cleanScript = '';
  this.indexMap = [];
  for (let i = 0; i < content.length; i++) {
    if (CLEAN_CHAR_REGEX.test(content[i])) {
      this.cleanScript += content[i];
      this.indexMap.push(i);  // 保存原稿索引
    }
  }
}
```

**反向映射**：干净文本索引 → 原稿索引

```typescript
private toRawIndex(cleanIndex: number): number {
  return this.indexMap[cleanIndex];
}
```

### 5.6 关键方法

| 方法 | 输入 | 输出 | 作用 |
|------|------|------|------|
| `setScript(content)` | 原稿 HTML | void | 初始化，构建 cleanScript 和 indexMap |
| `reset()` | - | void | 重置双指针到起始位置 |
| `setCurrentIndex(rawIndex)` | 原稿索引 | void | 手动跳转时同步覆盖锚点 |
| `consumeTranscript(text, isFinal)` | ASR 文本 + 是否最终 | AlignmentResult | 消费 ASR 结果，计算匹配位置 |

---

## 6. 提词器主视图

`TeleprompterView.tsx` 是提词器的主视图组件，整合控制栏、文本层、ASR 逻辑。

### 6.1 三种滚动模式

| 模式 | 滚动驱动 | 状态控制 |
|------|---------|---------|
| **手动** | 用户触摸/滚轮 | 无自动推进，ASR 不启动 |
| **自动** | RAF 定时器按 WPM 匀速推进 | 每帧计算时间增量，推进对应字数 |
| **本地 ASR** | 语音识别对齐推进 | 根据 ASR 对齐结果自动推进 |

### 6.2 自动匀速滚动核心代码

```typescript
useEffect(() => {
  let lastTime = performance.now();
  let accumulator = 0;

  const scroll = (time: number) => {
    if (settings.scrollMode === 'auto' && settings.isScrolling) {
      const deltaTime = time - lastTime;
      lastTime = time;

      const msPerChar = 60000 / settings.wpn;  // 每字符毫秒
      accumulator += deltaTime;

      if (accumulator >= msPerChar) {
        const charsToAdvance = Math.floor(accumulator / msPerChar);
        accumulator %= msPerChar;

        const newIndex = Math.min(totalChars - 1, currentIndexRef.current + charsToAdvance);
        if (newIndex >= totalChars - 1) {
          updateCurrentIndex(0);  // 读完自动重置
          setSettings((s) => ({ ...s, isScrolling: false }));
          return;
        }
        updateCurrentIndex(newIndex);
      }
      rafId = requestAnimationFrame(scroll);
    }
  };

  if (settings.scrollMode === 'auto' && settings.isScrolling) {
    rafId = requestAnimationFrame(scroll);
  }
  return () => { if (rafId) cancelAnimationFrame(rafId); };
}, [settings.scrollMode, settings.isScrolling, settings.wpn, updateCurrentIndex, totalChars]);
```

### 6.3 ASR 生命周期

**启动条件**：

```typescript
const shouldAsrBeOn =
  isVisible &&                          // 视图实际可见（占屏幕 50% 以上）
  settings.scrollMode === 'local' &&    // ASR 模式
  settings.isScrolling;                 // 播放状态
```

**启动流程**：
1. 调用 `asrClient.start()`
2. 注册 `onPartial` 回调：消费中间结果，限制跳幅，更新索引
3. 注册 `onFinal` 回调：消费最终结果，提交锚点
4. 注册 `onRms` 回调：更新音量计量

**停止流程**：
```typescript
const stopSpeechAsr = useCallback((showToast = false) => {
  setRms(0);
  asrClientRef.current?.stop().catch((error) => {
    if (!showToast) return;
    // 错误仅 toast 提示，不抛出
  });
}, [setToast]);
```

**边界处理**：
- `stop()` 幂等：已停止调用不做任何事
- 启动失败自动切回暂停状态并提示错误
- 组件卸载/模式切换自动清理
- 暂停/退出时立即停止采集、清空队列、释放麦克风

### 6.4 滚动定位算法

**阅读线位置**：
- 移动端：视口 30% 高度
- PC 端：视口 25% 高度

**计算流程**：

```
1. 确定目标字索引 = 当前索引 + 前瞻字数（移动端 0，PC 端 8）
2. 获取目标字 DOM 元素 → getBoundingClientRect() 得到屏幕坐标
3. 获取目标行 DOM → 得到行在屏幕坐标
4. 计算：
   - 阅读线 Y = window.innerHeight * 0.25
   - 目标字在行内偏移 = targetRect.top - lineRect.top
   - 目标字在容器内绝对 top = lineRect.top - containerRect.top + 字偏移
   - 最终目标 top = 限制在行高范围内，避免底部跳出
   - 目标 scrollTop = container.scrollTop + 目标字容器内 top - (阅读线 Y - containerRect.top)
5. container.scrollTo({ top: targetScrollTop, behavior: 'smooth' })
```

**关键代码**：

```typescript
const readingLineY = window.innerHeight * (isMobile ? 0.3 : 0.25);
const targetRect = targetElement.getBoundingClientRect();
const containerRect = container.getBoundingClientRect();
const lineRect = targetLine.getBoundingClientRect();

const relativeReadingY = readingLineY - containerRect.top;
const wordOffsetInLine = targetRect.top - lineRect.top;
const trueTargetTopInContainer = lineRect.top - containerRect.top + wordOffsetInLine;

// 底部锁定：不超出当前段落底部减去 3 行高度
const boxHeight = settings.fontSize * settings.lineHeight * 3;
const maxTargetTopInContainer = lineRect.bottom - containerRect.top - boxHeight;
const finalTargetTopInContainer = lineRect.height < boxHeight
  ? trueTargetTopInContainer
  : Math.min(trueTargetTopInContainer, maxTargetTopInContainer);

const targetScrollTop = Math.max(0,
  container.scrollTop + finalTargetTopInContainer - relativeReadingY
);

container.scrollTo({
  top: targetScrollTop,
  behavior: currentIndex >= 0 ? 'smooth' : 'auto',
});
```

**误差补偿分析**：
- 使用 `container.scrollTop + (targetTop - readingLineY)` 而非绝对定位
- 保证相对滚动平滑，避免跳变
- 只在 requestAnimationFrame 中执行，避免多次布局计算

### 6.5 空气垫设计

```tsx
<div className="pt-[65vh] pb-[220vh]">
  {/* 文本内容 */}
</div>
```

**作用**：
- 顶部 65vh：第一句可以滚动到阅读线位置，不会被顶部边界卡住
- 底部 220vh：最后一句可以滚动到阅读线位置，不会被底部边界卡住
- 允许用户继续向下滚动，完全读完稿件

### 6.6 可见性控制 ASR 启停

使用 `framer-motion` 的 `useInView` 检测容器可见性：

```typescript
const isVisible = useInView(containerRef, { amount: 0.5 });
```

- 当提词器视图可见面积 < 50%，自动停止 ASR
- 当提词器视图回到前台并满足启动条件，自动重启 ASR
- 配合预挂载设计，只在实际可见时占用麦克风和计算资源

### 6.7 控制功能

| 功能 | 说明 |
|------|------|
| **字体大小** | 范围 24px ~ 120px，支持 5 个预设 |
| **响应式适配** | 根据视口尺寸自动选择字号和行高 |
| **镜像翻转** | CSS 类 `.mirror-mode` 实现水平翻转，用于提词器分光镜 |
| **调速（自动模式）** | WPM（字/分钟），范围 60 ~ 450，预置多档位 |

**响应式预设选择**：

```typescript
function getResponsiveTeleprompterPreset(width: number, height: number) {
  const shorterSide = Math.min(width, height);
  if (width < 480) {
    return {
      fontSize: shorterSide < 380 ? 32 : 36,
      lineHeight: 1.6,
      paddingX: 4,
    };
  }
  // ... 其他断点
}
```

---

## 7. 文本渲染层

`TeleprompterTextLayer.tsx` 负责文本的逐字符渲染和高亮。

### 7.1 HTML 富文本解析为逐字符数组

**解析流程**：

1. 使用 `DOMParser` 解析 HTML 字符串
2. 递归遍历 DOM 节点，收集文本节点
3. 对每个文本节点字符，向上遍历父元素收集格式信息
4. 按块元素（p/div/h1-h6 等）分行渲染
5. 每个字符单独包裹 `<span>`，方便点击跳转和高亮

**格式收集逻辑**：

```typescript
function collectFormats(el: Element): FormatChar['format'] {
  const formats: FormatChar['format'] = {};
  let current: Element | null = el;
  let fontSizeFound = false;
  while (current) {
    const tag = current.tagName.toLowerCase();
    if (tag === 'strong' || tag === 'b') formats.bold = true;
    if (tag === 'em' || tag === 'i') formats.italic = true;
    if (tag === 'u') formats.underline = true;
    if (tag === 's' || tag === 'strike' || tag === 'del') formats.strike = true;
    if (!fontSizeFound) {
      const style = current.getAttribute('style');
      if (style) {
        const match = style.match(/font-size:\s*(\d+(?:\.\d+)?)px/i);
        if (match) {
          formats.fontSize = parseFloat(match[1]) / 16;  // 相对倍数
          fontSizeFound = true;
        }
      }
    }
    current = current.parentElement;
  }
  return formats;
}
```

### 7.2 已读高亮实现

每个字符单独渲染，通过索引判断是否已读：

```tsx
<span
  className={cn(
    'inline cursor-pointer rounded px-0.5 transition-colors duration-150 hover:bg-white/10',
    token.format.bold && 'font-bold',
    token.format.italic && 'italic',
    token.format.underline && 'underline',
    token.format.strike && 'line-through',
  )}
>
  {token.char}
</span>
```

**设计决策**：阅读线固定在视口，文字向上滚动，已读文字滚动到阅读线上方自然淡出，不需要额外高亮样式覆盖。

### 7.3 富文本格式保留

通过递归收集父节点格式信息，每个字符携带完整格式：

| 格式 | 实现 |
|------|------|
| 粗体 | `font-bold` |
| 斜体 | `italic` |
| 下划线 | `underline` |
| 删除线 | `line-through` |
| 字体大小 | 相对基字号的比例，内联 style 应用 |

---

## 8. ASR 语音识别架构

### 8.1 架构概览

系统支持两种 ASR 引擎：

| 引擎 | 实现 | 特点 |
|------|------|------|
| **本地 Sherpa-Onnx** | 前端 WASM 推理 | 无需网络、低延迟、离线可用 |
| **飞书云 ASR** | 前端直连飞书 API | 识别精度高、需网络 |

### 8.2 ASR 客户端接口

```typescript
export interface TeleprompterAsrClient {
  start(
    onPartial: (text: string) => void,    // 中间结果回调
    onFinal: (text: string) => void,      // 句子结束最终结果回调
    onRms: (rms: number) => void,         // 音量 RMS 回调（VAD 显示）
    onTelemetry?: (sample: AsrLatencySample) => void,  // 遥测
  ): Promise<void>;

  stop(): Promise<void>;
}
```

接口抽象使得可以接入不同 ASR 实现。

### 8.3 Sherpa-Onnx 本地 ASR 实现

**模型加载策略**：
- 单例共享 recognizer 实例：整个应用只加载一次模型
- 分阶段加载：绑定 JS → 运行时 WASM → 初始化识别器
- 支持预加载：进入提词器前提前加载模型

**音频处理**：

使用 `ScriptProcessorNode` 处理麦克风音频流：
- 缓冲区大小：4096 帧
- 采样率：16000 Hz
- 每次 `onaudioprocess` 得到一帧音频数据

```typescript
this.processor.onaudioprocess = (e) => {
  if (!this.isRunning || !this.recognizer || !this.stream) return;

  const float32 = new Float32Array(e.inputBuffer.getChannelData(0));

  // 计算音量 RMS
  const rmsValue = Math.sqrt(
    float32.reduce((s, v) => s + v * v, 0) / float32.length,
  );
  this.callbacks?.onRms(Number(rmsValue.toFixed(3)));

  // 送入识别流
  this.stream.acceptWaveform(16000, float32);

  // 持续解码直到处理完所有帧
  while (this.recognizer.isReady(this.stream)) {
    this.recognizer.decode(this.stream);
  }

  // 检测是否句子端点
  const isEndpoint = this.recognizer.isEndpoint(this.stream);
  const result = this.recognizer.getResult(this.stream);

  if (result.text && result.text !== lastPartialText) {
    lastPartialText = result.text;
    this.callbacks?.onPartial(result.text);
  }

  if (isEndpoint) {
    if (lastPartialText) {
      this.callbacks?.onFinal(lastPartialText);
      lastPartialText = '';
    }
    this.recognizer.reset(this.stream);
  }
};
```

**端点检测（VAD）**：
- 由 Sherpa-Onnx 内置完成
- 检测到静音超过阈值，认为句子结束
- 触发 `onFinal` 回调，重置识别流

**幂等清理逻辑**：

```typescript
async stop(): Promise<void> {
  if (!this.isRunning) return;  // 已停止直接返回，幂等
  this.isRunning = false;
  this.cleanup();
}

private cleanup(): void {
  if (this.processor) {
    this.processor.disconnect();
    this.processor = null;
  }
  if (this.audioContext) {
    try {
      this.audioContext.close();
    } catch { /* ignore */ }
    this.audioContext = null;
  }
  if (this.mediaStream) {
    this.mediaStream.getTracks().forEach((t) => t.stop());
    this.mediaStream = null;
  }
  if (this.stream) {
    this.stream.free();
    this.stream = null;
  }
  this.recognizer = null;
  this.callbacks = null;
}
```

**设计要点**：
- 所有清理步骤都做空检查，重复 stop 安全
- AudioContext close 包 try-catch，避免已关闭抛出异常
- 释放所有媒体轨道，确保麦克风可用给其他应用

### 8.4 飞书云 ASR 架构

当前采用**前端直连飞书接口**架构：

```
前端 → /api/feishu-proxy/tenant-access-token（后端代理获取 token）
     → 飞书 speech_to_text/v1/speech/stream_recognize（前端直连）
```

**音频切片策略**：
- `CHUNK_SIZE = 3200` 采样点
- 最小请求间隔 200ms
- 兼顾时延和 QPS 限制

**排队锁与 QPS 保护**：
- `isSending` 排队锁：同一时间只发送一个切片
- QPS 超限退避重试：收到 `qps exceeded` 错误后单次退避

**架构选择原因**：
- 降低延迟：前端直连减少后端转发跳数
- 提升实时性：音频切片直接发送给飞书，无需后端缓冲
- 安全性：token 通过后端代理获取，AppSecret 不暴露给前端

---

## 9. 飞书代理后端

`server/modules/feishu-proxy/` 提供飞书 API 代理。

### 9.1 API 路由

| 方法 | 路径 | 功能 |
|------|------|------|
| POST | `/api/feishu-proxy/tenant-access-token` | 获取飞书租户访问令牌 |
| POST | `/api/feishu-proxy/speech-recognize` | 语音识别代理（备用） |

### 9.2 Token 缓存策略

**缓存 Key**：`appId::normalizedBaseUrl`

**缓存失效**：

```typescript
const TOKEN_REFRESH_BUFFER_MS = 300000;  // 5 分钟

if (Date.now() >= cached.expiresAt - TOKEN_REFRESH_BUFFER_MS) {
  // 提前 5 分钟过期刷新
  this.tokenCache.delete(cacheKey);
  return null;
}
```

**缓冲机制**：在飞书返回的过期时间提前 5 分钟认为失效，避免使用过期 token。

### 9.3 并发请求去重

```typescript
if (!params.forceRefresh) {
  const cached = this.getCachedToken(params);
  if (cached) return cached;

  // 如果已有相同请求在进行，复用该 Promise
  const pendingRequest = this.pendingTokenRequests.get(cacheKey);
  if (pendingRequest) {
    return pendingRequest;
  }
}

// 创建新请求，存入 pending map
const request = this.fetchTenantAccessToken(params)
  .then((result) => {
    this.tokenCache.set(cacheKey, {
      tenantAccessToken: result.tenantAccessToken,
      expire: result.expire,
      expiresAt: Date.now() + result.expire * 1000,
    });
    return result;
  })
  .finally(() => {
    this.pendingTokenRequests.delete(cacheKey);
  });

this.pendingTokenRequests.set(cacheKey, request);
return request;
```

**设计效果**：
- 避免并发多个相同请求飞书接口
- 保护飞书 API 调用配额
- 减少网络等待，所有等待方复用同一个结果

### 9.4 错误处理

| 错误类型 | 处理方式 |
|---------|---------|
| HTTP 非 2xx 响应 | 记录日志，抛出 `BadGatewayException` |
| 飞书业务码非 0 | 记录 code/msg，抛出结构化错误 |
| 网络异常/超时 | 捕获异常，记录日志，抛出网络错误 |
| 语音识别请求错误 | 记录 streamId/sequenceId，错误向上抛出 |

**超时控制**：15 秒超时（`AbortSignal.timeout(15000)`）

---

## 10. UI 设计与主题系统

### 10.1 色彩系统

采用语义化命名 + HSL 色彩空间，基于品牌色 `#DB9D16` 构建完整深色主题。

**品牌色映射**：

```css
--primary: hsl(42 81% 47%);  /* #DB9D16 */
```

**深色主题基线**：

| 区域 | HSL 值 | 对应十六进制 |
|------|--------|--------------|
| 主背景 | `hsl(0 0% 5%)` | `#0d0d0d` |
| 卡片/表层 | `hsl(0 0% 8% ~ 9%)` | `#141414 ~ #171717` |
| 主文字 | `hsl(0 0% 95%)` | `#f2f2f2` |
| 弱文字 | `hsl(0 0% 62%)` | `#9e9e9e` |
| 边框 | `hsl(0 0% 18%)` | `#2e2e2e` |

**完整色彩变量**：

| 变量 | 用途 |
|------|------|
| `--background` | 主背景 |
| `--foreground` | 主文字 |
| `--card` / `--card-foreground` | 卡片 |
| `--popover` / `--popover-foreground` | 弹出框 |
| `--primary` / `--primary-foreground` | 品牌色 |
| `--secondary` / `--secondary-foreground` | 次要色 |
| `--muted` / `--muted-foreground` | 弱文字 |
| `--border` | 边框 |
| `--input` | 输入框 |
| `--success` / `--warning` / `--error` | 语义色 |
| `--canvas-bg` / `--surface-bg` / `--terminal-bg` | 场景专用 |

### 10.2 品牌色应用位置

- 主按钮背景
- 边框高亮、悬停高亮
- 链接、文字高亮
- 侧边栏主色
- 提词器已读高亮
- 徽章、标签

### 10.3 稿件卡片设计

**响应式栅格**：

```tsx
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
```

**卡片视觉**：
- `rounded-3xl border-neutral-800/50 bg-neutral-900/40`
- 悬停上移 `hover:-translate-y-1`
- 品牌边框高亮 + 阴影
- 右下角模糊光晕 `bg-yellow-500/5 blur-[60px]` 增强品牌氛围

**卡片结构**：
1. 文件图标
2. 标题
3. 3 行正文预览
4. 底部修改日期
5. 悬停显示"开始提词"按钮
6. 编辑/删除按钮仅悬停显示 `opacity-0 group-hover:opacity-100`

---

## 11. 稿件管理

### 11.1 混合存储方案

| 存储类型 | 数据来源 | 特点 |
|---------|---------|------|
| **远程稿件** | `/api/articles` 后端 API | 持久化、多端同步 |
| **临时稿件** | 浏览器 localStorage | 快速创建、离线可用 |

**合并展示**：

```typescript
const scripts = useMemo(
  () => [...temporaryScripts, ...remoteScripts],
  [temporaryScripts, remoteScripts]
);
```

### 11.2 搜索过滤

```typescript
const filteredScripts = useMemo(() => {
  return scripts.filter(
    (script) =>
      script.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      script.content.toLowerCase().includes(searchQuery.toLowerCase()),
  );
}, [scripts, searchQuery]);
```

- 不区分大小写
- 同时匹配标题和正文
- 搜索结果实时更新

### 11.3 后端 CRUD 接口

| 方法 | 路径 | 权限 | 功能 |
|------|------|------|------|
| GET | `/api/articles` | 公开 | 获取稿件列表（按更新时间倒序） |
| POST | `/api/articles` | 需要登录 | 创建新稿件 |
| PATCH | `/api/articles/:id` | 需要登录 | 更新稿件 |
| DELETE | `/api/articles/:id` | 需要登录 | 删除稿件 |

**数据库操作**：
- ORM：Drizzle ORM
- 列表查询：`orderBy(desc(articleTable.updatedAt))`，最新修改在前
- 创建：插入 `title/content/coverImage/status/userId`
- 更新：支持部分更新，只更新传入字段
- 删除：按 id 删除，找不到返回 404

**用户身份获取**：
- 创建稿件：从 `req.userContext.userId` 获取当前登录用户 ID

---

## 12. AI 优化能力

### 12.1 功能概述

在新建/编辑稿件弹窗中，支持"AI 优化正文"功能：
- 自动补齐逗号句号
- 整理为标准中文段落
- 保留原意，仅优化标点段落

### 12.2 流式调用实现

```typescript
const handleOptimize = async () => {
  setOptimizing(true);
  setOptimizedPreview('');
  try {
    let nextContent = '';
    for await (const chunk of optimizeTextWithAI(content.trim())) {
      nextContent += chunk;
      setOptimizedPreview(nextContent);  // 实时更新预览
    }
    setContent(nextContent.trim());  // 完成后应用到正文
  } finally {
    setOptimizing(false);
  }
};
```

**实现要点**：
- 使用 `for await...of` 消费流式返回
- 每收到一个 chunk 立即更新预览
- 用户能看到增量过程
- 优化过程中禁用提交按钮

### 12.3 优化预览 UI

- 独立容器展示，带渐变黄色边框和背景
- 顶部显示状态："AI 正在整理..." / "本次优化已完成" + 对应徽章
- 预览区支持滚动，保留换行格式
- 优化说明提示用户 AI 只整理标点段落

### 12.4 插件实例

使用 `manuscript_text_optimization_1` 插件实例进行流式优化。

---

## 13. 数据库模型

### 13.1 稿件表（article）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `title` | VARCHAR(255) | 标题 |
| `content` | TEXT | 正文（HTML 富文本） |
| `coverImage` | TEXT | 封面图 URL |
| `userId` | user_profile | 创建者用户 ID |
| `status` | VARCHAR(255) | 状态（draft/published） |
| `排序` | BIGINT | 排序权重 |
| `createdAt` | TIMESTAMPTZ | 创建时间 |
| `updatedAt` | TIMESTAMPTZ | 更新时间 |

**索引**：
- `idx_article_status`：按状态查询
- `idx_article_user_id`：按用户查询

### 13.2 系统设置表（system_setting）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `settingsKey` | VARCHAR(255) | 设置键（唯一） |
| `feishuAppId` | VARCHAR(255) | 飞书 App ID |
| `feishuAppSecret` | TEXT | 飞书 App Secret |
| `feishuBaseUrl` | TEXT | 飞书 API 基础 URL |
| `feishuEngineType` | VARCHAR(255) | 语音引擎类型 |
| `createdAt` | TIMESTAMPTZ | 创建时间 |
| `updatedAt` | TIMESTAMPTZ | 更新时间 |

**唯一索引**：`uk_system_setting_settings_key`

### 13.3 自定义类型

| 类型 | 说明 |
|------|------|
| `user_profile` | 用户资料复合类型，包含 `user_id` 字段 |
| `file_attachment` | 文件附件类型，包含 `bucket_id` 和 `file_path` |
| `customTimestamptz` | 带精度的时间戳类型 |

---

## 14. 性能优化策略

### 14.1 视图预挂载

首页同时挂载 manager（列表）和 prompter（提词器）两种视图，通过 CSS `display: block/none` 切换，而非条件渲染。

**效果**：进入提词器的延迟从 ~500ms 降至 ~50ms。

### 14.2 初始化副作用拆分

拆分为 5 个独立 `useEffect`，避免 `globalSettings` 变化时重复拉取稿件和系统设置。

### 14.3 ASR 模型预加载

进入首页时后台预热 Sherpa-Onnx 模型加载，错误仅日志不阻塞页面。

### 14.4 Token 并发锁

飞书 tenant-access-token 同一时段只请求一次，避免重复请求。

### 14.5 ASR 可见性控制

仅在提词器视图实际可见（占屏幕 50% 以上）时启动 ASR，节省资源。

### 14.6 RAF 驱动滚动

自动模式使用 `requestAnimationFrame` 驱动滚动，保证 60fps 流畅度。

---

## 15. 边界情况与容错

### 15.1 ASR 容错

| 场景 | 处理方式 |
|------|---------|
| ASR 吞字（漏识别） | 跳原稿最多 3 字继续匹配 |
| ASR 幻觉（多识别） | 跳 ASR 文本最多 3 字继续匹配 |
| ASR 标点不一致 | 过滤标点，只在有效字符上匹配 |
| ASR 非 final 结果漂移 | 始终从锚点重算，不移动锚点 |

### 15.2 滚动边界

| 场景 | 处理方式 |
|------|---------|
| 第一句被顶部卡住 | 65vh 顶部空气垫 |
| 最后一句被底部卡住 | 220vh 底部空气垫 |
| 底部锁定 | 不超出当前段落底部减去 3 行高度 |

### 15.3 ASR 资源清理

| 场景 | 处理方式 |
|------|---------|
| 暂停滚动 | 立即停止语音链路 |
| 退出稿件 | 停止 ASR，释放麦克风 |
| 模式切换 | 清空队列，取消进行中的请求 |
| 组件卸载 | 清理所有定时器和资源 |

### 15.4 网络异常

| 场景 | 处理方式 |
|------|---------|
| 飞书 API 非 2xx | 后端记录日志，返回 502 + 结构化错误 |
| 网络超时 | 15 秒超时，返回结构化网络错误 |
| Token 获取失败 | 前端提示用户补全配置 |

### 15.5 麦克风权限

| 场景 | 处理方式 |
|------|---------|
| 非 HTTPS 环境 | 提示错误（麦克风需要安全上下文） |
| 浏览器不支持 | 提示错误 |
| 权限被拒绝 | 完整清理后抛出错误 |

---

## 16. 核心调用链路

### 16.1 提词器跟随模式

```
Home (首页)
  ↓ 点击稿件
TeleprompterView (提词器主视图)
  ↓ 初始化
SherpaOnnxAsrClient / FeishuASRClient (ASR 采集)
  ↓ onPartial / onFinal 回调
TeleprompterAlignment.consumeTranscript() (对齐算法)
  ↓ 返回 AlignmentResult
TeleprompterTextLayer (更新 currentIndex)
  ↓ 触发滚动定位
getBoundingClientRect() + scrollTo() (滚动到阅读线)
```

### 16.2 飞书 Token 获取

```
前端请求 /api/feishu-proxy/tenant-access-token
  ↓
后端 FeishuProxyController
  ↓
FeishuProxyService.getTenantAccessToken()
  ↓ 检查缓存
命中缓存 → 直接返回
  ↓ 未命中
检查 pending 请求
有 pending → 复用 Promise
  ↓ 无 pending
请求飞书 /auth/v3/tenant_access_token/internal
  ↓
缓存结果 + 清理 pending
  ↓
返回前端
```

### 16.3 AI 优化正文

```
用户点击"AI 优化正文"
  ↓
ArticleCreateDialog / ArticleEditDialog
  ↓
optimizeTextWithAI(content)
  ↓ 流式调用
manuscript_text_optimization_1 插件
  ↓ for await...of
实时更新 optimizedPreview 状态
  ↓ 优化完成
用户确认 → 应用到正文
```

---

## 附录：关键文件清单

| 文件路径 | 行数 | 核心功能 |
|---------|------|---------|
| `client/src/pages/Home/Home.tsx` | ~500 | 首页主容器，视图切换、稿件管理 |
| `client/src/components/teleprompter/TeleprompterView.tsx` | ~1570 | 提词器主视图，整合所有核心功能 |
| `client/src/components/teleprompter/TeleprompterTextLayer.tsx` | ~570 | 文本渲染层，逐字高亮和滚动 |
| `client/src/lib/teleprompter/alignment/engine.ts` | ~252 | 对齐引擎核心算法 |
| `client/src/lib/teleprompter/asr-client.ts` | - | ASR 客户端接口定义 |
| `client/src/lib/teleprompter/sherpa-asr-client.ts` | - | Sherpa-Onnx 本地 ASR 实现 |
| `client/src/components/teleprompter/ScriptEditor.tsx` | ~2981 | 脚本编辑器 |
| `server/modules/feishu-proxy/feishu-proxy.service.ts` | ~263 | 飞书 API 代理 |
| `server/modules/article/article.controller.ts` | - | 稿件 CRUD 控制器 |
| `server/modules/article/article.service.ts` | - | 稿件数据库操作 |
| `server/modules/system-settings/` | - | 系统设置存储 |
| `shared/api.interface.ts` | ~119 | 前后端共享类型定义 |
| `server/database/schema.ts` | - | Drizzle ORM 表结构 |

---

*报告生成时间：2026-06-05*
*基于飓风提词器 v1.0 代码库分析*
