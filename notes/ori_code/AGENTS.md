# Gemini 平台导出项目迁移任务

## 任务描述

这是一个从Gemini平台导出的项目迁移到妙搭平台的任务，迁移工作已经完成了文件合并，两个平台的环境差异和具体文件合并规则可以参考**环境差异**和**文件结构**章节，请按照**迁移任务**章节执行具体的迁移任务。
**注意**: 直接开始执行迁移任务，不需要再向用户澄清是否需要迁移。迁移范围只包括前端代码，排除服务端代码。

## 环境差异

| 项目     | 源             | 目标   |
| -------- | -------------- | ------ |
| React    | 19             | 19     |
| Tailwind | CDN + 内联配置 | 4      |
| 构建工具 | Vite           | Rspack |

## 文件结构

### 迁移映射表

| Gemini 源路径   | 合并后位置                    | 说明                             |
| --------------- | ----------------------------- | -------------------------------- |
| `components/**` | `client/src/components/**`    | 组件目录，直接可用               |
| `services/**`   | `client/src/services/**`      | 服务目录（含 geminiService）     |
| `types.ts`      | `client/src/types.ts`         | 类型定义                         |
| `constants.ts`  | `client/src/constants.ts`     | 常量定义                         |
| `App.tsx`       | `source_package/App.tsx`      | 原入口组件，需参考其结构创建页面 |
| `index.tsx`     | `source_package/index.tsx`    | 原入口文件，不需要               |
| `index.html`    | `source_package/index.html`   | 含 Tailwind 主题配置，需提取     |
| `package.json`  | `source_package/package.json` | 依赖已合并，不需要               |
| 其他文件        | `source_package/**`           | 隔离，按需参考                   |

## 迁移任务

### 1. 主题配置（关键）

读取 `source_package/index.html` 中的 `tailwind.config` 配置，将颜色和字体变量写入 `client/src/tailwind-theme.css`。

**源配置位置**：`source_package/index.html` 中的 `<script>tailwind.config = {...}</script>`

**转换示例**：

```javascript
// 源：index.html 中的 tailwind.config
colors: {
  brand: {
    black: '#0a0a0a',
    dark: '#121212',
    accent: '#00dc82',
    silver: '#e5e5e5',
  }
}
```

```css
/* 目标：tailwind-theme.css 的 :root 块中添加 */
:root {
  /* 保留原有变量... */

  /* Gemini 主题 */
  --brand-black: #0a0a0a;
  --brand-dark: #121212;
  --brand-accent: #00dc82;
  --brand-silver: #e5e5e5;
}

@theme inline {
  --color-brand-black: var(--brand-black);
  --color-brand-dark: var(--brand-dark);
  --color-brand-accent: var(--brand-accent);
  --color-brand-silver: var(--brand-silver);
}
```

**字体配置**：从 `source_package/index.html` 的 `<head>` 中复制 Google Fonts 链接到 `client/index.html`。

**内联样式**：从 `source_package/index.html` 的 `<style>` 标签中提取 CSS（如字体设置、滚动条样式等），添加到 `client/src/index.css` 末尾。

```css
/* 示例：从 <style> 标签提取 */
body {
  font-family: "Inter", "Noto Sans SC", sans-serif;
}
.scrollbar-hide::-webkit-scrollbar {
  display: none;
}
```

### 2. 创建页面入口（关键）

参考 `source_package/App.tsx` 的页面结构，创建 `client/src/pages/Home/Home.tsx`：

**步骤**：

1. 读取 `source_package/App.tsx` 了解页面布局
2. 创建 `client/src/pages/Home/Home.tsx`
3. 导入 `client/src/components/` 下的组件
4. 复制 `source_package/App.tsx` 中的完整 JSX 结构（**保留外层 div 及其所有类名**，如 `className="min-h-screen flex flex-col"` 是布局必需的）

**示例**：

```tsx
// client/src/pages/Home/Home.tsx
import { useState } from "react";
import { Hero } from "@/components/Hero";
import { ChatWidget } from "@/components/ChatWidget";

const Home = () => {
  const [isModalOpen, setIsModalOpen] = useState(false);

  return (
    <div className="min-h-screen flex flex-col">
      {" "}
      {/* 保留外层 div 和类名 */}
      <nav className="...">...</nav>
      <main className="flex-grow">
        <Hero onRegister={() => setIsModalOpen(true)} />
        {/* 从 source_package/App.tsx 复制其他内容 */}
      </main>
      <footer className="...">...</footer>
      <ChatWidget />
    </div>
  );
};

export default Home;
```

### 3. 更新路由（关键）

修改 `client/src/app.tsx`，添加 Home 页面路由：

```tsx
import Home from "./pages/Home/Home";

const RoutesComponent = () => {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Home />} />
      </Route>
      <Route path="*" element={<NotFound />} />
    </Routes>
  );
};
```

### 4. 修复组件导入路径

