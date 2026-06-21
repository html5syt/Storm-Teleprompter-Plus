# Storm Teleprompter Plus (Flutter) - 系统架构

## 简洁版架构图

```mermaid
graph TB
    subgraph "应用入口层"
        A["main.dart<br/>(应用启动&Provider配置)"]
    end
    
    subgraph "表现层 UI Pages"
        A --> B["HomePage<br/>(首页导航)"]
        A --> C["EditorPage<br/>(稿件编辑)"]
        A --> D["TeleprompterPage<br/>(提词器播放)"]
        A --> E["SettingsPage<br/>(应用设置)"]
    end
    
    subgraph "状态管理层 Providers"
        B & C & D & E --> F["ArticleProvider<br/>(稿件数据)"]
        B & C & D & E --> G["SettingsProvider<br/>(应用设置)"]
        B & C & D & E --> H["TeleprompterProvider<br/>(播放控制)"]
    end
    
    subgraph "业务逻辑层 Services"
        F --> I["StorageService<br/>(本地存储)"]
        G --> I
        H --> J["AsrService<br/>(语音识别)"]
        H --> K["TextParser<br/>(文本解析)"]
        H --> L["AlignmentEngine<br/>(对齐引擎)"]
    end
    
    subgraph "数据模型层 Models"
        F --> M["Article"]
        G --> N["AppSettings<br/>ScriptCharacter"]
        K --> O["ScriptCharacter"]
    end
    
    subgraph "本地存储层"
        I --> P["JSON Files<br/>(Desktop)<br/>LocalStorage<br/>(Web)"]
    end
    
    subgraph "核心控制层"
        H --> Q["TeleprompterController<br/>(播放逻辑)"]
    end
    
    subgraph "UI 组件层 Widgets"
        D --> R["TeleprompterTextLayer<br/>(文本渲染)"]
        D --> S["TeleprompterSettingsPanel<br/>(设置面板)"]
        E --> T["ColorPickerUI<br/>(颜色选择)"]
    end
    
    Q --> J & K & L
    
    style A fill:#FF6B6B
    style F fill:#4ECDC4
    style G fill:#4ECDC4
    style H fill:#4ECDC4
    style P fill:#95E1D3
```

---

## 详细版架构图

