# Tsuki Workspace Notes

本文件只保留协作时必须知道的信息；详细实现与设计规范以 `docs/` 为准。

## 1) 单一事实来源
- 架构与分层：`docs/architecture/ARCHITECTURE.md`
- UI/UX 规范：`docs/design/DESIGN.md`
- 视觉对照：`docs/design/design.html`
- 当前演示数据：`docs/design/example.json`

## 2) 当前目录约定
- 前端（Swift/macOS）：`code/FE/TsukiApp`
- 后端预留目录：`code/BE`
- SwiftPM 清单：`code/FE/Package.swift`
- 根目录启动脚本：`tsuki.sh`

## 3) 常用命令（从仓库根目录）
- 启动前端：`./tsuki.sh` 或 `./tsuki.sh fe run`
- 构建前端：`./tsuki.sh fe build`
- 测试前端：`./tsuki.sh fe test`
- 启动后端（预留）：`./tsuki.sh be start`
- 后端自定义命令：`./tsuki.sh be <command...>`

## 4) 当前阶段边界
- 先不接网络 API，请继续使用 `example.json` 的硬编码输入/输出。
- UI 变更必须与 `DESIGN.md` + `design.html` 对齐。
