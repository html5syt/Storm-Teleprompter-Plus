# 飓风提词器 — 技术实现全解析

> 本文以通俗易懂的语言，详细拆解飓风提词器的每一项技术实现，包括系统架构、核心算法、界面设计、功能细节等。无论你是新加入项目的开发者，还是想深入理解整个系统的 AI 智能体，都可以把这当成一份完整的学习手册。

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

飓风提词器是一个**前后端一体的全栈 Web 应用**，前端用 React 构建，后端用 NestJS 搭建。它最主要的能力是：**主播朗读稿件时，系统能“听懂”他说到哪了，自动把文字向上滚动，让当前正在读的那一行始终停留在屏幕的固定阅读线上**，就像有一个看不见的助手在精准翻稿。

除了这个核心的“语音跟随”功能，它还支持手动滚动、自动匀速滚动两种传统模式，并且内置了富文本编辑器、AI 润色、云端同步等功能，完全可以作为专业录播或直播的提词工具使用。

### 核心特性一览

| 特性 | 说明 |
|------|------|
| **语音跟随** | 实时识别朗读内容，自动滚动稿件；支持本地 Sherpa-Onnx 识别引擎和飞书云端识别引擎两种方案 |
| **流式对齐算法** | 采用双指针字符级匹配，能自动容忍最多 3 个字的漏识别或多识别偏差 |
| **三种提词模式** | 手动滚动 / 自动匀速滚动 / 语音跟随，一键切换 |
| **富文本支持** | 稿件可包含粗体、斜体、下划线、删除线，以及自定义字号 |
| **镜像翻转** | 支持提词器分光镜场景，将画面水平翻转，方便摄像机前使用 |
| **响应式设计** | 一套代码自动适配手机端和电脑端的不同屏幕 |
| **AI 优化** | 流式调用 AI 对稿件正文进行智能整理（补标点、分段），边生成边预览 |
| **混合存储** | 兼顾云端持久化和浏览器本地临时稿件，联网离线两不误 |

---

## 2. 技术栈

### 前端

| 技术 | 用途 |
|------|------|
| React 19 | 构建用户界面的主力框架 |
| TypeScript | 为所有 JavaScript 代码加上类型检查，减少低级错误 |
| React Router DOM v6 | 管理页面跳转与路由 |
| Tailwind CSS v4 | 用工具类快速编写样式，保持主题一致 |
| styled-jsx | 编写那些复杂的 CSS 动画和组件私有样式 |
| shadcn/ui | 基于 Radix UI 的高质量组件库，拿来即用 |
| Framer Motion | 实现动画效果，还能检测组件是否出现在屏幕视野内 |
| Lucide React | 统一的图标库 |
| dayjs | 日期格式化与处理 |
| Tiptap | 功能强大的富文本编辑器 |
| Sherpa-Onnx | 本地语音识别引擎（通过 WebAssembly 在浏览器中运行） |

### 后端

| 技术 | 用途 |
|------|------|
| NestJS 10.x | 基于 Express 的企业级后端框架，依赖注入、模块化设计 |
| Drizzle ORM | 轻量 TypeScript ORM，类型安全地操作数据库 |
| PostgreSQL | 关系型数据库，保存稿件、系统设置等数据 |
| @nestjs/axios | NestJS 封装后的 HTTP 客户端，用于调用外部 API |

### 构建工具

| 工具 | 用途 |
|------|------|
| Rspack | 极速打包前端资源，替代 Webpack |
| NestJS CLI | 开发与构建后端应用 |

---

## 3. 项目结构

整个项目的源码组织得非常清晰，前端和后端分别放在 `client/` 和 `server/` 下，还有一个 `shared/` 目录用来存放前后端共享的 TypeScript 类型定义。

```
├── client/src/
│   ├── api/                          # 封装好的 API 调用函数，统一管理后端接口
│   ├── components/
│   │   ├── teleprompter/             # 提词器相关组件
│   │   │   ├── TeleprompterView.tsx  # 提词器主视图，整合控制栏、文本显示与语音跟随
│   │   │   ├── TeleprompterTextLayer.tsx  # 文本渲染层，负责将 HTML 拆分成逐字符显示
│   │   │   ├── ScriptEditor.tsx      # 脚本（稿件）编辑器
│   │   │   ├── GlobalSettingsDialog.tsx  # 全局设置弹窗
│   │   │   ├── LatencyPanel.tsx      # ASR 延迟统计面板（开发调试用）
│   │   │   └── types.ts              # 组件层面的类型定义
│   │   ├── business-ui/              # 多个页面共用的业务组件
│   │   ├── ui/                       # 基于 shadcn/ui 二次封装的基础组件
│   │   └── Layout.tsx                # 全局布局（导航栏、侧边栏等）
│   ├── hooks/                        # 可复用的 React 自定义 Hooks
│   ├── lib/teleprompter/             # 提词器核心逻辑库（纯逻辑，不依赖 UI）
│   │   ├── alignment/
│   │   │   ├── engine.ts             # 对齐引擎核心算法，语音到稿件的匹配核心
│   │   │   └── index.ts              # 对齐引擎的单例导出
│   │   ├── asr-client.ts             # ASR 客户端接口定义（抽象类）
│   │   ├── sherpa-asr-client.ts      # 基于 Sherpa-Onnx 的本地 ASR 实现
│   │   └── temp-script-store.ts      # 浏览器临时稿件存储工具
│   ├── pages/
│   │   ├── Home/
│   │   │   ├── Home.tsx              # 首页主容器，融合稿件列表和提词器两大视图
│   │   │   ├── ArticleCardList.tsx   # 稿件卡片网格
│   │   │   ├── ArticleCreateDialog.tsx  # 新建稿件弹窗
│   │   │   ├── ArticleEditDialog.tsx    # 编辑稿件弹窗
│   │   │   └── ArticleDeleteDialog.tsx  # 删除确认弹窗
│   │   ├── ScriptEditor/
│   │   │   └── ScriptEditorPage.tsx  # 独立脚本编辑器页面
│   │   └── NotFound/
│   │       └── NotFound.tsx          # 404 页面
│   ├── types/                        # 全局通用类型定义
│   ├── utils/                        # 工具函数
│   ├── app.tsx                       # 应用根组件与路由配置
│   ├── index.tsx                     # ReactDOM 入口文件
│   ├── tailwind-theme.css            # Tailwind 主题变量定制
│   └── index.css                     # 全局样式补充
├── server/
│   ├── modules/
│   │   ├── article/                  # 稿件 CRUD 模块
│   │   ├── feishu-proxy/             # 飞书 API 代理模块
│   │   ├── system-settings/          # 系统设置读写模块
│   │   └── view/                     # 视图渲染模块（SSR 相关）
│   ├── database/
│   │   └── schema.ts                 # Drizzle ORM 定义的表结构
│   └── capabilities/                 # 插件实例配置（如 AI 能力）
└── shared/
    └── api.interface.ts              # 前后端共享的类型与接口定义
```

