# BarTool

因为 mac 菜单栏老是显示不完程序图标，所以让 AI 写了一个。

简洁、美观的 macOS 菜单栏运行程序管理工具。

## Preview

![BarTool Preview](screenshots/preview.png)

支持：

- 查看当前运行 App
- 搜索 App
- 显示 CPU / 内存占用
- 快速退出 App
- 双击激活 App
- 登录启动
- 隐藏系统进程
- 隐藏 Apple App
- 菜单栏模式运行

---

# 预览

- 深色半透明 UI
- macOS 原生风格
- 菜单栏窗口模式
- 支持 Retina 图标

---

# 功能

## App 管理

- 查看正在运行的 App
- 支持 Bundle ID 显示
- 支持按名称排序
- 双击激活窗口
- 一键 Quit

---

## 性能监控

可选显示：

- CPU 使用率
- 内存占用

支持排序：

- CPU 排序
- 内存排序

---

## 筛选

支持：

- 隐藏系统进程
- 隐藏 Apple App
- 搜索 App 名称
- 搜索 Bundle ID

---

## 登录启动

支持：

- Launch at login

使用：

```swift
SMAppService.mainApp.register()
```

---

# 系统要求

- macOS 13+
- Intel / Apple Silicon

---

# 安装

在 Releases 页面下载最新版本。

---

# 注意

如果 macOS 提示：

“无法验证开发者”

请：

1. 右键 App
2. 点击“打开”
3. 再次确认打开
