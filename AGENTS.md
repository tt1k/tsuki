# Tsuki Workspace Notes

本文件只保留协作时必须知道的信息；详细实现与设计规范以 `docs/` 为准。

## 1) 单一事实来源
- 架构与分层：`docs/architecture/ARCHITECTURE.md`
- 当前实现状态：`docs/architecture/IMPLEMENTATION.md`
- UI/UX 规范：`docs/design/DESIGN.md`
- 视觉对照：`docs/design/design.html`
- 当前演示数据：`docs/design/example.json`

## 2) 当前目录约定
- 前端（Swift/macOS）：`code/fe/macos/TsukiApp`
- 后端预留目录：`code/be`
- SwiftPM 清单：`code/fe/macos/Package.swift`
- 根目录启动脚本：`tsuki.sh`
- 运行日志目录：`~/Library/Logs/tsuki/logs`
- 翻译笔记目录：`~/Library/Logs/tsuki/note/<yyyy-MM-dd>`

## 3) 常用命令（从仓库根目录）
- 启动前端：`./tsuki.sh` 或 `./tsuki.sh fe run`
- 构建前端：`./tsuki.sh fe build`
- 测试前端：`./tsuki.sh fe test`
- 清理前端缓存：`./tsuki.sh fe clean`
- 打包 dmg：`./tsuki.sh fe package`
- 启动后端（预留）：`./tsuki.sh be start`
- 后端自定义命令：`./tsuki.sh be <command...>`

## 4) 当前阶段边界
- 当前已接入在线翻译：`deepseek/openai/gemini/qwen/kimi`。
- `example.json` 仅作为视觉与结构对照，不再代表运行时唯一数据源。
- API Key 当前仍写入 `~/.config/tsuki/config.json`（未迁移 Keychain）。
- `shortcutEnabled` 已持久化但尚未接入快捷键开关逻辑。
- UI 变更必须与 `DESIGN.md` + `design.html` 对齐。

## 5) 当前交互基线（实现约束）
- 手动点击翻译按钮、`Enter`、`Cmd+Enter` 的状态切换必须一致。
- 翻译进行中输入框保持锁定；请求结束后应可继续编辑（当前实现为点击输入区恢复焦点）。
- 输出 token 必须与例句文本一致；若 provider 漏 token（如助词），需要本地补齐（标点除外）。
- 支持 URL Scheme：`tsuki://translate?text=<urlencoded-text>`。

## 6) 产物约定（日志与笔记）
- 每次成功翻译会在当日同时追加 `NOTE-day.md` 与 `NOTE-night.md` 两份词条记录，并保存输出卡截图。
- 截图默认路径：`~/Library/Logs/tsuki/note/<yyyy-MM-dd>/screenshot/<headword>-day.png` 与 `~/Library/Logs/tsuki/note/<yyyy-MM-dd>/screenshot/<headword>-night.png`。
