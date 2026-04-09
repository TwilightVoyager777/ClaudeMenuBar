# ClaudeMenuBar

一个轻量级 macOS 菜单栏应用，实时显示 Claude Code 状态，无需切换窗口即可响应权限请求。

## 功能

| 状态 | 菜单栏显示 |
|------|-----------|
| 空闲 | `>_` 图标 |
| Claude 正在执行工具 | 工具名称 + 动画圆点 |
| Claude 需要授权 | "Needs input" + 下拉面板 |
| 任务完成 | "Done" + 勾号（3 秒后自动隐藏） |

当 Claude Code 请求权限时，菜单栏下方会弹出一个下拉面板。你可以通过以下方式响应：

- **点击按钮**
- **按键盘 Y / A / N**（下拉面板激活时直接按，无需修饰键）
- **按 Esc** 关闭面板（不响应，Claude 继续等待）

应用会自动检测请求类型：2 个选项（是 / 否）或 3 个选项（允许一次 / 始终允许 / 拒绝），并显示对应的按钮。

## 环境要求

- macOS 13 (Ventura) 或更高版本
- 已安装 [Claude Code](https://claude.ai/code) CLI
- Xcode 15+（从源码构建）

## 安装

```bash
git clone https://github.com/TwilightVoyager777/ClaudeMenuBar.git
cd ClaudeMenuBar
bash scripts/build-and-install.sh
```

脚本会构建 Release 版本、注册 Claude Code hooks 并生成 DMG 安装包。打开后将 **ClaudeMenuBar.app** 拖入 **Applications** 文件夹，然后启动即可。

启动后需要前往 **系统设置 → 隐私与安全性 → 辅助功能**，授权 ClaudeMenuBar。这是发送按键到终端的必要权限。

> 也可以在 Xcode 中打开 `ClaudeMenuBar.xcodeproj`，按 **Cmd+R** 直接运行，再执行 `bash scripts/install.sh` 注册 hooks。注意：Xcode 调试版本和安装版本在辅助功能列表中是两个不同的条目，需要分别授权。

## 使用方法

安装完成后，正常在终端中使用 Claude Code 即可，菜单栏会自动更新：

- **执行中** — 显示当前运行的工具名称
- **等待输入** — 弹出下拉面板，显示权限请求信息，面板会一直保持直到你响应
  - 点击按钮，或按 **Y**（允许一次）/ **A**（始终允许）/ **N**（拒绝）
  - 全局热键（**⌥⌘Y / ⌥⌘A / ⌥⌘N**）可用，但受 macOS 安全输入限制，在部分应用中可能不生效。点击下拉框按钮是最可靠的响应方式。
  - 面板不会因新事件到达而消失——只有你的响应或 **Esc** 才能关闭它
  - 如果内容过长无法显示，请到终端查看详情
- **完成** — 短暂提示后自动隐藏

选择选项后，ClaudeMenuBar 会自动切回之前活跃的应用并发送对应的响应按键。

如需开机自启，点击菜单栏 `>_` 图标，选择 **Launch at Login**。

## 手动测试

在应用运行时，通过 curl 模拟事件：

```bash
# 权限请求 — 3 个选项（Y/A/N）
curl -s -X POST http://localhost:36787 \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"rm -rf node_modules"},"permission_suggestions":[{"allow":"y"}]}'

# 权限请求 — 2 个选项（Y/N）
curl -s -X POST http://localhost:36787 \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"npm install"}}'

# 执行中状态
curl -s -X POST http://localhost:36787 \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/tmp/test.py"}}'

# 完成
curl -s -X POST http://localhost:36787 \
  -H "Content-Type: application/json" \
  -d '{"hook_event_name":"Stop"}'
```

## 架构

```
ClaudeMenuBarApp          @main 入口
└── MenuBarController     总控制器
    ├── MenuBarPill       NSStatusItem 菜单栏组件
    ├── DropdownPanel     菜单栏下方的 NSPanel 浮动面板
    ├── StateManager      @Published AppState + 自动消失计时器
    ├── EventRouter       ClaudeEvent → AppState 映射
    ├── HTTPServer        NWListener 监听端口 36787
    ├── GlobalHotkeys     NSEvent 监听器，处理 Y/A/N/Esc（仅在等待输入时激活）
    └── KeystrokeReplay   CGEventPost 将响应按键转发到终端
```

## 反馈

项目仍在早期开发中，如果遇到 Bug 或有功能建议，欢迎 [提交 Issue](../../issues)，也欢迎 PR！

## 许可证

MIT
