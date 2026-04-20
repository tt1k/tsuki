# Tsuki macOS UI/UX 设计规范

## 1. 视觉方向
- 设计语境：极简、开发者工具感、低噪音信息密度。
- 字体基线：全局以 `14pt` 等宽字体为主（`SF Mono` / `Menlo` / `Monaco`）。
- 双主题：支持 Dark / Light / Auto；色值由 `DesignTokens` 动态分发。

---

## 2. 主题色板

### 2.1 Dark（默认）
- 主文字：`#E5E5E5`
- 次文字：`#777777`
- 窗口背景：`#141414`
- 卡片 idle：`rgba(45,45,45,0.5)`
- 卡片 hover：`rgba(60,60,60,0.75)`

### 2.2 Light
- 主文字：`#262626`
- 次文字：`#6C6C70`
- 窗口背景：`#F4F4F2`
- 卡片 idle：`rgba(255,255,255,0.9)`
- 卡片 hover：`rgba(236,236,234,0.95)`

### 2.3 共用强调色（token 胶囊）
1. 黄色：`rgba(204,171,8,0.45)`
2. 紫色：`rgba(153,72,194,0.45)`
3. 绿色：`rgba(40,172,60,0.45)`
4. 蓝色：`rgba(8,105,204,0.45)`
5. 灰色：`rgba(110,110,115,0.4)`

---

## 3. 窗口与容器
- 窗口形态：无标题栏、无系统红黄绿按钮。
- 固定尺寸：`460 x 236`。
- 间距体系：
  - 外边距 `8pt`
  - 卡片间距 `8pt`
  - 窗口圆角 `12pt`
  - 卡片圆角 `10pt`
- Hover 反馈：输入卡与输出卡统一 `0.25s` 过渡。
- 全局行为：
  - `ESC` 隐藏应用（不退出）
  - 状态栏入口可唤起/收起窗口并定位到右上方

---

## 4. 输入卡（Input Card）
- 布局：右上角 Action Group（翻译 + 设置）。
- 按钮尺寸：`24x24`，容器圆角 `5pt`。
- 输入框：单行、14pt 等宽、无 placeholder。
- 右侧避让：为按钮预留约 `76pt` 可输入区域外边距。
- 输入限制：
  - 超过 `25` 字触发提示
  - 允许继续编辑
  - 翻译请求会被拦截直到长度回到阈值内
- 触发入口：翻译按钮、`Enter`、`Cmd+Enter`、URL Scheme 填充后自动翻译。

---

## 5. 输出卡（Output Card）
- 结构：标题区 + 释义（可选）+ token 流式区。
- 标题区：`headwordKanji + headwordKana`，均为 14pt 粗体等宽。
- 释义区：12pt 等宽，次要色。
- token 区：
  - 行距 `12pt`
  - 列距 `5pt`
  - 假名 `8.5pt`
  - 主体 `14pt`
- 胶囊高亮：高度 `5.5pt`，圆角 `4pt`。

---

## 6. 设置面板（Settings Sheet）
- 结构：左侧 Tab（General / Shortcuts / About），右侧详情区。
- General：
  - App Theme（Dark/Light/Auto）
  - Screenshot Theme（Light/Dark/Auto）
  - Language / Provider
  - API Key（掩码显示，显式点击编辑）
  - Note Path（可点击打开 Finder）
- Shortcuts：显示当前翻译快捷键文案、Dock 图标显隐。
- About：应用信息与链接。

---

## 7. 交互一致性要求
- 所有翻译触发入口共享同一翻译状态机。
- 翻译进行中按钮需显示 loading 图标。
- token 输出需与例句文本对齐；provider 漏 token 时须本地补齐（标点除外）。

---

## 8. 当前实现对齐说明（2026-04）
- 设计与代码已对齐双主题（Dark/Light/Auto）。
- 快捷键文案与实现为 `Enter / Cmd+Enter`。
- `shortcutEnabled` 配置字段已存在，但尚未接入快捷键触发开关。

---
本文件为当前版本 UI 基线，涉及视觉调整时请同步更新 `docs/design/design.html` 与对应 token 常量。
