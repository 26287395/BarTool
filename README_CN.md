# BarTool

因为mac菜单栏老是显示不完程序图标，所以让AI写一个

简洁、美观的 macOS 菜单栏运行程序管理工具。

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
