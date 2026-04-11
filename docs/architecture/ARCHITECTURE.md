# Tsuki macOS 架构文档

## 1. 文档目的
本文档描述 Tsuki 当前前端（macOS）技术架构，重点覆盖：
- 分层与依赖方向
- 翻译请求编排与 token 补齐
- 窗口/快捷键/URL Scheme 交互链路
- 配置、日志、截图与笔记产物

参考文档：
- `docs/architecture/IMPLEMENTATION.md`
- `docs/design/DESIGN.md`

---

## 2. 架构总览（分层）

1) Presentation（UI 层）
- SwiftUI 页面：`InputCardView`、`OutputCardView`、`SettingsSheetView`
- 视图编排：`MainWindowView`
- 设计 token：`DesignTokens` + `DarkColorPalette` + `LightColorPalette`

2) Application（用例层）
- `TranslationUseCase`：请求编排入口
- `TokenizeAndAnnotateUseCase`：词块标注与高亮色分配

3) Domain（领域层）
- 模型：`TranslationRequest`、`TranslationResult`、`WordToken`
- 协议：`TranslatorProvider`

4) Infrastructure（基础设施）
- 网络：`TranslateRouterProvider`、`DeepSeekDictionaryProvider`
- 日志：`AppEventLogger`
- 笔记与截图：`TranslationNoteLogger`、`OutputCardScreenshotWriter`
- 时间与命名：`LocalDateTime`、`NoteAssetNaming`

依赖方向：
- `View -> ViewModel -> UseCase -> Protocol -> Infrastructure`
- 依赖在 `TsukiApp` 入口处完成组装，UI 不直接依赖具体 provider。

---

## 3. 应用入口与窗口模型

- 入口：`App/TsukiApp.swift`，使用 `@NSApplicationDelegateAdaptor` 挂接 `AppDelegate`。
- 窗口：`WindowGroup + .hiddenTitleBar + .windowResizability(.contentSize)`。
- 固定尺寸：`460 x 236`（由 `DesignTokens.Size` 定义）。
- 标题栏按钮隐藏、窗口位置默认置于状态栏下方右侧。
- 支持 Dock 图标显隐切换（`dockIconVisible`）。
- `ESC` 触发 `onExitCommand` 后隐藏 app（不退出）。

---

## 4. 输入与触发链路

输入规则：
- 单行输入（换行会被替换为空格）。
- 最大长度 25 字；超过长度可继续编辑，但翻译请求会被拦截。

触发入口：
- 点击翻译按钮。
- `Enter` 或 `Cmd+Enter`（本地 key monitor，且对输入法 composition 做保护）。
- URL Scheme：`tsuki://translate?text=...`。

状态一致性：
- 同一通知 `TsukiTriggerTranslate` 驱动按钮与快捷键触发。
- `isTranslating` 驱动 loading 与请求中状态。

---

## 5. 翻译与标注流程

主流程：
1. `MainViewModel.translate()` 校验空输入、长度、并发状态。
2. 读取 `SettingsStore`（provider、language、apiKey）。
3. 调用 `TranslationUseCase.execute()`。
4. `TranslateRouterProvider` 路由到具体 provider（`deepseek/openai/gemini/qwen/kimi`）。
5. 对应 provider 请求 `chat/completions` 并解析 JSON。
6. provider 侧先做“漏 token 本地补齐（不含标点）”。
7. `TokenizeAndAnnotateUseCase` 分配高亮色并返回 `TranslationResult`。
8. ViewModel 更新为 `success`/`failure`，并记录日志与笔记。

错误映射：
- 缺失 API Key、HTTP 错误、响应格式异常、未接入 provider，均映射为本地化 UI 文案。

---

## 6. 数据模型

核心模型定义在 `Domain/Models/TranslationModels.swift`：
- `TranslationRequest`：`sourceText/provider/apiKey/sourceLang/targetLang`
- `TranslationResult`：`headwordKanji/headwordKana/meaning/sentence/tokens`
- `WordToken`：`kanji/furigana/partOfSpeech/highlight`
- `ProviderTranslationPayload`：provider 原始结构到领域结构的桥接对象

---

## 7. 状态与并发模型

- 视图状态：`idle | typing | success | failure`。
- 并行状态：`isTranslating`（按钮 loading 与任务互斥）。
- 并发机制：Swift Concurrency（`Task` + `async/await`）。
- 输入变化时会取消上一轮请求，防止过期结果回写。
- UI 状态更新统一在 `@MainActor`。

---

## 8. 配置与持久化

配置文件：`~/.config/tsuki/config.json`

当前持久化字段：
- `provider`
- `language`
- `appearanceMode`
- `screenshotAppearanceMode`
- `shortcutEnabled`（字段保留）
- `dockIconVisible`
- `forceTopRightOnLaunch`
- `apiKeys`（按 provider）

归一化策略：
- 不在支持集的 provider/language 会回落到默认值。
- API key 按 provider 独立存储。

---

## 9. 可观测性与产物

运行日志：
- 目录：`~/Library/Logs/tsuki`
- 文件：`tsuki-app-<run-id>.log`
- 内容：设置变更、快捷键事件、`AI_REQ`/`AI_RES` 紧凑 JSON

翻译笔记：
- 目录：`~/Library/Logs/tsuki/note/<yyyy-MM-dd>/`
- 文件：`NOTE-day.md`、`NOTE-night.md`
- 标题：`# Tsuki Note <yyyy-MM-dd> Light|Dark`（由主题映射生成）
- 每次成功翻译会追加：词条标题 + 输出卡片截图引用
- 截图文件位于 `screenshot/<headword>-day.png`、`screenshot/<headword>-night.png`

---

## 10. 主题与设计 Token

- Token 入口：`Presentation/Design/DesignTokens.swift`
- 支持 `dark/light/auto` 三种应用主题
- 翻译完成后会自动保存 `day` 与 `night` 两份截图
- 关键尺寸：`windowWidth=460`、`windowHeight=236`、`outputMinHeight=160`
- 高亮色：`yellow/purple/green/blue/gray`

---

## 11. 安全边界与已知限制

- API key 当前仍保存在本地配置文件，尚未迁移 Keychain。
- provider 路由与网络层当前已接入：`deepseek/openai/gemini/qwen/kimi`。
- `shortcutEnabled` 已持久化，当前版本未接入实际快捷键开关逻辑。

---

## 12. 演进建议

1. 为各 provider 补充更细粒度错误映射与重试策略。
2. API key 迁移至 Keychain，配置文件仅保留非敏感字段。
3. 为 token 补齐与输入长度限制补回归测试。
4. 将 `shortcutEnabled` 接入真正的快捷键启停逻辑。