```mermaid
graph TB
    subgraph "应用启动层"
        A["main.dart<br/>├─ WidgetsFlutterBinding初始化<br/>├─ MultiProvider配置<br/>└─ Material App 主题应用"]
    end
    
    subgraph "页面层 Pages & Logic"
        direction LR
        B["HomePage<br/>├─ 稿件列表展示<br/>├─ 文件夹导航<br/>└─ 快速操作"]
        C["EditorPage + EditorLogic<br/>├─ 富文本编辑<br/>├─ 自动保存3s<br/>├─ WYSIWYG预览<br/>└─ 背景色标注"]
        D["TeleprompterPage + TeleprompterLogic<br/>├─ 播放UI主界面<br/>├─ 全屏控制<br/>├─ 快捷键处理<br/>└─ 窗口事件监听"]
        E["SettingsPage<br/>├─ 全局设置<br/>├─ 颜色主题选择<br/>├─ ASR模型管理<br/>├─ 镜像URL配置<br/>└─ 其他参数调节"]
    end
    
    subgraph "状态管理层 State Management"
        F["ArticleProvider<br/>├─ CRUD操作<br/>├─ 文件夹管理<br/>├─ 拖拽排序<br/>└─ 观察者模式"]
        G["SettingsProvider<br/>├─ 全局应用设置<br/>├─ 每稿独立覆盖<br/>├─ mergedSettings<br/>└─ 自动保存"]
        H["TeleprompterProvider<br/>├─ 播放状态管理<br/>├─ 速度控制<br/>├─ 滚动位置<br/>├─ 识别状态<br/>└─ 模式切换"]
    end
    
    subgraph "核心业务逻辑层"
        Q["TeleprompterController<br/>├─ 播放暂停逻辑<br/>├─ 速度计算<br/>├─ 自动滚动算法<br/>├─ 手动滚动处理<br/>└─ 识别结果对齐"]
    end
    
    subgraph "服务层 Services"
        I["StorageService<br/>├─ 跨平台文件I/O<br/>├─ Desktop: AppDir<br/>├─ Web: localStorage<br/>└─ JSON序列化"]
        J["AsrService extends ChangeNotifier<br/>├─ 模型下载&管理<br/>├─ 原生Plugin调用<br/>├─ 流式识别处理<br/>├─ 下载进度追踪<br/>└─ 镜像URL支持"]
        K["TextParser<br/>├─ HTML解析<br/>├─ 背景色提取<br/>├─ 字符流生成<br/>└─ 样式标签转换"]
        L["AlignmentEngine<br/>├─ 原始文本→字符数组<br/>├─ 识别结果匹配<br/>├─ 位置映射计算<br/>└─ 进度条数据"]
    end
    
    subgraph "数据模型层 Models"
        M["Article<br/>├─ id, title, content<br/>├─ createdAt, updatedAt<br/>├─ sortOrder<br/>├─ folderId<br/>└─ teleprompterSettings"]
        N["AppSettings<br/>├─ 字体大小/族<br/>├─ 速度/播放模式<br/>├─ 颜色主题<br/>├─ paddingX<br/>├─ readingLineOffset<br/>└─ asrMirrorUrl"]
        O["ScriptCharacter<br/>├─ char: String<br/>├─ original: bool<br/>├─ isNonPrintable<br/>└─ backgroundColor"]
    end
    
    subgraph "UI 组件层 Widgets"
        R["TeleprompterTextLayer<br/>├─ ListView.builder渲染<br/>├─ 字符级别样式<br/>├─ 背景色渲染<br/>├─ 阅读区域框<br/>└─ 进度信息显示"]
        S["TeleprompterSettingsPanel<br/>├─ 340px覆盖面板<br/>├─ 提词器设置section<br/>├─ 应用设置section<br/>└─ 滑块&颜色选择"]
        T["UI 组件库<br/>├─ flutter_colorpicker<br/>├─ Material3 widgets<br/>├─ 字体选择对话框<br/>└─ 速度预设对话框"]
    end
    
    subgraph "主题&样式层"
        U["AppColors<br/>├─ primaryFromSettings<br/>├─ teleprompterBgFromSettings<br/>└─ 预设颜色映射"]
        V["AppTheme<br/>├─ fromColor工厂方法<br/>└─ Material3主题生成"]
    end
    
    subgraph "本地存储层"
        P["StorageBackend<br/>├─ Desktop: ~/.storm/<br/>│  ├─ articles.json<br/>│  ├─ settings.json<br/>│  └─ asr_models/<br/>└─ Web: Browser<br/>   ├─ localStorage<br/>   └─ IndexedDB"]
    end
    
    subgraph "平台层"
        NATIVE["原生插件<br/>├─ sherpa_onnx<br/>│  └─ ASR语音识别<br/>├─ window_manager<br/>│  └─ 窗口控制<br/>├─ path_provider<br/>│  └─ 文件路径<br/>├─ shared_preferences<br/>│  └─ 轻量存储<br/>├─ record<br/>│  └─ 音频录制<br/>├─ http<br/>│  └─ 模型下载<br/>└─ archive<br/>   └─ 压缩包解压"]
    end
    
    A --> B & C & D & E
    B & C & D & E --> F & G & H
    H --> Q
    F --> I & M
    G --> N
    Q --> J & K & L & O
    K --> O
    D --> R & S & H
    E --> T & N & G
    S & R --> U & V
    I --> P
    J --> P
    P --> NATIVE
    L --> Q
    
    style A fill:#FF6B6B,color:#fff
    style F fill:#4ECDC4,color:#fff
    style G fill:#4ECDC4,color:#fff
    style H fill:#4ECDC4,color:#fff
    style Q fill:#FFE66D,color:#000
    style J fill:#95E1D3,color:#000
    style K fill:#95E1D3,color:#000
    style L fill:#95E1D3,color:#000
    style NATIVE fill:#C7E8AC,color:#000
```

---

## 架构说明

### 层级设计

| 层级            | 职责                         | 示例                                                    |
| --------------- | ---------------------------- | ------------------------------------------------------- |
| **应用启动层**  | 应用初始化、Provider全局配置 | main.dart                                               |
| **页面层**      | UI布局与用户交互             | HomePage, EditorPage, TeleprompterPage                  |
| **状态管理层**  | 业务状态存储与观察者模式     | ArticleProvider, SettingsProvider, TeleprompterProvider |
| **核心逻辑层**  | 提词器播放算法实现           | TeleprompterController                                  |
| **服务层**      | 独立的业务功能封装           | StorageService, AsrService, TextParser, AlignmentEngine |
| **数据模型层**  | 业务数据结构定义             | Article, AppSettings, ScriptCharacter                   |
| **UI组件层**    | 可复用的UI组件               | TeleprompterTextLayer, TeleprompterSettingsPanel        |
| **主题&样式层** | 应用主题与色彩系统           | AppColors, AppTheme                                     |
| **本地存储层**  | 数据持久化                   | JSON文件(Desktop)、localStorage(Web)                    |
| **平台层**      | 跨平台原生能力               | sherpa_onnx, window_manager, path_provider等            |