组件已迁移到 `client/src/`，需要修复内部的相对路径导入：

**示例**

```tsx
// 源（组件中）
import { SPECS } from "../constants";
import { PaintOption } from "../types";

// 目标
import { SPECS } from "@/constants";
import { PaintOption } from "@/types";
```

### 5. 迁移 Gemini AI 服务至妙搭 AI 插件（关键）

`client/src/services/geminiService.ts` 使用了 `@google/genai`，需要迁移为妙搭 AI 插件能力。

**原服务功能分析**：

| 原函数 | 功能 | 对应妙搭插件 |
| --- | --- | --- |
| `generateNoteText(topic)` | 生成结构化文本（标题、内容、图片提示词） | AI智能生文 |
| `generateNoteImage(imagePrompt)` | 根据提示词生成图片 | AI智能生图 |

**迁移步骤**：

1. **召回插件文档**：调用 `steering_doc_search` 获取 `plugin_guide`，查看 AI 智能生文、AI 智能生图的可用插件
2. **检查或创建插件实例**：
   - 先检查 `available_plugin_instances` 是否有可复用的插件实例
   - 若无合适的插件实例，调用 `plugin_instance` 工具（operType=CREATE）基于可用插件创建新的 PluginInstance（如 `xhsTextGen`、`xhsImageGen`）
   - **注意**：必须通过 `plugin_instance` 工具创建，**禁止**直接修改 `server/capabilities/` 目录
3. **获取插件规格**：对插件实例调用 `get_plugin_ai_json(pluginInstanceId)`，获取 `actions[].key / inputSchema / outputSchema / outputMode`
4. **生成客户端调用代码**：默认在 Client 侧直接调用插件，严格按照 `get_plugin_ai_json` 返回的 schema 构造参数

**代码生成**：

根据 `get_plugin_ai_json` 返回的 `outputMode` 选择调用方式，在 `client/src/services/aiService.ts` 中实现：
- `outputMode = unary`：使用 `capabilityClient.load(id).call(actionKey, input)`
- `outputMode = stream`：使用 `capabilityClient.load(id).callStream(actionKey, input)`

具体调用示例参考召回的 `plugin_guide` 文档中的 **Client 侧调用方式** 章节。

**注意**：
- 调用插件前**必须**通过 `get_plugin_ai_json(pluginInstanceId)` 获取 actions/inputSchema/outputSchema，禁止猜测参数结构
- 插件调用**默认在 Client 侧**，除非有明确的后端需求（如触发器、敏感凭证、强事务）
- **禁止**使用 `multi_edit` 或 `write` 工具直接修改 `server/capabilities/` 目录

### 6. 环境变量

- `import.meta.env` → `process.env`
- `process.env.API_KEY` 需要在 `.env` 中配置（或 Mock 后不需要）

### 当前补充说明

- 当前稿件列表接口 `/api/articles` 展示全部稿件，不按当前登录用户过滤。
- 当前 Home 页面已改为常驻挂载 manager / prompter / editor 三种视图，通过显隐切换替代条件 return，减少进入提词器与编辑器时的初始化延迟；同时已拆分首页初始化副作用，避免 globalSettings 变化时重复拉取稿件与系统设置导致额外卡顿，并为首页 token 保鲜增加并发锁，避免同一时段重复请求飞书 tenant-access-token。
- 当前 `TeleprompterView` 在预挂载场景下使用可见性判断控制飞书 ASR 启停，仅在提词器视图实际可见时启动语音链路；`ScriptEditor` 已支持随稿件切换同步本地编辑态。
- 当前新建稿件弹窗已移除封面图输入，仅保留标题与正文；同时支持"AI 优化正文"按钮，前端通过 `manuscript_text_optimization_1` 插件实例流式优化口语化正文，自动补齐逗号句号、整理为标准中文段落，并在弹窗内实时展示优化预览。
- 当前编辑稿件弹窗也已复用同一套"AI 优化正文"能力：保留标题、封面图 URL、正文编辑，同时支持流式优化正文并展示优化预览，优化期间禁止提交保存。

- 当前应用已新增 `server/modules/feishu-proxy` 后端代理模块。
- 前端通过 `/api/feishu-proxy/tenant-access-token` 获取 tenant access token，避免在浏览器直接请求飞书 token 接口。
- 当前飞书 ASR 采用前端直连飞书接口链路：前端先通过 `/api/feishu-proxy/tenant-access-token` 获取 token，再直接请求飞书 `speech_to_text/v1/speech/stream_recognize`；后端不再参与 ASR 音频逐片转发。
- 当前系统设置侧边栏新增底部"保存设置"按钮，App ID、App Secret、Base URL、引擎类型在点击保存后会写入后台 `system_setting` 表，并同步更新本地缓存作为回退。

