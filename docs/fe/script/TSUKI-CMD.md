# Tsuki CLI 命令说明

以下命令在仓库根目录执行。

- `./tsuki.sh`
  - 不带参数时，显示帮助（等同 `./tsuki.sh -h`）。

- `./tsuki.sh fe mac run`
  - 构建并启动 macOS 前端 `TsukiApp`，会写启动日志到 `~/Library/Logs/tsuki/`。

- `./tsuki.sh fe mac stop`
  - 停止正在运行的 `TsukiApp` 进程。

- `./tsuki.sh fe mac build`
  - 执行前端构建（Swift build）。

- `./tsuki.sh fe mac clean`
  - 清理前端构建缓存（删除 `code/fe/macos/.build`）。

- `./tsuki.sh fe mac package`
  - 打包发布版 `.dmg` 到 `dist/`，过程中会：
  - 先确认版本/构建号（交互确认）
  - 构建 release、签名 app 和 dmg
  - 打包后自动更新脚本里的 `TSUKI_DEFAULT_VERSION_DEV` / `TSUKI_DEFAULT_BUILD_DEV`
  - 可选创建 git commit + tag（交互确认）

- `./tsuki.sh fe web run`
  - 后台启动 Web 前端开发服务器（`code/fe/web/tsuki-app`）。
  - 固定使用端口 `5199`（若端口被占用则启动失败，不会切换到其他端口）。
  - 日志写入 `~/Library/Logs/tsuki/log/tsuki-web.log`，PID 写入 `~/Library/Logs/tsuki/log/tsuki-web.pid`，启动后终端可继续输入命令。

- `./tsuki.sh fe web stop`
  - 停止 Web 前端开发服务器。

- `./tsuki.sh fe web status`
  - 查看 Web 前端开发服务器运行状态。

- `./tsuki.sh -h` / `--help` / `help`
  - 显示帮助。