### 关键组件详解

#### 1. **提词器播放核心** (TeleprompterController)
- **功能**: 驱动文本自动滚动、速度计算、识别结果对齐
- **输入**: 当前速度、播放状态、识别文本、时间戳
- **输出**: 应滚动位置、进度百分比、下一次更新的延迟时间

#### 2. **状态管理三角形**
- **ArticleProvider**: 稿件的CRUD、文件夹树结构、拖拽排序
- **SettingsProvider**: 全局设置 + 每稿覆盖层（mergedSettings）
- **TeleprompterProvider**: 播放状态、速度、识别模式、识别结果缓存

#### 3. **本地存储策略**
- **Desktop (Windows/macOS/Linux)**: 用户目录下 `~/.storm/` 的JSON文件
- **Web**: 浏览器 `localStorage` + `IndexedDB`（大文件）
- **StorageService**: 统一接口，自动选择平台实现

#### 4. **语音识别流程**
```
1. 用户点击 "自动识别" → TeleprompterProvider.startRecognition()
2. AsrService 加载已选模型 (sherpa_onnx 原生插件)
3. 音频流以PCM块形式输入 → 识别器持续处理
4. 识别结果通过 AlignmentEngine 映射到原文本位置
5. TeleprompterTextLayer 实时高亮已读部分
```

#### 5. **颜色主题系统**
- 用户在SettingsPage选择主题色 → AppColors.primaryFromSettings() 转换
- main.dart Consumer 包装器监听SettingsProvider → 主题重建
- 所有页面使用 `AppColors.primary` 而非硬编码颜色

#### 6. **编辑器特性**
- **自动保存**: 3秒防抖，后台保存到本地存储
- **WYSIWYG模式**: Toggle按钮切换 RichText预览 vs 源码编辑
- **背景色标注**: TextParser解析HTML `<span style="background-color:...">` 标签

#### 7. **提词器设置面板**
- **位置**: 右侧覆盖面板 (340px宽)，不需要页面跳转
- **分区**: 
  - 上部: 提词器播放相关 (字体、速度、模式、滚动参数)
  - 下部: 应用级设置 (主题、ASR、镜像)
- **每稿独立**: 稿件可覆盖全局设置参数

---

## 数据流示例

### 场景 1: 新建稿件 → 编辑 → 提词
```
HomePage 
  → 新建按钮 
  → EditorPage(article: null) 
  → ArticleProvider.addArticle()
  → StorageService 保存
  → TeleprompterPage 加载
  → TeleprompterController 开始播放
```

### 场景 2: 自动识别流程
```
TeleprompterPage (播放中)
  → TeleprompterProvider.startRecognition()
  → AsrService.recognize() (原生Plugin)
  → 识别结果回调 → AlignmentEngine.align()
  → 计算高亮位置 → TeleprompterTextLayer 重绘
```

### 场景 3: 修改颜色主题
```
SettingsPage
  → 颜色选择器
  → SettingsProvider.setUiPrimaryColor()
  → AppSettings 保存
  → StorageService.saveSettings()
  → main.dart Consumer 触发重建
  → MaterialApp 应用新主题
```

---

## 跨平台适配

| 功能         | Windows        | macOS          | Linux          | Web          |
| ------------ | -------------- | -------------- | -------------- | ------------ |
| **文件存储** | AppData\Local  | ~/Library      | ~/.config      | localStorage |
| **窗口管理** | window_manager | window_manager | window_manager | ❌            |
| **语音识别** | sherpa_onnx    | sherpa_onnx    | sherpa_onnx    | ⚠️ WASM Stub  |
| **全屏模式** | ✓              | ✓              | ✓              | ✓            |
| **模型下载** | ✓              | ✓              | ✓              | ❌ (静态资源) |

---

## 关键设计决策

1. **Provider 而非 Riverpod**: 相对轻量，易于学习与维护
2. **ListView.builder**: 支持2000+字符的流畅渲染
3. **ChangeNotifier 在 AsrService**: 下载进度可观察，SettingsPage 可显示进度条
4. **mergedSettings**: 优雅支持全局 + 每稿覆盖的设置系统
5. **TextParser + ScriptCharacter**: 清晰的字符级元数据模型
6. **Platform-aware Downloader**: 工厂模式自动选择 Desktop/Web 实现

---

## 性能优化点

- ✅ ListView.builder 而非 SingleChildScrollView（减少内存占用）
- ✅ 3秒防抖自动保存（避免频繁IO）
- ✅ Provider 的部分重建机制（只更新关联Widget）
- ✅ 原生Plugin调用 (sherpa_onnx) 性能更优