---

## 4. 路由与页面架构

### 路由配置

整个应用只有三个页面，路由结构非常简单：

| 路由 | 组件 | 说明 |
|------|------|------|
| `/` | Home | 首页，包含稿件列表 + 提词器双视图 |
| `/editor/:id` | ScriptEditorPage | 独立的稿件编辑器页面 |
| `*` | NotFound | 404 页面，处理未匹配的路径 |

React Router 的配置如下：

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

所有包含导航和布局的页面都放在 `Layout` 组件内部，而编辑器页面和 404 页面则独立渲染，这样可以根据场景灵活决定是否显示导航栏。

### 首页视图预挂载设计

首页（`Home`）其实承载了两个完全不同的界面：**稿件管理视图**（列表和卡片）和**提词器视图**。传统做法是通过条件渲染来切换，即切换到提词器时再挂载提词器组件，切回管理视图时就卸载它。

我们采用了一个更聪明的策略：**两个视图始终同时挂载，只是通过 CSS 的 `display: block` 和 `display: none` 来控制哪个可见**。

这样做的好处非常明显：

- 切换视图时不再需要重新挂载组件，免去了初始化 ASR 引擎、加载对齐模型等昂贵的操作。
- 从点击“开始提词”到看到提词器界面，延迟从原来大约 500 毫秒降到了 50 毫秒，几乎是瞬间出现。

代码示意：

```tsx
// Home.tsx 片段
{activeScriptId && (
  <div className={view === 'prompter' ? 'block' : 'hidden'}>
    <TeleprompterView script={activeScript} ... />
  </div>
)}

<div className={view === 'manager' ? '...' : 'hidden'}>
  {/* 稿件列表 */}
</div>
```

### 初始化的副作用拆分

首页在加载时需要做很多事：加载稿件列表、拉取系统设置、预加载语音识别模型、监听本地临时稿件等等。为了不让这些工作互相阻塞，我们把这些初始化逻辑拆成了 5 个独立的 `useEffect`，每个只关心自己的触发条件：

| 副作用 | 干了什么 | 触发时机 |
|--------|---------|---------|
| 滚动监听 | 更新导航栏头部的透明度 | 用户滚动页面时 |
| 临时脚本订阅 | 监听浏览器本地存储中临时稿件的增删变化 | 组件挂载后仅一次 |
| ASR 预热 | 后台静默加载 Sherpa-Onnx 模型，减少进入提词器时的等待 | 组件挂载后仅一次 |
| 加载应用设置 | 从后端获取全局设置（如飞书配置、默认 WPM 等） | 组件挂载后仅一次 |
| 加载稿件 | 调用 API 获取所有云端稿件 | 组件挂载后仅一次 |

拆分后，如果未来某个设置变化了，它只会触发对应的副作用，不会连带引起不必要的稿件重新拉取或模型重新加载。

---

## 5. 核心算法：对齐引擎

对齐引擎是语音跟随提词的灵魂。它的任务是：**把语音识别返回的零碎文本，和原稿内容进行逐个字符的比对，找到主播当前读到了哪个字**。这个引擎位于 `client/src/lib/teleprompter/alignment/engine.ts`。

### 5.1 设计目标

语音识别引擎给出的结果并不是完美的。它可能会漏掉几个字（吞字），也可能多出几个原文没有的字（幻觉），而且标点符号的处理往往乱七八糟。对齐引擎要能在这些干扰下，仍然准确地找到当前朗读位置，并且不能出现大幅度跳动，保证视觉上的滚动平顺。

### 5.2 双指针策略

引擎维护两个关键索引：

- **anchorIndex（锚点）**：已经确认匹配完成的最后位置。只有识别引擎明确说“这一句结束了”（final 结果），锚点才会被更新到这个新的确认位置。
- **currentIndex（游标）**：当前实时匹配到的最佳位置。随着中间识别结果不断更新，游标可能会往前跳跃，但绝不会后退。

核心规则：
- 对于**非 final 的临时结果**（partial），每次都从锚点之后重新计算匹配，但锚点本身不动。这样做可以修正识别过程中的漂移。
- 对于**final 最终结果**，锚点会被正式提交更新到游标的位置。
- 游标只前进不后退：`currentIndex = max(currentIndex, 新计算的位置)`。

### 5.3 算法流程简述

