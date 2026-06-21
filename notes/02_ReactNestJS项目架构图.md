# 原始飓风提词器 (React + NestJS) - 系统架构

## 简洁版架构图

```mermaid
graph TB
    subgraph "前端 Client"
        A["React App<br/>(Vite + React Router)"]
        A --> B["Home Page<br/>(稿件列表)"]
        A --> C["ScriptEditor<br/>(编辑页面)"]
        A --> D["Teleprompter<br/>(播放页面)"]
    end
    
    subgraph "前端状态管理"
        B & C & D --> E["Redux Toolkit<br/>+ React Query"]
    end
    
    subgraph "前端组件库"
        B & C & D --> F["Radix UI<br/>+ Tailwind CSS<br/>+ Custom Components"]
    end
    
    subgraph "前端本地功能"
        D --> G["Sherpa ONNX<br/>(WASM ASR)"]
        C & D --> H["Shiki<br/>(代码高亮)"]
        C & D --> I["TipTap<br/>(富文本编辑)"]
    end
    
    subgraph "前后端通信"
        E --> J["Axios<br/>HTTP Client"]
    end
    
    subgraph "后端 Server"
        J --> K["NestJS App<br/>(Express + TypeScript)"]
        K --> L["Article Module<br/>(稿件CRUD)"]
        K --> M["Settings Module<br/>(系统设置)"]
        K --> N["View Module<br/>(前端服务)"]
        K --> O["FeishuProxy Module<br/>(飞书集成)"]
    end
    
    subgraph "后端服务层"
        L & M & O --> P["Database<br/>(Drizzle ORM)"]
    end
    
    subgraph "外部服务"
        O --> Q["Feishu API<br/>(飞书平台)"]
        K --> R["Google Gemini<br/>(AI文本改写)"]
    end
    
    subgraph "数据库"
        P --> S["SQLite / MySQL<br/>(持久化存储)"]
    end
    
    style K fill:#FF6B6B,color:#fff
    style E fill:#4ECDC4,color:#fff
    style P fill:#95E1D3,color:#000
```

---

## 详细版架构图

