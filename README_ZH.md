# xue_hua_navite_system_tray

[English](./README.md) | **简体中文**

一款专为 Flutter 桌面端（**macOS**、**Windows**、**Linux**）打造的生产级、全功能原生**系统托盘 / 状态栏（System Tray / Status Bar）**插件。

- **作者**：Matkurban (`3496354336@qq.com`)
- **仓库地址**：[https://github.com/Matkurban/xue_hua_navite_system_tray](https://github.com/Matkurban/xue_hua_navite_system_tray)
- **当前版本**：`1.0.0`

---

## 核心特性

- **三端纯正原生实现**：
  - **macOS**：基于 AppKit `NSStatusBar` / `NSStatusItem`、`NSMenu` / `NSMenuItem`、`UNUserNotificationCenter` 以及 `NSApplication.ActivationPolicy` 实现。
  - **Windows**：基于 Win32 `Shell_NotifyIconW` (`NOTIFYICONDATAW`)、GDI+ (`Gdiplus::Bitmap`) 自动解码 PNG/BMP/JPEG/ICO/内存字节流为 `HICON` 与菜单 `HBITMAP`，以及原生 `HMENU` 弹出菜单实现。
  - **Linux**：通过 `dlopen` 动态加载 `libayatana-appindicator3.so.1` 或 `libappindicator3.so.1`（`StatusNotifierItem` 协议），并在未安装 AppIndicator 运行库的环境下自动降级至 GTK3 `GtkStatusIcon`。
- **多样化图标来源 (`TrayIconSource`)**：
  - 支持 Flutter 资源图标 (`TrayIconSource.asset`)、本地绝对路径文件 (`TrayIconSource.file`)、内存 `Uint8List` 字节流 (`TrayIconSource.bytes`，适用于 Canvas 动态绘制角标或进度图标)、以及系统原生符号/主题图标 (`TrayIconSource.system`：macOS SF Symbols、Windows 系统内置图标、Linux Freedesktop 图标主题)。
  - 支持 macOS 模板图标 (`isTemplate: true`)，自动适配浅色与深色菜单栏外观。
- **全功能上下文菜单 (`TrayMenuItem`)**：
  - 支持普通点击项 (`TrayMenuItem.action`)、复选框 (`TrayMenuItem.checkbox`)、单选按钮组 (`TrayMenuItem.radio`)、多级嵌套子菜单 (`TrayMenuItem.submenu`)、分组标题 (`TrayMenuItem.header`) 与分隔线 (`TrayMenuItem.separator`)。
  - 支持菜单项图标、快捷键提示 (`TrayMenuShortcut`)、悬停提示 (`toolTip`)、内联 `onTap` / `onChanged` 回调自动分发，以及不重建整棵菜单树的单项原地更新 (`updateMenuItem`)。
- **完善的鼠标与交互事件流 (`events`)**：
  - 广播流实时推送 `leftClick`（左键单击）、`leftDoubleClick`（左键双击）、`rightClick`（右键单击）、`rightDoubleClick`（右键双击）、`middleClick`（中键点击）、`menuItemClick`（菜单项点击）与 `notificationClick`（通知点击），并附带鼠标屏幕坐标与托盘图标几何边界 (`TrayBounds`)。
- **窗口控制与系统托盘通知**：
  - 内置“最小化到托盘”与恢复窗口辅助方法 (`hideMainWindow`、`showMainWindow`、`isMainWindowVisible`)、macOS 程序坞（Dock）图标显隐切换 (`setDockIconVisible`) 以及跨平台托盘通知 (`showNotification`)。

---

## 各平台能力对比与差异说明

| 功能特性 | macOS (`NSStatusItem`) | Windows (`Shell_NotifyIconW`) | Linux (`AppIndicator3` / `GtkStatusIcon`) |
| :--- | :---: | :---: | :---: |
| 资源 / 本地文件 / 内存字节图标 | 支持 | 支持（GDI+ 自动支持 PNG/ICO/BMP） | 支持 |
| 系统原生符号 / 主题图标 | 支持 (SF Symbols) | 支持 (`application`, `info`, `warning`, `error`, `shield`) | 支持 (Freedesktop Icon Theme) |
| 模板自适应图标 (`isTemplate`) | 支持 | 不适用 | 不适用 |
| 状态栏内联标题文字 (`setTitle`) | 支持 | 自动作为备用 Tooltip | 支持 (`AppIndicator` Label) |
| 悬停提示文本 (`setToolTip`) | 支持 | 支持（最长 127 字符） | 支持 |
| 多级子菜单 / 复选框 / 单选框组 | 支持 | 支持 | 支持 |
| 菜单项图标与快捷键提示 | 支持 | 支持（32 位 ARGB `HBITMAP`） | 支持快捷键提示 / 图标不支持 |
| 左键 / 右键 / 双击区分事件 | 支持 | 支持 | `GtkStatusIcon` 支持 / `AppIndicator` 由面板接管 |
| 获取托盘屏幕坐标 (`getBounds`) | 支持 | 支持 (`Shell_NotifyIconGetRect`) | `GtkStatusIcon` 支持 / `AppIndicator` 返回 `null` |
| 隐藏/显示 Dock 图标 (`setDockIconVisible`) | 支持 | 安全空操作 (No-op) | 安全空操作 (No-op) |
| 托盘通知 (`showNotification`) | 支持 (`UNUserNotificationCenter`) | 支持 (`NIF_INFO` 气泡/Toast) | 支持 (`notify-send`) |

---

## 集成与安装

在项目的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  xue_hua_navite_system_tray: ^1.0.0
```

### 安装 AI Agent Skills

本插件已按照 [Dart Package Skills 规范](https://dart.dev/tools/pub/package-skills) 在包根目录内置 `skills/xue-hua-navite-system-tray/SKILL.md`。使用者可在宿主项目中通过以下命令一键安装 AI 辅助编程技能：

```bash
dart run skills@ get
```

---

## 快速上手

```dart
import 'package:flutter/material.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tray = XueHuaNaviteSystemTray.instance;

  await tray.initSystemTray(
    TrayConfig(
      icon: const TrayIconSource.system('sparkles', isTemplate: true),
      title: '雪花托盘',
      toolTip: '雪花桌面端客户端 • 运行中',
      menuTrigger: TrayMenuTrigger.rightClick,
      menuItems: [
        const TrayMenuItem.header(id: 'hdr', label: '雪花工作台'),
        TrayMenuItem.action(
          id: 'show_win',
          label: '显示主窗口',
          shortcut: const TrayMenuShortcut('o', meta: true),
          onTap: () => tray.showMainWindow(focus: true),
        ),
        TrayMenuItem.action(
          id: 'hide_win',
          label: '最小化到系统托盘',
          shortcut: const TrayMenuShortcut('h', meta: true),
          onTap: () => tray.hideMainWindow(),
        ),
        const TrayMenuItem.separator(),
        TrayMenuItem.checkbox(
          id: 'auto_sync',
          label: '后台自动同步',
          checked: true,
          onChanged: (bool checked) {
            debugPrint('后台自动同步状态: $checked');
          },
        ),
        TrayMenuItem.submenu(
          id: 'mode_menu',
          label: '性能模式',
          children: [
            TrayMenuItem.radio(
              id: 'mode_eco',
              groupId: 'perf',
              label: '节能模式',
              checked: false,
            ),
            TrayMenuItem.radio(
              id: 'mode_balanced',
              groupId: 'perf',
              label: '均衡模式',
              checked: true,
            ),
          ],
        ),
        const TrayMenuItem.separator(),
        TrayMenuItem.action(
          id: 'quit',
          label: '退出托盘',
          shortcut: const TrayMenuShortcut('q', meta: true),
          onTap: () => tray.destroy(),
        ),
      ],
    ),
  );

  // 监听托盘图标点击与菜单事件：
  tray.events.listen((TrayEvent event) {
    if (event.type == TrayEventType.leftDoubleClick) {
      tray.showMainWindow(focus: true);
    }
  });

  runApp(const MyApp());
}
```

---

## 进阶用法

### 1. 动态内存字节流图标 (`TrayIconSource.bytes`)

可通过 Flutter `Canvas` 实时绘制带有未读数量角标或状态颜色的 PNG 字节流，直接更新到系统托盘：

```dart
await XueHuaNaviteSystemTray.instance.setIcon(
  TrayIconSource.bytes(pngBytes, isTemplate: false, iconSize: 18.0),
);
```

### 2. 单项菜单原地更新 (`updateMenuItem`)

高频更新某个菜单项的文字（如同步进度）或勾选状态时，无需调用 `setContextMenu` 重建整棵菜单：

```dart
await XueHuaNaviteSystemTray.instance.updateMenuItem(
  'sync_status',
  label: '正在同步 (85%)...',
  enabled: false,
);
```

### 3. macOS 程序坞（Dock）图标显隐与最小化到托盘

在 macOS 上隐藏主窗口时，可同时隐藏 Dock 栏图标以实现纯粹的菜单栏常驻工具：

```dart
// 隐藏主窗口并隐藏 macOS Dock 图标：
await XueHuaNaviteSystemTray.instance.hideMainWindow();
await XueHuaNaviteSystemTray.instance.setDockIconVisible(false);