```
初始化:
  anchorIndex = -1
  currentIndex = -1

每次收到一段 ASR 文本:
  1. 计算搜索起点：anchorStart = max(0, anchorIndex + 1)
  2. 从 anchorStart 开始的窗口内进行字符级匹配
  3. 得到匹配结果，算出 nextCurrentIndex
  4. currentIndex = max(currentIndex, nextCurrentIndex)  // 只前进不后退
  5. 如果是 final 结果:
       anchorIndex = currentIndex  // 提交锚点
  6. 返回映射后的原稿索引
```

### 5.4 字符级匹配与跳字容错

字符级匹配不是简单的字符串相等比较。考虑到 ASR 可能吞字或多字，算法允许**双向最多跳过 3 个字符**来尝试重新对齐。

实现的核心是两层循环：
- 优先尝试跳过原稿字符（适应吞字情况）。
- 如果跳原稿还是对不上，再尝试跳过识别文本字符（适应幻觉多字情况）。
- 如果两个方向 3 步内都找不到匹配，那就各进一步，继续往后匹配。

```typescript
private charLevelMatch(scriptStart: number, transcript: string): MatchResult {
  let scriptIndex = scriptStart;
  let transcriptIndex = 0;
  let lastMatchedScriptIndex = scriptStart - 1;
  let matchedLength = 0;

  while (scriptIndex < this.cleanScript.length && transcriptIndex < transcript.length) {
    if (this.cleanScript[scriptIndex] === transcript[transcriptIndex]) {
      // 字符匹配成功，双方指针同时前进
      lastMatchedScriptIndex = scriptIndex;
      matchedLength += 1;
      scriptIndex += 1;
      transcriptIndex += 1;
      continue;
    }

    // 尝试跳过原稿字符（容忍 ASR 吞字）
    for (let skip = 1; skip <= 3; skip++) {
      if (this.cleanScript[scriptIndex + skip] === transcript[transcriptIndex]) {
        scriptIndex += skip;
        continue outer;
      }
    }

    // 尝试跳过 ASR 文本字符（容忍 ASR 幻觉多字）
    for (let skip = 1; skip <= 3; skip++) {
      if (this.cleanScript[scriptIndex] === transcript[transcriptIndex + skip]) {
        transcriptIndex += skip;
        continue outer;
      }
    }

    // 双方都对不上，各进一步
    scriptIndex += 1;
    transcriptIndex += 1;
  }

  return { matchedLength, scriptAdvance: ..., transcriptAdvance: ... };
}
```

**为什么限制最多跳 3 字？**
这是一个经验值。跳到太多会导致匹配漂移到完全无关的位置；跳 3 字则可以覆盖绝大多数中文朗读时常见的吞音、连读引起的漏字或多字错误。

**为什么优先跳原稿再跳 ASR？**
从实际数据看，本地识别引擎吞字的情况比多字幻觉常见得多，所以先尝试原稿补偿，成功率更高。

### 5.5 标点过滤与索引映射

为了让算法专注于内容，对齐只在**有效字符**（中文、英文字母、数字）上进行，所有标点、空格等统统忽略。

引擎初始化时，会扫描整篇稿件，构建一个“干净文本”（`cleanScript`）和一张映射表（`indexMap`）。映射表记录了干净文本中每个字符对应原稿的哪个位置。