```mermaid
graph TB
    subgraph "入口层"
        ENTRY["index.tsx<br/>├─ React 根节点<br/>├─ Router配置<br/>├─ Provider包装<br/>└─ 全局样式加载"]
    end
    
    subgraph "路由&页面层"
        HOME["Home.tsx<br/>├─ 稿件列表展示<br/>├─ 新建/删除操作<br/>├─ 搜索过滤<br/>└─ 拖拽排序"]
        EDITOR["ScriptEditorPage.tsx<br/>├─ TipTap编辑器<br/>├─ 实时预览<br/>├─ 草稿自动保存<br/>├─ 标签标注工具<br/>└─ 背景色高亮"]
        TELEPROMPTER["TeleprompterPage.tsx<br/>├─ 播放UI<br/>├─ 速度控制<br/>├─ 全屏模式<br/>├─ 快捷键处理<br/>├─ 识别模式选择<br/>└─ 进度展示"]
        NOTFOUND["NotFound.tsx<br/>(404处理)"]
        LAYOUT["Layout.tsx<br/>├─ 导航栏<br/>├─ 侧边栏<br/>└─ 主内容区"]
    end
    
    subgraph "状态管理层"
        REDUX["Redux Toolkit<br/>├─ articleSlice<br/>├─ settingsSlice<br/>├─ teleprompterSlice<br/>├─ asrSlice<br/>└─ uiSlice"]
        QUERY["React Query<br/>├─ 服务器状态缓存<br/>├─ 自动重新获取<br/>├─ 请求去重<br/>└─ 乐观更新"]
    end
    
    subgraph "UI 组件库"
        RADIX["Radix UI Primitives<br/>├─ Dialog<br/>├─ Select<br/>├─ Tabs<br/>├─ Slider<br/>├─ Popover<br/>└─ 其他原始组件"]
        CUSTOM["自定义业务组件<br/>├─ ColorPicker<br/>├─ SpeedControl<br/>├─ TeleprompterView<br/>├─ SettingsPanel<br/>└─ ArticleList"]
        TAILWIND["Tailwind CSS<br/>├─ 工具类样式<br/>├─ 响应式设计<br/>├─ 深色主题<br/>└─ 动画库"]
    end
    
    subgraph "前端服务层"
        TEXTPARSE["TextParser<br/>├─ HTML解析<br/>├─ 字符流生成<br/>├─ 样式标签提取<br/>└─ 背景色处理"]
        ALIGNMENT["AlignmentEngine<br/>├─ 原文 → 字符数组映射<br/>├─ ASR结果对齐<br/>├─ 位置计算<br/>└─ 进度百分比生成"]
        SHIKI["Shiki 代码高亮<br/>├─ 语法着色<br/>├─ 多语言支持<br/>└─ 主题切换"]
        TIPTAP["TipTap Editor<br/>├─ 富文本编辑<br/>├─ 标签插件系统<br/>├─ 撤销/重做<br/>└─ Markdown支持"]
        ASR["Sherpa ONNX (WASM)<br/>├─ 浏览器本地识别<br/>├─ 模型加载<br/>├─ 流式处理<br/>└─ 多语言支持"]
    end
    
    subgraph "HTTP 通信层"
        AXIOS["Axios Instance<br/>├─ 请求拦截<br/>├─ 响应拦截<br/>├─ 错误处理<br/>├─ 超时控制<br/>└─ 请求取消"]
        APIINDEX["API 接口定义<br/>├─ article.api.ts<br/>├─ settings.api.ts<br/>├─ view.api.ts<br/>└─ feishu.api.ts"]
    end
    
    subgraph "后端应用层 NestJS"
        APP["app.module.ts<br/>├─ Platform Module<br/>├─ Article Module<br/>├─ Settings Module<br/>├─ View Module<br/>├─ Feishu Module<br/>└─ 全局异常过滤器"]
    end
    
    subgraph "后端业务模块"
        ARTICLE["Article Module<br/>├─ article.controller.ts<br/>│  ├─ GET /articles<br/>│  ├─ POST /articles<br/>│  ├─ PUT /articles/:id<br/>│  └─ DELETE /articles/:id<br/>├─ article.service.ts<br/>└─ article.entity.ts"]
        SETTINGS["Settings Module<br/>├─ settings.controller.ts<br/>│  ├─ GET /settings<br/>│  └─ PUT /settings<br/>├─ settings.service.ts<br/>└─ settings.entity.ts"]
        VIEW["View Module<br/>├─ view.controller.ts<br/>│  └─ 前端静态资源服务<br/>└─ index.html 渲染"]
        FEISHU["Feishu Proxy Module<br/>├─ feishu-proxy.controller.ts<br/>│  ├─ POST /feishu/sync<br/>│  └─ POST /feishu/webhook<br/>├─ feishu-proxy.service.ts<br/>└─ Feishu API 代理调用"]
    end
    
    subgraph "后端通用层"
        FILTER["异常处理<br/>├─ GlobalExceptionFilter<br/>├─ 统一错误格式<br/>└─ HTTP状态码映射"]
        INTERFACE["公共接口<br/>├─ ApiResponse<br/>├─ ApiException<br/>└─ 分页定义"]
        CONSTANT["常量定义<br/>├─ API响应码<br/>└─ 业务常量"]
    end
    
    subgraph "数据访问层"
        ORM["Drizzle ORM<br/>├─ 类型安全SQL<br/>├─ 数据库连接管理<br/>├─ 事务支持<br/>└─ 迁移工具"]
        SCHEMA["Database Schema<br/>├─ articles 表<br/>├─ settings 表<br/>├─ folders 表<br/>└─ relations 定义"]
    end
    
    subgraph "数据库层"
        DB["SQLite / MySQL<br/>├─ 稿件数据<br/>├─ 用户设置<br/>├─ 系统配置<br/>└─ 关系数据"]
    end
    
    subgraph "外部服务"
        FEISHUAPI["飞书 API<br/>├─ 文档API<br/>├─ 用户API<br/>└─ 存储API"]
        GEMINI["Google Gemini<br/>├─ 文本改写<br/>├─ 内容优化<br/>└─ AI处理"]
    end
    
    subgraph "工具链"
        VITE["Vite<br/>├─ 极速冷启动<br/>├─ HMR热更新<br/>└─ 优化构建"]
        ESLINT["ESLint + Prettier<br/>├─ 代码质量检查<br/>└─ 代码格式化"]
        TAILDWIND["Tailwind CSS<br/>├─ PostCSS处理<br/>└─ 实用优先CSS"]
    end
    
    ENTRY --> LAYOUT
    LAYOUT --> HOME & EDITOR & TELEPROMPTER & NOTFOUND
    
    HOME & EDITOR & TELEPROMPTER --> REDUX & QUERY
    REDUX --> TEXTPARSE & ALIGNMENT & SHIKI & TIPTAP
    QUERY --> AXIOS
    
    HOME & EDITOR & TELEPROMPTER --> RADIX & CUSTOM & TAILWIND
    
    EDITOR --> TIPTAP
    TELEPROMPTER --> ASR & ALIGNMENT
    
    AXIOS --> APIINDEX
    APIINDEX --> APP
    
    APP --> ARTICLE & SETTINGS & VIEW & FEISHU & FILTER & INTERFACE & CONSTANT
    
    ARTICLE & SETTINGS & FEISHU --> ORM
    ORM --> SCHEMA --> DB
    
    FEISHU --> FEISHUAPI
    APP --> GEMINI
    
    VITE -.-> ENTRY
    ESLINT -.-> EDITOR
    TAILDWIND -.-> TAILWIND
    
    style APP fill:#FF6B6B,color:#fff
    style REDUX fill:#4ECDC4,color:#fff
    style QUERY fill:#4ECDC4,color:#fff
    style ARTICLE fill:#FFE66D,color:#000
    style SETTINGS fill:#FFE66D,color:#000
    style DB fill:#95E1D3,color:#000
```