// 恢复主窗口并显示 macOS Dock 图标：
await XueHuaNaviteSystemTray.instance.setDockIconVisible(true);
await XueHuaNaviteSystemTray.instance.showMainWindow(focus: true);
```

### 4. 查询当前桌面环境托盘能力 (`getCapabilities`)

```dart
final caps = await XueHuaNaviteSystemTray.instance.getCapabilities();
debugPrint('当前原生后端: ${caps.backendName}, 是否支持内联标题: ${caps.supportsInlineTitle}');
```

---

## 注意事项与平台差异说明

1. **macOS (`NSStatusItem`)**：
   - 建议使用 18×18 pt (`@1x`) / 36×36 px (`@2x`) 的透明背景单色 PNG 图标并开启 `isTemplate: true`，系统会自动根据浅色/深色模式反色。
   - 所有 `TrayIconSource` 图标（包括 `TrayIconSource.system` 的 SF Symbols）在原生层均会自动归一化渲染为 2x Retina `NSBitmapImageRep` 位图表示，确保在状态栏按钮 (`NSStatusBarButton`) 与菜单项 (`NSMenuItem`) 中都能稳定显示。
   - 调用 `hideMainWindow()` 隐藏主窗口时，插件会自动缓存 `FlutterViewController` 宿主窗口（设置 `isReleasedWhenClosed = false`）并拦截 `NSApp.delegate` 的 `applicationShouldTerminateAfterLastWindowClosed(_:)` 返回 `false`，防止 macOS 因最后一个可见窗口隐藏而自动退出应用；同时建议在宿主工程 `macos/Runner/AppDelegate.swift` 中将 `applicationShouldTerminateAfterLastWindowClosed` 设为返回 `false`。
   - `showNotification` 使用 `UNUserNotificationCenter`，要求宿主应用在具有合法 `CFBundleIdentifier` 的 `.app` 包中运行并授予通知权限。
2. **Windows (`Shell_NotifyIconW`)**：
   - **无需手动将 PNG 转为 `.ico`**：Windows 端内置 GDI+ 解码器，可直接加载 PNG、BMP、JPEG、ICO 以及内存 `Uint8List` 字节流。
   - Windows 任务栏托盘区不支持在图标旁直接渲染内联文字（`supportsInlineTitle == false`）；当未设置 `toolTip` 时，`title` 会自动作为备用悬停提示生效。
   - 弹出 Win32 原生菜单时已严格遵循 `SetForegroundWindow` + `PostMessage(WM_NULL)` 规范，点击菜单外部区域可正常收起菜单。
3. **Linux (`AppIndicator3` / `GtkStatusIcon`)**：
   - 插件在运行时通过 `dlopen` 自动探测 `libayatana-appindicator3.so.1` 与 `libappindicator3.so.1`，编译期无需额外安装 `libayatana-appindicator3-dev`，仅需标准 GTK3 环境即可编译通过。
   - 在 Ubuntu / GNOME 桌面环境下，请确保已启用 `AppIndicator and KStatusNotifierItem Support` 扩展以在顶部栏显示托盘图标。
   - 根据 DBus `StatusNotifierItem` (`AppIndicator`) 协议规范，左/右键点击行为由桌面面板直接管理并弹出绑定的 `GtkMenu`，且 Wayland/SNI 协议不暴露托盘图标的屏幕绝对坐标（`getBounds()` 返回 `null`）。

---

## 开源协议

MIT License © 2026 Matkurban (`3496354336@qq.com`)
