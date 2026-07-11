# 项目架构

## 运行时分层

- `lib/backend/`：本地 WebSocket 服务端、请求分发、持久化服务和提词会话状态。
- `lib/frontend/`：WebSocket 客户端传输层。
- `lib/providers/`：面向 UI 的状态，以及对后端请求的编排。
- `lib/pages/`：页面组合和页面级交互逻辑。
- `lib/widgets/`：可复用组件和复杂渲染组件。
- `lib/services/`：导入导出、文本解析、对齐、字体、网络信息和 ASR 等平台或领域服务。
- `lib/models/`：可序列化的应用与稿件数据模型。

UI 通过 Provider 读取和修改数据。Provider 统一通过 `ConnectionProvider` 与后端通信，页面不应直接访问存储服务。

## 启动流程

1. `main.dart` 在支持的平台启动内置后端。
2. 创建 Provider，并绑定共享的 `ConnectionProvider`。
3. 客户端连接内置后端。
4. 加载稿件、文件夹和应用设置。
5. `StormTeleprompterApp` 将 Provider 注入 Widget 树。

## 提词器数据流

- `TeleprompterProvider` 管理播放状态、当前字、自动滚动和转录对齐状态。
- `TeleprompterPage` 管理键盘、指针、全屏和可见控制栏交互。
- `TeleprompterTextLayer` 管理文字测量、懒加载渲染和视口定位。
- `SettingsProvider` 合并全局设置与当前稿件的提词器覆盖设置。
- `TeleprompterSession` 向已连接客户端分发当前稿件、播放位置和同步设置。

文字测量和滚动逻辑应留在前端渲染层；传输和持久化逻辑不应进入 Widget。

## ASR 接入边界

当前 ASR 包含三个职责：

- `asr_service.dart`：按平台选择原生实现或不支持平台的占位实现。
- `asr_service_native.dart`：管理模型文件、识别器生命周期和 PCM 样本处理。
- `alignment_engine.dart`：将临时/最终转录文本映射为稿件原始字符位置。

后续麦克风采集应向 ASR 服务输入标准化的单声道 PCM 样本，不应直接修改当前字。转录结果继续经过对齐引擎，只有对齐后的稿件原始索引可以进入 `TeleprompterProvider`。

扩展 ASR 时应保持以下职责独立：

1. 音频采集与权限处理。
2. 模型下载、加载和识别器生命周期。
3. 转录事件、状态和错误上报。
4. 转录文本与稿件的对齐。
5. 提词器播放状态与多端同步。

该边界允许单独测试音频采集和语音识别，而不改变已经稳定的滚动及远程会话行为。