---

## 架构说明

### 前端架构（React + Vite）

#### 层级设计
| 层级            | 职责                                | 示例                                       |
| --------------- | ----------------------------------- | ------------------------------------------ |
| **入口层**      | React根组件、路由配置、全局Provider | index.tsx                                  |
| **路由/页面层** | 独立页面组件与用户交互              | Home, ScriptEditor, Teleprompter           |
| **状态管理**    | 全局状态存储与同步                  | Redux Toolkit + React Query                |
| **UI组件**      | 可复用UI组件库                      | Radix + Tailwind + 自定义组件              |
| **服务层**      | 业务逻辑与数据处理                  | TextParser, AlignmentEngine, Shiki, TipTap |
| **HTTP通信**    | API调用与请求管理                   | Axios + API接口定义                        |

#### 核心前端库
- **Vite**: 极速开发服务器 + 优化构建
- **React Router**: 声明式路由管理
- **Redux Toolkit**: 可预测的全局状态
- **React Query**: 服务器状态缓存同步
- **Radix UI**: 无样式可访问原始组件
- **Tailwind CSS**: 工具优先的CSS框架
- **TipTap**: 强大的富文本编辑器
- **Shiki**: 高精度代码语法高亮
- **Sherpa ONNX (WASM)**: 浏览器本地语音识别

---

### 后端架构（NestJS + Express）

#### 模块化设计
```
AppModule (根模块)
├─ PlatformModule (飞书AaaS平台能力)
├─ ArticleModule
│  ├─ ArticleController (路由)
│  ├─ ArticleService (业务逻辑)
│  └─ Article Entity (数据模型)
├─ SettingsModule
│  ├─ SettingsController
│  ├─ SettingsService
│  └─ Settings Entity
├─ FeishuProxyModule
│  ├─ FeishuProxyController (API代理)
│  ├─ FeishuProxyService (飞书SDK调用)
│  └─ 飞书事件处理
├─ ViewModule (前端静态资源+MPA路由)
└─ 全局过滤器、中间件、拦截器
```

#### API 设计规范
```typescript
// 统一响应格式
{
  "code": 200,           // 业务状态码
  "data": {...},         // 业务数据
  "message": "success"   // 说明文本
}

// 分页格式
{
  "code": 200,
  "data": {
    "items": [...],
    "total": 100,
    "page": 1,
    "pageSize": 10
  }
}
```

#### 数据库设计
- **articles 表**: id, title, content, createdAt, updatedAt, folderId
- **settings 表**: key, value, type, description
- **folders 表**: id, name, parentId, sortOrder

---

### 关键特性详解