```typescript
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

通过 `toRawIndex(cleanIndex)` 方法，可以随时把匹配到的干净索引映射回带标点的原稿位置，用于驱动 UI 高亮和滚动。

### 5.6 关键方法总结

| 方法 | 输入 | 输出 | 作用 |
|------|------|------|------|
| `setScript(content)` | 带 HTML 的原稿内容 | void | 初始化引擎，构建干净文本和索引映射 |
| `reset()` | - | void | 重置双指针，重新开始 |
| `setCurrentIndex(rawIndex)` | 原稿中的索引位置 | void | 手动跳转或重置时，同步覆盖锚点和游标 |
| `consumeTranscript(text, isFinal)` | ASR 识别的文本 + 是否最终结果 | 对齐后的原稿索引等结果 | 核心方法，每次 ASR 有结果就调一次 |

---

## 6. 提词器主视图

`TeleprompterView.tsx` 是整个提词器最复杂的组件，约 1570 行。它把控制栏、文本显示、语音识别逻辑、滚动定位都整合在一起。

### 6.1 三种滚动模式

| 模式 | 谁驱动滚动 | 如何控制 |
|------|-----------|---------|
| **手动** | 用户自己用手指或鼠标滚轮拖动 | 不做任何自动推进，ASR 关闭 |
| **自动** | 一个基于 `requestAnimationFrame` 的定时器，按设定的 WPM（每分钟字数）匀速前进 | 根据时间差算出该前进多少个字 |
| **本地 ASR** | 语音识别的对齐结果 | 每收到一个新的识别片段，对齐引擎算出位置，然后滚动到那里 |

### 6.2 自动匀速滚动的实现

自动模式下，我们用浏览器的 `requestAnimationFrame`（RAF）来驱动滚动，保证每秒 60 帧的流畅度。核心逻辑是：

```typescript
useEffect(() => {
  let lastTime = performance.now();
  let accumulator = 0;

  const scroll = (time: number) => {
    if (settings.scrollMode === 'auto' && settings.isScrolling) {
      const deltaTime = time - lastTime;
      lastTime = time;

      const msPerChar = 60000 / settings.wpn;  // 根据 WPM 算出每个字需要的毫秒
      accumulator += deltaTime;

      if (accumulator >= msPerChar) {
        const charsToAdvance = Math.floor(accumulator / msPerChar);
        accumulator %= msPerChar;

        const newIndex = Math.min(totalChars - 1, currentIndexRef.current + charsToAdvance);
        if (newIndex >= totalChars - 1) {
          updateCurrentIndex(0);  // 读完自动回到开头
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

用一个累加器来平滑处理“每字毫秒数”不整除的情况，保证长时间运行不会累积误差。

### 6.3 ASR 语音跟随的生命周期

ASR 什么时候开始、什么时候停止，这是影响用户体验和系统资源的关键。

**启动条件：**

```typescript
const shouldAsrBeOn =
  isVisible &&                          // 提词器视图真的在屏幕上（占 50% 以上可见面积）
  settings.scrollMode === 'local' &&    // 当前选了 ASR 模式
  settings.isScrolling;                 // 播放状态是启动的
```

**启动时的动作：**
1. 调用 ASR 客户端的 `start()` 方法，申请麦克风权限并开始捕获音频。
2. 注册 `onPartial` 回调：每收到一段不完整的识别中间结果，就调对齐引擎消费，更新游标，驱动滚动。
3. 注册 `onFinal` 回调：当识别引擎判断一句话结束时，消费最终结果并提交锚点。
4. 注册 `onRms` 回调：获取音量大小，用来在界面上显示说话音量指示条。

**停止逻辑：**

```typescript
const stopSpeechAsr = useCallback((showToast = false) => {
  setRms(0);
  asrClientRef.current?.stop().catch((error) => {
    if (!showToast) return;
    // 停止出错时只弹一个提示，不打断界面
  });
}, [setToast]);
```

`stop()` 方法是幂等的，如果已经停止，里面会直接返回，不会出错。

**边界与清理：**
- 启动失败：自动把播放状态切回暂停，并弹出错误提示。
- 组件卸载：清理所有定时器，停止 ASR 并释放麦克风。
- 切换到手动或自动模式：同样会安全地停止语音链路。

### 6.4 滚动定位算法：把字送到阅读线上

这是确保“当前朗读行始终在屏幕固定位置”的关键。

**阅读线的定义：**
- 手机端：屏幕可视高度的 30% 处（因为下方有控制栏，稍微偏上一些）。
- 电脑端：屏幕可视高度的 25% 处（更靠上，留出更多前方内容）。

**定位流程：**

```
1. 找出当前目标字（currentIndex）在 HTML 中对应的 <span> 元素
2. 通过 getBoundingClientRect() 获取这个字在屏幕上的坐标
3. 找到这个字所在的那一行（Line）的 DOM 元素，获取其坐标
4. 计算：
   - 阅读线在屏幕上的 Y 坐标 = window.innerHeight * 0.25（PC）
   - 目标字在这一行内的偏移量 = targetRect.top - lineRect.top
   - 目标字在滚动容器内的绝对位置 = lineRect.top - containerRect.top + 字偏移
   - 如果行高度足够，还要限制最大滚动位置，防止底部过早跳出
   - 最终需要的 scrollTop = container.scrollTop + 目标字容器内位置 - (阅读线Y - containerRect.top)
5. 调用 container.scrollTo({ top: targetScrollTop, behavior: 'smooth' }) 平滑滚动
```

**为什么不用绝对定位？**
`scrollTop + (targetTop - readingLineY)` 这种相对计算方式，能保证在用户手动滚过之后再切回自动时，不会出现跳变，而是平滑地继续。

### 6.5 上下“空气垫”设计

提词器的文本容器被包裹在一个特殊的 padding 中：

```tsx
<div className="pt-[65vh] pb-[220vh]">
  {/* 文本内容 */}
</div>
```

- 顶部 65vh 的留白：让第一行文字有足够的空间被滚到阅读线的位置，而不会被容器顶部边界卡住。
- 底部 220vh 的巨大留白：让最后一行文字也能被推到阅读线的高度，让主播可以一直读到最后一个字。

这个“空气垫”让滚动在任何位置都能保持阅读线居中，体验非常自然。

### 6.6 可见性控制：省电又省资源

我们使用 Framer Motion 的 `useInView` Hook 来检测提词器组件在屏幕上的可见比例：

```typescript
const isVisible = useInView(containerRef, { amount: 0.5 });
```

当组件超过一半区域不在屏幕内（比如用户切到了后台或锁屏），`isVisible` 会变为 `false`，从而自动停止 ASR 采集和滚动，释放麦克风和 CPU 资源。一旦提词器重新回到前台，只要其他启动条件也满足，ASR 就会自动重新开启。

### 6.7 控制功能一览

| 功能 | 说明 |
|------|------|
| **字体大小** | 范围 24px～120px，提供 5 个常用预设，也可精细调节 |
| **响应式适配** | 根据当前屏幕宽高自动选择合适的字号、行高和内边距 |
| **镜像翻转** | 通过 CSS 类 `.mirror-mode` 将整个画面水平翻转，适配使用分光镜的场景 |
| **调速（自动模式）** | WPM（字/分钟）范围 60～450，内置几个常用档位，也可自定义 |

---

## 7. 文本渲染层

`TeleprompterTextLayer.tsx` 负责将一篇富文本稿件变成屏幕上一个个可定位、可高亮的字符，并在正确的位置显示格式效果。

### 7.1 从 HTML 到逐字符数组

稿件用 HTML 存储（例如 `<p>大家好，我是<strong>小明</strong>。</p>`）。渲染层需要将它解析为一个个字符，同时记住每个字符的格式。

**解析流程：**
1. 用浏览器的 `DOMParser` 把 HTML 字符串解析为一棵 DOM 树。
2. 递归遍历所有节点，搜集所有文本内容。
3. 对文本节点中的每一个字符，沿着它的父节点一路向上查找，收集沿途的格式标签（如 `<strong>`、`<em>`、`<u>` 以及行内 `font-size` 样式）。
4. 最终生成一个“字符令牌”数组，每个令牌包含字符本身和它的格式描述。
5. 在渲染时，按块级元素（p、div、h1-h6 等）分行，每一行内部是若干 `<span>`，每个 `<span>` 代表一个字，通过 CSS 类应用格式。

收集格式的核心逻辑：

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
          formats.fontSize = parseFloat(match[1]) / 16;  // 相对于 16px 的倍数
          fontSizeFound = true;
        }
      }
    }
    current = current.parentElement;
  }
  return formats;
}
```

### 7.2 高亮与已读效果

由于阅读线固定在屏幕的某条水平线上，文字从下往上滚动。已读过的文字会被自然地推到阅读线上方，视觉上形成“已读”的感觉，不需要额外的高亮颜色变化。每个字使用基本的透明背景和圆角样式，悬停时稍微高亮，方便用户手动点击跳转。

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

### 7.3 富文本格式的完整保留

通过递归收集格式，所有常见的文字样式都能被保留下来：

| 格式 | CSS 实现 |
|------|---------|
| 粗体 | `font-bold` |
| 斜体 | `italic` |
| 下划线 | `underline` |
| 删除线 | `line-through` |
| 自定义字号 | 相对于基字号的倍数，通过内联 style 设置 `font-size` |

---

## 8. ASR 语音识别架构

### 8.1 双引擎策略

系统支持两种语音识别引擎，各有优势：

| 引擎 | 运行在哪里 | 特点 |
|------|-----------|------|
| **Sherpa-Onnx（本地）** | 浏览器内通过 WASM 推理 | 完全离线可用，延迟低，隐私安全 |
| **飞书云 ASR** | 飞书云端服务 | 识别精度更高，但需要网络连接 |

两套引擎遵循统一的接口，可以无缝切换。

### 8.2 统一的 ASR 客户端接口

```typescript
export interface TeleprompterAsrClient {
  start(
    onPartial: (text: string) => void,    // 收到临时结果
    onFinal: (text: string) => void,      // 收到一句话的最终结果
    onRms: (rms: number) => void,         // 实时音量
    onTelemetry?: (sample: AsrLatencySample) => void,  // 性能遥测（可选）
  ): Promise<void>;

  stop(): Promise<void>;
}
```

有了这个抽象，上层提词器组件完全不用关心底层是本地引擎还是云端引擎，只需要注入不同的实现即可。

### 8.3 本地 Sherpa-Onnx 实现细节

**模型加载优化：**
- 整个应用只创建一个识别器实例（单例），避免重复加载几十 MB 的模型文件。
- 采用分阶段加载：先加载 JS 绑定，再加载 WASM 运行时，最后初始化识别器，过程中可以显示进度。
- 支持预加载：用户还在浏览稿件列表时，后台已经开始默默加载模型，进入提词器时大概率已经就绪。

**音频处理流水线：**

利用浏览器的 `ScriptProcessorNode` 处理麦克风实时音频流：
- 缓冲区大小设置为 4096 帧，平衡延迟和处理效率。
- 强制使用 16000 Hz 采样率，这是 Sherpa 模型要求的输入。
- 每次 `onaudioprocess` 事件触发时：
  1. 检查运行状态，已停止则直接返回。
  2. 从输入缓冲区获取一帧 PCM 浮点数据。
  3. 计算这一帧的 RMS（均方根）音量，传给 `onRms` 回调供界面显示。
  4. 将音频数据送入 Sherpa 识别流 (`acceptWaveform`)。
  5. 循环调用 `decode` 直到流中没有更多就绪帧。
  6. 检测端点（VAD），如果当前到达句子结尾，将之前累积的 partial 文本作为 final 结果回调，并重置识别流。

**端点检测（VAD）：**
Sherpa-Onnx 内置了语音活动检测功能，能根据静音时长判断一句话的结束。当检测到端点时，引擎会把之前积攒的临时结果当作一句完整的话提交给对齐引擎，同时重置内部状态准备下一句。

**幂等的清理逻辑：**

```typescript
async stop(): Promise<void> {
  if (!this.isRunning) return;  // 已经停止了，直接返回
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

- 所有清理步骤都做了空值检查，多次调用 `stop()` 绝对安全。
- 关闭 AudioContext 时包了 try-catch，防止在它已经 close 的情况下再 close 抛异常。
- 停止所有媒体轨，确保浏览器释放麦克风权限，别的应用可以正常使用。

### 8.4 飞书云 ASR 集成架构

为了追求识别精度和低延迟，我们采用了**前端直连飞书语音识别接口**的方案，只有获取访问令牌这一步经过后端代理（以保护 AppSecret）：

```
前端 → 后端 /api/feishu-proxy/tenant-access-token → 获得 token
     → 直连飞书 speech_to_text/v1/speech/stream_recognize → 发送音频切片
```

**音频切片策略：**
- 每个切片包含 `CHUNK_SIZE = 3200` 个采样点。
- 发送间隔最低 200ms，防止触发飞书的 QPS 限制。

**排队锁与 QPS 保护：**
- 使用 `isSending` 排队锁，同一时间只有一个切片在发送，避免并发。
- 如果收到飞书返回的 “qps exceeded” 错误，会退避重试。

这套方案兼顾了实时性（少一跳后端转发）和安全性（Secret 不泄露）。

---

## 9. 飞书代理后端

`server/modules/feishu-proxy/` 模块用来代理飞书 API 的认证相关接口。

### 9.1 API 路由

| 方法 | 路径 | 功能 |
|------|------|------|
| POST | `/api/feishu-proxy/tenant-access-token` | 获取飞书租户访问令牌 |
| POST | `/api/feishu-proxy/speech-recognize` | 语音识别代理（备用，当前主要使用前端直连） |

### 9.2 Token 缓存与预过期

飞书的访问令牌有有效期。为了不每次都去请求，后端在内存中缓存 token：

```typescript
const TOKEN_REFRESH_BUFFER_MS = 300000;  // 5 分钟

if (Date.now() >= cached.expiresAt - TOKEN_REFRESH_BUFFER_MS) {
  // 在到期前 5 分钟就认为缓存失效，提前刷新
  this.tokenCache.delete(cacheKey);
  return null;
}
```

这个提前量（5 分钟）保证即便网络稍有延迟，也不会出现使用已过期 token 的情况。

### 9.3 并发请求去重

当多个前端请求几乎同时要求获取 token 时（比如页面刚加载，多个组件一起初始化），后端会：

1. 先查缓存，命中则直接返回。
2. 再查 `pendingTokenRequests` Map，如果已经有相同参数的请求正在进行中，就直接返回那个正在进行的 Promise，避免重复请求飞书。
3. 都没有，才真正发起 HTTP 请求飞书，并把 Promise 存入 pending Map，完成或失败后清除。

这个小小的并发锁极大地保护了飞书 API 的调用配额，也降低了前端的等待时间。

### 9.4 错误处理

| 错误场景 | 处理方式 |
|---------|---------|
| 飞书接口返回非 2xx | 记录日志，向前端抛 `BadGatewayException` |
| 飞书业务码非 0 | 记录 code 和 msg，抛出结构化错误 |
| 网络超时或异常 | 捕获异常，记录日志，抛出网络错误 |
| 语音识别请求出错 | 记录 streamId/sequenceId 方便排查，错误上抛 |

所有飞书代理请求均设置 15 秒超时，防止上游服务假死导致请求堆积。

---

## 10. UI 设计与主题系统

### 10.1 色彩系统

整个应用使用了一套基于 HSL 色彩空间的语义化主题变量，以品牌色 `#DB9D16`（一种温暖的金黄色）为核心，构建出深邃、专业的暗色主题。

**品牌色映射：**

```css
--primary: hsl(42 81% 47%);  /* #DB9D16 */
```

**深色主题基线：**

| 区域 | HSL 值 | 对应十六进制 | 视觉感受 |
|------|--------|--------------|---------|
| 主背景 | `hsl(0 0% 5%)` | `#0d0d0d` | 深沉但不死黑 |
| 卡片/表层 | `hsl(0 0% 8% ~ 9%)` | `#141414 ~ #171717` | 略微浮起，层次分明 |
| 主文字 | `hsl(0 0% 95%)` | `#f2f2f2` | 清晰明亮 |
| 弱文字 | `hsl(0 0% 62%)` | `#9e9e9e` | 次要信息，不喧宾夺主 |
| 边框 | `hsl(0 0% 18%)` | `#2e2e2e` | 低调分隔 |

**完整的 CSS 变量集：**

| 变量 | 用途 |
|------|------|
| `--background` | 页面主背景 |
| `--foreground` | 主文字颜色 |
| `--card` / `--card-foreground` | 卡片背景与文字 |
| `--popover` / `--popover-foreground` | 弹出层 |
| `--primary` / `--primary-foreground` | 品牌色及用于其上的文字 |
| `--secondary` / `--secondary-foreground` | 次要按钮等 |
| `--muted` / `--muted-foreground` | 被弱化的文字 |
| `--border` | 组件边框 |
| `--input` | 输入框边框 |
| `--success` / `--warning` / `--error` | 语义色（成功、警告、错误） |
| `--canvas-bg` / `--surface-bg` / `--terminal-bg` | 特定场景背景 |

### 10.2 品牌色的运用

品牌色出现在这些地方：
- 主要按钮的背景色。
- 聚焦输入框、下拉框等的高亮边框。
- 页面内的链接和可点击高亮文字。
- 侧边栏的活跃项背景。
- 提词器阅读线上方的已读文字高亮（如果需要额外强化）。
- 标签（Badge）和通知徽章。

### 10.3 稿件卡片的视觉设计

首页的稿件列表采用响应式栅格，根据屏幕宽度自动调整列数：

```tsx
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
```

每个卡片：

- 圆角巨大（`rounded-3xl`），半透明背景和超细边框，质感轻盈。
- 悬停时整体向上微移（`hover:-translate-y-1`），同时边框亮起品牌色，带有柔和阴影。
- 右下角放置一个极淡的金色模糊光晕（`bg-yellow-500/5 blur-[60px]`），增强品牌氛围但不抢眼。

**卡片内部布局：**
1. 顶部一个文件图标。
2. 稿件标题，醒目且易读。
3. 三行正文预览，颜色较浅。
4. 底部显示最后修改日期。
5. 悬停时在卡片中央浮现“开始提词”按钮。
6. 编辑和删除按钮默认隐藏（`opacity-0`），仅在悬停时显示，保持界面干净。

---

## 11. 稿件管理

### 11.1 混合存储方案：云端 + 本地

| 存储位置 | 数据来源 | 优点 |
|---------|---------|------|
| **远程稿件** | 后端 API，存入 PostgreSQL | 持久化保存，多设备可同步 |
| **临时稿件** | 浏览器 localStorage | 不登录也能快速创建，离线可用，即用即丢 |

首页会将两份列表合并展示，临时稿件总是显示在最前面，方便快速找到：

```typescript
const scripts = useMemo(
  () => [...temporaryScripts, ...remoteScripts],
  [temporaryScripts, remoteScripts]
);
```

### 11.2 搜索与过滤

搜索框支持实时过滤，不区分大小写，同时匹配标题和正文：

```typescript
const filteredScripts = useMemo(() => {
  return scripts.filter(
    (script) =>
      script.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      script.content.toLowerCase().includes(searchQuery.toLowerCase()),
  );
}, [scripts, searchQuery]);
```

### 11.3 后端 CRUD 接口

| 方法 | 路径 | 是否需要登录 | 功能 |
|------|------|-------------|------|
| GET | `/api/articles` | 否 | 获取所有稿件，按最后修改时间倒序排列 |
| POST | `/api/articles` | 是 | 创建新稿件 |
| PATCH | `/api/articles/:id` | 是 | 修改稿件（支持部分字段更新） |
| DELETE | `/api/articles/:id` | 是 | 删除稿件（找不到返回 404） |

数据库操作通过 Drizzle ORM 完成，所有查询都享受完整的类型检查。创建和更新时自动记录当前登录的用户 ID。

---

## 12. AI 优化能力

### 12.1 它能做什么

在新建或编辑稿件时，用户可以使用“AI 优化正文”功能。它会：
- 自动补全缺失的逗号、句号。
- 将零散的句子整理为标准的中文段落。
- 严格保持原意，只优化标点和段落结构，不改变实质内容。

### 12.2 流式调用与实时预览

为了不让用户干等，优化过程采用了流式调用。每收到一小段结果，就立刻追加到预览区：

```typescript
const handleOptimize = async () => {
  setOptimizing(true);
  setOptimizedPreview('');
  try {
    let nextContent = '';
    for await (const chunk of optimizeTextWithAI(content.trim())) {
      nextContent += chunk;
      setOptimizedPreview(nextContent);  // 实时展示生成过程
    }
    setContent(nextContent.trim());  // 用户确认后应用
  } finally {
    setOptimizing(false);
  }
};
```

优化过程中，“提交”按钮会被禁用，避免用户在半成品时误操作。

### 12.3 预览 UI 设计

- 独立的预览区域，带渐变的金色边框，与普通编辑区明确区分。
- 顶部状态栏显示动画图标和文字：“AI 正在整理……” 或 “本次优化已完成”。
- 预览区可滚动，保留换行格式。
- 底下有说明小字，提醒用户 AI 只调整标点和段落，不会改动原意。

### 12.4 底层插件

实际调用的是 `manuscript_text_optimization_1` 这个内部 AI 插件实例，它被配置在 `server/capabilities/` 中，前后端通过统一的插件调用机制完成流式通信。

---

## 13. 数据库模型

### 13.1 稿件表（article）

| 字段 | 类型 | 含义 |
|------|------|------|
| `id` | UUID | 主键，自动生成 |
| `title` | VARCHAR(255) | 稿件标题 |
| `content` | TEXT | 稿件正文（保存 HTML 富文本） |
| `coverImage` | TEXT | 封面图片的 URL，可为空 |
| `userId` | 自定义类型 user_profile | 稿件创建者 |
| `status` | VARCHAR(255) | 状态，如 draft（草稿）或 published（已发布） |
| `排序` | BIGINT | 排序权重，数值越大约靠前 |
| `createdAt` | TIMESTAMPTZ | 创建时间（带时区） |
| `updatedAt` | TIMESTAMPTZ | 最后更新时间（带时区） |

表上建有按 `status` 和 `userId` 的索引，加速常见查询。

### 13.2 系统设置表（system_setting）

| 字段 | 类型 | 含义 |
|------|------|------|
| `id` | UUID | 主键 |
| `settingsKey` | VARCHAR(255) | 设置键（唯一），用来区分不同配置项 |
| `feishuAppId` | VARCHAR(255) | 飞书应用 ID |
| `feishuAppSecret` | TEXT | 飞书应用密钥（加密存储或需权限控制） |
| `feishuBaseUrl` | TEXT | 飞书 API 基础地址，支持私有化部署 |
| `feishuEngineType` | VARCHAR(255) | 飞书语音引擎类型 |
| `createdAt` | TIMESTAMPTZ | 创建时间 |
| `updatedAt` | TIMESTAMPTZ | 更新时间 |

表中对 `settingsKey` 建有唯一索引，确保不会重复插入同一配置。

### 13.3 自定义类型

| 类型 | 说明 |
|------|------|
| `user_profile` | 用户资料复合类型，包含 `user_id` 字段 |
| `file_attachment` | 文件附件类型，包含 `bucket_id` 和 `file_path` |
| `customTimestamptz` | 带自定义精度的时间戳类型 |

---

## 14. 性能优化策略

### 14.1 视图预挂载

不再通过条件渲染挂载/卸载提词器，而是始终挂载，通过 `display` 切换。进入提词器的延迟从 ~500ms 降到 ~50ms，几乎无感。

### 14.2 副作用隔离

首页的多个初始化逻辑被拆成独立 `useEffect`，避免某个状态（如系统设置）的变化导致不必要的稿件重新拉取或模型重复加载。

### 14.3 ASR 模型预加载

用户还在浏览首页时，Sherpa-Onnx 模型就已经在后台静默加载。加载失败只会打 log，不影响页面正常使用。

### 14.4 Token 并发锁

飞书 token 获取逻辑中，相同参数的并发请求共享一个 Promise，大幅减少对飞书 API 的无效调用。

### 14.5 可见性驱动的 ASR 启停

提词器只在真正被用户看到（超过 50% 面积）时才开启语音识别和麦克风，切到后台自动释放资源，省电又省流量。

### 14.6 RAF 驱动滚动

自动滚动和语音跟随滚动的动画都跑在 `requestAnimationFrame` 里，确保与浏览器刷新率同步，不丢帧。

---

## 15. 边界情况与容错

### 15.1 ASR 容错设计

| 场景 | 对策 |
|------|------|
| ASR 漏字（吞字） | 允许跳过原稿最多 3 个字符继续匹配 |
| ASR 多字（幻觉） | 允许跳过识别文本最多 3 个字符继续匹配 |
| 标点不一致 | 忽略所有标点，只在有效字符上做对比 |
| 中间结果漂移 | 始终从最后确认的锚点开始重算，锚点不动 |

### 15.2 滚动边界保护

| 场景 | 对策 |
|------|------|
| 第一句无法滚到阅读线 | 顶部留 65vh 空气垫 |
| 最后一句被底部卡住 | 底部留 220vh 空气垫 |
| 文本行过长导致底部过早露出 | 设置最大滚动值，限制在段落底部减去 3 行的高度 |

### 15.3 资源安全清理

| 场景 | 对策 |
|------|------|
| 暂停滚动 | 立即停止语音采集和处理 |
| 退出稿件 | 停止 ASR，释放麦克风 |
| 切换模式 | 清空识别队列，取消进行中的网络请求 |
| 组件卸载 | 清理所有定时器和资源，`stop()` 幂等 |

### 15.4 网络异常处理

| 场景 | 对策 |
|------|------|
| 飞书 API 返回错误 | 后端返回 502 状态码并携带结构化错误信息 |
| 网络超时 | 所有请求 15 秒超时，返回明确错误 |
| 获取 token 失败 | 前端提示用户检查飞书配置，不会无限重试 |

### 15.5 麦克风权限处理

| 场景 | 对策 |
|------|------|
| 非 HTTPS 环境 | 安全上下文要求，直接提示用户错误 |
| 浏览器不支持 `getUserMedia` | 提示浏览器版本过旧 |
| 用户拒绝权限 | 完整清理后抛错，不会残留未释放的流 |

---

## 16. 核心调用链路

### 16.1 提词器语音跟随模式的全流程

```
首页 (Home)
  ↓ 用户点击“开始提词”
提词器主视图 (TeleprompterView)
  ↓ 根据设置初始化 ASR 客户端
SherpaOnnxAsrClient 或 FeishuASRClient (采集麦克风音频)
  ↓ 识别到文字后触发 onPartial / onFinal 回调
对齐引擎 (TeleprompterAlignment.consumeTranscript)
  ↓ 双指针算法计算出原稿中的匹配索引
文本渲染层 (TeleprompterTextLayer)
  ↓ 更新 currentIndex，触发滚动定位
getBoundingClientRect() + scrollTo() → 文字平滑滚动到阅读线
```

### 16.2 飞书 Token 获取流程

```
前端请求 /api/feishu-proxy/tenant-access-token
  ↓
后端 FeishuProxyController
  ↓
FeishuProxyService.getTenantAccessToken()
  ↓ 1. 检查缓存
缓存命中 → 直接返回
  ↓ 未命中 → 2. 检查 pending 请求
有 pending → 复用 Promise
  ↓ 无 pending → 3. 真正请求飞书
飞书 /auth/v3/tenant_access_token/internal
  ↓ 缓存结果，清理 pending 状态
返回前端
```

### 16.3 AI 优化正文流程

```
用户在编辑器点击“AI 优化正文”
  ↓
ArticleCreateDialog / ArticleEditDialog
  ↓ 调用 optimizeTextWithAI(content)
流式调用 manuscript_text_optimization_1 插件
  ↓ 每收到一个 chunk
更新 optimizedPreview 状态，界面实时增长
  ↓ 全部生成完毕
用户确认 → 将优化后的文本应用到稿件正文
```

---

## 附录：关键文件及职责速查

| 文件路径 | 大约行数 | 核心功能 |
|---------|---------|---------|
| `client/src/pages/Home/Home.tsx` | ~500 | 首页主容器，负责视图切换、稿件管理、初始化调度 |
| `client/src/components/teleprompter/TeleprompterView.tsx` | ~1570 | 提词器主视图，汇集控制、文本、语音和滚动所有功能 |
| `client/src/components/teleprompter/TeleprompterTextLayer.tsx` | ~570 | 文本渲染层，HTML 解析为逐字高亮并驱动定位 |
| `client/src/lib/teleprompter/alignment/engine.ts` | ~252 | 对齐引擎核心，双指针字符匹配算法 |
| `client/src/lib/teleprompter/asr-client.ts` | 少 | ASR 客户端抽象接口 |
| `client/src/lib/teleprompter/sherpa-asr-client.ts` | 中等 | Sherpa-Onnx 本地识别实现 |
| `client/src/components/teleprompter/ScriptEditor.tsx` | ~2981 | 脚本编辑器，含富文本编辑与 AI 优化交互 |
| `server/modules/feishu-proxy/feishu-proxy.service.ts` | ~263 | 飞书 API 代理服务，含 token 缓存和并发去重 |
| `server/modules/article/article.controller.ts` | 中等 | 稿件 CRUD 控制器 |
| `server/modules/article/article.service.ts` | 中等 | 稿件数据库操作 |
| `server/modules/system-settings/` | 小 | 系统设置的存储与读取 |
| `shared/api.interface.ts` | ~119 | 前后端共享的请求/响应类型定义 |
| `server/database/schema.ts` | 中等 | Drizzle ORM 建表 schema |

---

*报告编写时间：2026-06-05*
*基于飓风提词器 v1.0 代码库深入分析*