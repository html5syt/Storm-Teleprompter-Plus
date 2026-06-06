# 飓风提词器 Plus

基于 Flutter 框架构建的跨平台智能提词器应用，从原始 React + NestJS 项目完整移植。

## ✨ 特性

- **三种滚动模式**：手动滚动 / 自动滚动 / ASR 语音识别自动滚动
- **ASR 语音识别**：使用 sherpa-onnx 原生插件，支持多种中文模型，国内镜像加速下载
- **逐字符对齐引擎**：双指针字符级匹配算法，3 字符跳过容差处理 ASR 识别误差
- **富文本支持**：HTML 格式解析，保留粗体/斜体/下划线/删除线/字号
- **镜像翻转**：支持提词器分光镜场景
- **全屏模式**：沉浸式显示，自动隐藏控制面板
- **本地存储**：SharedPreferences 本地持久化，无需后端服务
- **跨平台**：Android / iOS / Windows / macOS / Linux / Web

## 🏗 项目结构

```
lib/
├── main.dart                          # 应用入口
├── models/
│   ├── article.dart                   # 稿件数据模型
│   ├── app_settings.dart              # 应用设置模型
│   └── script_character.dart          # 逐字符脚本模型（含格式信息）
├── services/
│   ├── storage_service.dart           # 本地存储服务（SharedPreferences）
│   ├── alignment_engine.dart          # ASR 对齐引擎（双指针字符匹配）
│   ├── asr_service.dart               # 语音识别服务（sherpa-onnx）
│   └── text_parser.dart               # HTML/纯文本解析器
├── providers/
│   ├── article_provider.dart          # 稿件状态管理
│   ├── settings_provider.dart         # 设置状态管理
│   └── teleprompter_provider.dart     # 提词器核心状态管理
├── pages/
│   ├── home_page.dart                 # 首页 UI 布局
│   ├── home_logic.dart                # 首页业务逻辑（mixin）
│   ├── settings_page.dart             # 设置页面
│   ├── teleprompter_page.dart         # 提词器页面 UI 布局
│   ├── teleprompter_logic.dart        # 提词器业务逻辑（mixin）
│   ├── editor_page.dart               # 稿件编辑页面 UI 布局
│   └── editor_logic.dart              # 编辑器业务逻辑（mixin）
├── widgets/
│   └── teleprompter_text_layer.dart   # 提词器文本渲染层（含 LineSnapScrollPhysics）
├── theme/
│   ├── app_colors.dart                # 品牌色彩体系
│   └── app_theme.dart                 # Material 3 主题配置
└── utils/
    └── constants.dart                 # 全局常量
```

## 🚀 快速开始

### 环境要求

- Flutter 3.12+
- Dart 3.12+

### 安装运行

```bash
# 获取依赖
flutter pub get

# 运行（选择目标平台）
flutter run                    # 默认设备
flutter run -d chrome          # Web
flutter run -d windows         # Windows 桌面
flutter run -d android         # Android
```

### ASR 语音识别

首次使用 ASR 模式时，需要在设置页面下载语音识别模型：

1. 进入 设置 → ASR 语音识别 → 选择模型
2. 支持的模型：
   - **Paraformer 中文**：适合大多数中文场景（推荐）
   - **流式 Paraformer**：实时性更好
   - **Whisper Tiny**：适合低性能设备
3. 下载支持国内镜像加速

## 🎨 设计规范

- **品牌色**：#DB9D16（金色）
- **深色主题**：背景 #0D0D0D，表面 #141414
- **Material Design 3** 组件体系

## 📝 技术说明

- **状态管理**：Provider + ChangeNotifier
- **本地持久化**：SharedPreferences JSON 序列化
- **ASR 引擎**：sherpa-onnx 原生插件（替代原项目 WASM 方案）
- **对齐算法**：双指针逐字符匹配，3 字符跳过容差，24 字符窗口重同步
- **文本解析**：自定义 HTML 状态机解析器，按字符保留格式信息
- **全屏**：SystemChrome immersiveSticky + 自动隐藏定时器

## 📄 许可

Private Project
- 模型管理：支持预置模型和自定义模型地址，支持镜像源下载。
- 语音接口：通过可插拔的 ASR 服务接入本地识别引擎；当前工程内同时提供演示回放实现，便于跨平台调试。

## 结构

- `lib/main.dart`：应用入口。
- `lib/app/`：应用主题和根节点。
- `lib/core/models/`：稿件、设置、模型等核心数据结构。
- `lib/core/controllers/`：全局状态和对齐逻辑。
- `lib/core/services/`：本地持久化、模型下载、ASR 服务和文本解析。
- `lib/features/home/`：主界面、稿件面板、模型面板。
- `lib/features/editor/`：脚本编辑器。
- `lib/features/teleprompter/`：提词器渲染与滚动控制。

## 运行方式

1. 打开项目后执行 Flutter 运行命令。
2. 进入主界面后可直接选择样例稿件开始预览。
3. 在右侧或设置页调整字体、速度、镜像和语音跟随参数。
4. 在模型管理中选择预置模型，或填写自定义模型 URL 后下载。

## 关于语音跟随

原始 Web 版使用了 Sherpa-Onnx WASM 方案。当前 Flutter 版本将语音识别抽象为独立服务，应用侧已经接入 Native Sherpa 方法通道和演示回放服务。这样可以在不同平台上保持统一的上层逻辑，同时为后续补齐原生插件实现留出清晰边界。

## 数据存储

稿件、当前选项和基础设置会以本地 JSON 形式保存：

- Windows 和其他桌面平台：写入本地用户目录。
- Web：写入浏览器 localStorage。

## 说明

- 项目不再包含飞书相关业务逻辑。
- 项目内所有主流程都围绕 Flutter 组件、控制器和服务层组织，不再依赖 React/NestJS 架构。
- 如果你要接入真正的 Sherpa-Onnx 原生识别，只需要在 `storm_teleprompter_plus/sherpa_asr` 方法通道下补齐平台侧实现即可。