#### 1. **文本对齐引擎 (AlignmentEngine)**
功能：ASR识别结果与原始文本的位置映射
```
原始文本: "今天天气很好，我们一起去公园"
ASR结果: "今天天气很好 我们一起去公园"
           ↓ 对齐
映射数组: [
  { char: '今', position: 0, recognized: true },
  { char: '天', position: 1, recognized: true },
  ...
]
进度: 12/20 (60%)
```

#### 2. **富文本编辑器 (TipTap)**
- 基于 ProseMirror 的强大富文本引擎
- 扩展系统: 可定制颜色、背景、样式
- Markdown 导入导出支持

#### 3. **飞书集成 (FeishuProxy)**
- OAuth认证与授权
- 双向同步: 文档<→>稿件
- Webhook事件推送

#### 4. **Google Gemini AI**
- 文本改写与优化
- 内容生成与补全

#### 5. **状态管理三层**
```
1. 组件本地状态 (useState) - 临时UI状态
2. Redux全局状态 - 跨组件共享数据
3. React Query 缓存 - 服务器同步状态
```

---

### 数据流示例

#### 场景1: 新建稿件
```
Home.tsx (新建按钮)
  → 打开对话框
  → 提交表单
  → articleApi.createArticle()
  → POST /api/articles
  → ArticleService.create()
  → Database.insert()
  → Redux dispatch (addArticle)
  → Home列表重新渲染
```

#### 场景2: 编辑稿件
```
ScriptEditor.tsx (用户输入)
  → 3s防抖
  → articleApi.updateArticle()
  → PUT /api/articles/:id
  → ArticleService.update()
  → Database.update()
  → React Query invalidate
  → 同步回主列表
```

#### 场景3: ASR识别
```
TeleprompterPage (播放中)
  → Sherpa ONNX 识别完成
  → AlignmentEngine.align()
  → 计算字符高亮范围
  → Redux dispatch (updateRecognition)
  → TeleprompterView 重绘
  → 选项1: 发送识别结果到后端 (articleApi.updateRecognition)
  → 选项2: 纯前端处理 (保存到本地)
```

#### 场景4: 飞书同步
```
SettingsPanel (开启飞书同步)
  → POST /api/feishu/sync
  → FeishuService.fetchDocuments()
  → Feishu API 返回文档列表
  → 转换为 Article 数据模型
  → Database.insert()
  → Redux 更新列表
```

---

## 技术栈总结

### 前端
| 分类   | 技术          | 版本       |
| ------ | ------------- | ---------- |
| 框架   | React         | 18.x       |
| 构建   | Vite          | 5.x        |
| 路由   | React Router  | 6.x        |
| 状态   | Redux Toolkit | 2.x        |
| 缓存   | React Query   | 5.x        |
| UI原始 | Radix UI      | 1.x        |
| 样式   | Tailwind CSS  | 4.x        |
| 编辑器 | TipTap        | 3.x        |
| 高亮   | Shiki         | 3.x        |
| ASR    | Sherpa ONNX   | 1.x (WASM) |

### 后端
| 分类   | 技术            | 版本   |
| ------ | --------------- | ------ |
| 框架   | NestJS          | 10.x   |
| 运行时 | Node.js         | 20.x   |
| 数据库 | SQLite/MySQL    | -      |
| ORM    | Drizzle         | 0.44.x |
| HTTP   | Express         | 4.x    |
| 验证   | class-validator | 0.14.x |
| AI     | Google Gemini   | API    |
| 飞书   | @lark-apaas     | 1.x    |

---

## 部署架构

```
生产环境
├─ 前端
│  ├─ Vite build 输出 (dist/)
│  └─ 静态资源 CDN 分发
└─ 后端
   ├─ NestJS 应用实例
   ├─ 数据库 (MySQL主从/PostgreSQL)
   └─ 消息队列 (可选，用于异步任务)
```

---

## 跨平台差异

| 功能     | 桌面网页 | 手机网页 | 说明              |
| -------- | -------- | -------- | ----------------- |
| 完整编辑 | ✓        | ⚠️        | 手机UI需优化      |
| 提词播放 | ✓        | ✓        | 响应式设计        |
| ASR识别  | ✓        | ✓        | WASM跨平台        |
| 飞书集成 | ✓        | ⚠️        | 部分功能需OAuth   |
| 模型管理 | ✓        | ❌        | Web不支持本地下载 |