- 提词器对齐引擎 TeleprompterAlignment 已按流式 ASR 累加文本模式重构：
  - 使用 `anchorIndex` 与 `currentIndex` 双指针管理句首锚点和实时游标，非 final 结果始终从锚点重算，final 结果才提交锚点。
  - 引擎初始化时构建 `cleanScript` 与 `indexMap`，底层比对仅在去标点后的干净文本上执行，再映射回原稿索引供 UI 渲染。
  - 字符级匹配使用最多 3 字的双向跳字容错，处理 ASR 吞字与幻觉，避免依赖 `indexOf` / `includes`。
  - 新增 `setCurrentIndex(rawIndex)` 支持手动点击/跳转时同步覆盖引擎锚点，避免人工干预后匹配链路卡死。
  - 脚本切换时重置游标与调试统计，并同步调用 alignmentEngine.setScript。
- 当前 `FeishuASRClient.stop()` 已改为幂等清理：发送结束尾包失败仅记录 warn 日志，不再向 React 渲染层抛出未捕获错误；提词器视图中的 stop 调用统一捕获 Promise 异常。
- 当前飞书配置入口已增加前置校验：当 App ID 或 App Secret 为空时，系统设置中的"测试 API"和进入提词器前的 token 预加载会直接提示用户补全配置，不再向 `/api/feishu-proxy/tenant-access-token` 发送空参数请求。
- 当前飞书 token 代理在上游飞书接口非 2xx、网络异常或超时时，会在后端记录带 appId/baseUrl/status 的错误日志，并统一以 502 + 结构化错误信息返回前端，前端优先展示后端返回的详细失败原因。
- 当前提词器在阅读进度推进到稿件末尾时会自动重置游标与已读样式，不再保留"读到哪里"的完成态位置。
- 当前提词器在云 ASR 模式下暂停滚动或退出稿件时，会立即停止语音链路并释放麦克风资源，避免浏览器持续占用录音设备。
- 当前提词器在停止或退出页面时，会主动清空飞书 ASR 队列、取消进行中的识别请求并清理重试/限流定时器，避免残留请求继续发送。
- 当前提词器切换到手动、自动、云 ASR 任意模式后均默认保持暂停状态，必须由用户主动点击播放后才开始滚动或采集语音。
- 当前飞书 ASR 发送链路保留 `isSending` 排队锁、最小请求间隔与 `qps exceeded` 单次退避重试作为保护；当前测试态已恢复 200ms 极速切片（`CHUNK_SIZE=3200`）、将最小请求间隔下调为 200ms，并把静音结束阈值放宽到 10 个静音切片，兼顾识别时延与停顿容错。
- 当前提词器滚动定位已统一到 `TeleprompterView` 与 `TeleprompterTextLayer`：阅读线固定在视口 25% 高度，正文滚动统一基于当前焦点字或活动行元素的 `getBoundingClientRect()` 计算屏幕绝对坐标，并以 `currentScrollTop + (targetCenterTop - readingLineTop)` 的误差补偿方式执行 `scrollTo`；同时正文容器统一加厚为 `pt-[65vh]` 与 `pb-[220vh]` 空气垫，避免第一句与最后一句被浏览器滚动边界卡住。
- 当前深色品牌基线为：主背景接近 `#0d0d0d`（`--background` / `--canvas-bg`），卡片与表层接近 `#141414` ~ `#171717`（`--card` / `--surface-bg` / `--terminal-bg`），主文字接近 `#f2f2f2`，弱文字接近 `#9e9e9e`，边框接近 `#2e2e2e`，主色保持 `#DB9D16`。

### 7. 依赖库检查

以下依赖**已内置于脚手架**：

- `lucide-react` - 图标库
- `react` / `react-dom` - React 19

**需要注意**：`@google/genai` 不在脚手架中，需迁移为妙搭 AI 插件（见任务 5）

---

## 迁移顺序建议

1. **主题配置** - 修改 tailwind-theme.css 和 index.html
2. **修复导入路径** - 修改 components/ 和 services/ 中的导入
3. **迁移 AI 服务** - 将 geminiService.ts 迁移为妙搭 AI 插件调用
4. **创建页面** - 创建 pages/Home/Home.tsx
5. **更新路由** - 修改 app.tsx
6. **编译测试** - 运行 `npm run build` 检查错误

---

## 常见编译错误及修复

| 错误                                 | 原因       | 修复                              |
| ------------------------------------ | ---------- | --------------------------------- |
| `Cannot find module '@google/genai'` | 平台依赖   | 迁移为妙搭 AI 插件（见任务 5）    |
| `Cannot find module '../constants'`  | 路径变化   | 改为 `@/constants`                |
| `Cannot find module '../types'`      | 路径变化   | 改为 `@/types`                    |
| `bg-brand-accent` 无效               | 主题未配置 | 添加到 tailwind-theme.css         |

---

## 约束

**禁止**：

- 修改 package.json
- 引入新依赖
- 重新创建已存在的组件（组件已在 `components/` 目录）