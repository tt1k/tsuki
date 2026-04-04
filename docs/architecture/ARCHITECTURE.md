# macOS 极简日语翻译助手 技术架构文档

## 1. 文档目的与范围
本文档用于指导“macOS 极简日语翻译助手”的工程实现，覆盖：
- 桌面端应用架构（SwiftUI + AppKit）
- 翻译流程与分词标注流程
- UI 渲染与设计 token 落地
- 配置、可观测性、测试与发布策略

设计依据：
- `design/DESIGN.md`
- `design/design.html`

---

## 2. 产品目标与非目标

### 2.1 目标
- 提供极速唤起、输入即译的日语翻译助手体验。
- 严格还原极简黑客风 UI（颜色、字号、间距、窗口行为）。
- 支持“词形 + 读音 + 例句分词高亮”结果展示。
- 具备可扩展的翻译 Provider 架构（可替换后端服务）。

### 2.2 非目标（当前阶段）
- 不实现复杂历史管理、多窗口、多标签。
- 不做跨平台（优先 macOS 原生）。
- 不支持离线大模型推理（优先在线 API）。

---

## 3. 架构总览

采用分层架构：

1) Presentation Layer（UI 层）
- SwiftUI 视图：输入卡片、输出卡片、设置面板
- 自定义 FlowLayout：例句流式词块布局
- 设计 Token 系统：统一颜色/字号/间距/圆角

2) Application Layer（应用编排层）
- TranslationUseCase：翻译流程编排
- TokenizeAndAnnotateUseCase：分词 + 词性映射 + 高亮颜色策略
- ShortcutHandler：ESC 隐藏、Cmd+Enter 翻译

3) Domain Layer（领域层）
- 实体：TranslationRequest / TranslationResult / WordToken
- 接口：TranslatorProvider、TokenizerProvider

4) Infrastructure Layer（基础设施层）
- Provider 实现：HTTP 翻译服务适配器（OpenAI/DeepL/自定义）
- NLP 实现：NaturalLanguage.NLTokenizer
- Window 管理：NSPanel / AppKit bridge
- 配置存储：UserDefaults / Keychain（密钥）

---

## 4. 关键模块设计

### 4.1 窗口与生命周期模块
职责：
- 启动即创建无标题工具窗口（460pt 固定宽，内容自适应高）
- Dock 点击唤起并自动聚焦输入框
- ESC 隐藏应用（不退出）

实现建议：
- AppKit `NSPanel` + SwiftUI hosting
- 或 SwiftUI `.windowStyle(.hiddenTitleBar)` + 自定义行为桥接
- 全局按键监听（仅窗口激活时）

### 4.2 输入模块（Input Card）
职责：
- 接收文本输入、快捷键触发翻译
- 右上角 Action Group：翻译按钮 + 设置按钮

约束：
- Monospace 14pt
- 右侧保留 70pt 内边距，避免与按钮重叠
- hover 背景 0.25s 过渡

### 4.3 翻译编排模块
流程：
1. 读取输入文本
2. 参数校验（空文本短路）
3. 调用 TranslatorProvider
4. 对返回结果执行分词与标注
5. 更新 ViewModel 状态（主线程）
6. 输出核心结果与例句词块

失败策略：
- 网络失败/超时：输出轻量错误提示
- Provider 异常：可重试一次（指数退避）

### 4.4 分词与高亮模块
职责：
- 对例句进行分词（NLTokenizer）
- 输出 `WordToken[]`：`kanji`、`furigana`、`pos`、`colorClass`

颜色策略（与设计稿一致）：
- yellow / purple / green / blue / gray 五色轮替
- 后续可按词性映射（名词=blue，动词=green 等）+ 兜底 gray

### 4.5 输出模块（Output Card）
结构：
- Header Row：`汉字词形 + 空格 + 平假名读音`
- Sentence Flow：可换行词块，上假名下主体 + 胶囊下划线

渲染约束：
- 行间距 12pt，词间距 5pt
- 假名 8.5pt，主体 14pt
- 胶囊高度 5.5pt，圆角 4pt，blend mode `plus-lighter/screen`

### 4.6 设置模块
职责：
- 管理 Provider 类型、API Key、请求超时、快捷键偏好
- 持久化本地配置（Keychain + UserDefaults）

---

## 5. 数据模型（建议）

```swift
struct TranslationRequest {
    let sourceText: String
    let sourceLang: String   // e.g. "zh"
    let targetLang: String   // e.g. "ja"
}

struct TranslationResult {
    let headwordKanji: String
    let headwordKana: String
    let sentence: String
    let tokens: [WordToken]
}

struct WordToken: Identifiable {
    let id: UUID
    let kanji: String
    let furigana: String
    let partOfSpeech: String?
    let highlight: HighlightColor
}

enum HighlightColor: String {
    case yellow, purple, green, blue, gray
}
```

---

## 6. 状态管理与并发模型

ViewModel 状态机：
- idle
- typing
- translating
- success(result)
- failure(message)

并发建议：
- 使用 Swift Concurrency（`async/await`）
- 翻译任务可取消（用户继续输入时取消上次任务）
- UI 更新统一在主线程 `@MainActor`

---

## 7. UI 设计 Token 落地

建议建立 `DesignTokens.swift`：

- 颜色：
  - textMain `#E5E5E5`
  - textDim `#777777`
  - windowBg `#141414 @0.98`
  - boxIdle `rgba(45,45,45,0.5)`
  - boxHover `rgba(60,60,60,0.75)`
- 尺寸：
  - windowWidth 460
  - outerPadding 8
  - cardRadius 10
  - windowRadius 12
  - cardGap 8
- 字体：
  - mono 14pt
  - furigana 8.5pt
- 动效：
  - hoverTransition 0.25s ease

---

## 8. 外部依赖与接口边界

外部依赖：
- Apple NaturalLanguage（分词）
- 网络层（URLSession）
- 可选第三方翻译 API

接口边界：
- `TranslatorProvider`：统一翻译入口，屏蔽具体供应商差异
- `TokenizerProvider`：支持未来替换自定义分词器

---

## 9. 安全与隐私

- API Key 必须存储在 Keychain，不写入明文配置文件
- 日志默认不记录用户原文全文（只记录长度、耗时、错误码）
- 网络请求启用 TLS，设置合理 timeout（建议 10s）

---

## 10. 测试策略

单元测试：
- TranslationUseCase 成功/失败/取消场景
- 颜色映射与 token 生成逻辑

UI 测试：
- ESC 隐藏行为
- Cmd+Enter 触发
- 输入输出卡片 hover 状态变化
- 关键尺寸与排版回归快照

集成测试：
- Provider mock 与真实沙箱 API 联调

---

## 11. 发布与演进路线

M1（MVP）：
- 固定 Provider + 输入翻译 + 输出展示 + 快捷键

M2：
- 设置页（Provider/API Key/超时）
- 错误提示与重试
- 词性映射优化

M3：
- 多 Provider 路由
- 历史记录（可选）
- 术语表与自定义词典（可选）

---

## 12. 验收标准（DoD）

- UI 与设计稿视觉偏差可控（颜色、字号、间距符合规范）
- 窗口行为满足：Dock 唤起聚焦、ESC 隐藏
- 平均翻译响应可用（网络正常时）
- 例句分词可换行展示且高亮正确
- 核心流程具备单测覆盖与基础 UI 自动化验证
