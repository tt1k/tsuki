# Tsuki 当前实现文档

## 1. 文档目的
本文件记录仓库内已落地实现，作为 `docs/architecture/ARCHITECTURE.md` 的实现态补充。

## 2. 代码结构与分层映射

### 2.1 目录
- 前端主工程：`code/fe/macos/TsukiApp`
- 启动脚本：`tsuki.sh`
- 架构文档：`docs/architecture`

### 2.2 分层

1) App 层
- `App/TsukiApp.swift`：组装 `SettingsStore` + `MainViewModel`，注入 `TranslationUseCase`。
- `App/AppDelegate.swift`：状态栏图标、窗口定位、键盘监听、URL Scheme 路由。

2) Presentation 层
- `Presentation/Views/MainWindowView.swift`：主窗口组合与通知总线接收。
- `Presentation/Views/InputCardView.swift`：输入、翻译按钮、设置按钮、长度提示钩子。
- `Presentation/Views/OutputCardView.swift`：结果与错误展示。
- `Presentation/Views/SettingsSheetView.swift`：General / Shortcuts / About。
- `Presentation/ViewModels/MainViewModel.swift`：状态机、翻译任务、错误本地化。
- `Presentation/ViewModels/SettingsStore.swift`：配置加载、归一化、持久化。
- `Presentation/Design/*.swift`：动态色板与尺寸/字体 token。

3) Application 层
- `Application/UseCases/TranslationUseCase.swift`：provider + annotate 串联。
- `Application/UseCases/TokenizeAndAnnotateUseCase.swift`：高亮颜色分配。

4) Domain 层
- `Domain/Models/TranslationModels.swift`：请求与结果模型。
- `Domain/Protocols/Providers.swift`：`TranslatorProvider` 协议。

5) Infrastructure 层
- 网络：`Infrastructure/Network/TranslateRouterProvider.swift`、`Infrastructure/Network/Impl/DeepSeekDictionaryProvider.swift`
- 日志：`Infrastructure/Logging/AppEventLogger.swift`
- 翻译笔记：`Infrastructure/Logging/TranslationNoteLogger.swift`
- 输出截图：`Infrastructure/Logging/OutputCardScreenshotWriter.swift`

## 3. 依赖组装

依赖方向：
- `View -> ViewModel -> UseCase -> Protocol -> Infrastructure`

当前运行链路：
- `MainViewModel`
  - `TranslationUseCase`
      - `TranslateRouterProvider`
      - `DeepSeekDictionaryProvider`
    - `TokenizeAndAnnotateUseCase`

## 4. 关键流程

### 4.1 翻译流程
1. 用户触发来源：按钮 / `Enter` / `Cmd+Enter` / `tsuki://translate?text=...`。
2. `MainViewModel.translate()` 校验空输入、25 字上限、并发状态。
3. 读取 `SettingsStore` 当前 provider/language/apiKey。
4. 路由到 provider（`deepseek/openai/gemini/qwen/kimi`）。
5. provider 解析结果并补齐缺失 token（过滤标点）。
6. 标注用例映射 `WordToken` 与高亮色。
7. 成功后写入展示状态，并触发：
   - `TranslationNoteLogger.record(result:)`
   - 输出卡片截图持久化（`MainWindowView` 监听 `isTranslating`）

### 4.2 状态模型
- `idle`：空输入
- `typing`：输入中
- `success(TranslationResult)`：成功
- `failure(title, message)`：失败

并行状态：
- `isTranslating`：请求进行中

取消策略：
- 输入真实变化会取消上一轮翻译任务，避免过期结果回写。

## 5. 设置与配置

### 5.1 配置文件
- 路径：`~/.config/tsuki/config.json`
- 字段：
  - `provider`
  - `language`
  - `appearanceMode`
  - `screenshotAppearanceMode`
  - `shortcutEnabled`
  - `dockIconVisible`
  - `forceTopRightOnLaunch`
  - `apiKeys`

### 5.2 支持集
- provider：`deepseek/openai/gemini/qwen/kimi`
- language：`zh-CN/zh-TW/en/ja/ko/es/fr/de/ru`

### 5.3 API Key 交互
- 默认掩码显示（前 8 位 + `*`）。
- 显式点击后进入编辑态。
- 以 provider 为粒度独立保存 key。

## 6. 窗口、快捷键与 URL Scheme

### 6.1 窗口
- `WindowGroup + hiddenTitleBar` + AppKit 级窗口配置。
- 固定尺寸 `460x236`。
- 状态栏图标控制显示/隐藏与重定位。

### 6.2 快捷键
- 通过 `NSEvent.addLocalMonitorForEvents` 监听回车事件。
- 当按键为 `Enter`（无修饰）或 `Cmd+Enter` 时发送 `TsukiTriggerTranslate`。
- 监听逻辑包含输入法组字保护（`hasMarkedText`）。

### 6.3 URL Scheme
- 注册协议：`tsuki://translate?text=...`
- 接收后拉起窗口并发布 `TsukiFillInputAndTranslate`。

## 7. 日志、截图与笔记

### 7.1 运行日志
- 目录：`~/Library/Logs/tsuki`
- 文件名：`tsuki-app-<run-id>.log`
- 关键内容：设置变更、快捷键事件、`AI_REQ` / `AI_RES`

### 7.2 翻译笔记
- 目录：`~/Library/Logs/tsuki/note/<yyyy-MM-dd>/`
- 文档：`NOTE-day.md` 与 `NOTE-night.md`
- 附件：`screenshot/<headword>-day.png` 与 `screenshot/<headword>-night.png`

## 8. 脚本能力（`tsuki.sh`）

- 前端：`fe run|stop|build|test|clean|package`
- 默认启动：`./tsuki.sh` 等同 `./tsuki.sh fe run`
- 打包：生成 `dist/Tsuki-<version>.dmg`，并附带 CLI 安装脚本

## 9. 已知边界

- 当前已接入 provider：`deepseek/openai/gemini/qwen/kimi`。
- API key 仍在本地配置明文保存，未迁移 Keychain。
- `shortcutEnabled` 已持久化，当前未接入触发判断。
- `code/be` 仍为预留目录。
