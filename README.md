# xue_hua_navite_system_tray

**English** | [简体中文](./README_ZH.md)

A production-grade, full-featured native desktop **System Tray / Status Bar** plugin for Flutter across **macOS**, **Windows**, and **Linux**.

- **Author**: Matkurban (`3496354336@qq.com`)
- **Repository**: [https://github.com/Matkurban/xue_hua_navite_system_tray](https://github.com/Matkurban/xue_hua_navite_system_tray)
- **Version**: `1.0.0`

---

## Features

- **Native Desktop Backends**:
  - **macOS**: Built on `NSStatusBar` / `NSStatusItem`, `NSMenu` / `NSMenuItem`, `UNUserNotificationCenter`, and `NSApplication.ActivationPolicy`.
  - **Windows**: Built on Win32 `Shell_NotifyIconW` (`NOTIFYICONDATAW`), GDI+ (`Gdiplus::Bitmap`) for automatic PNG/BMP/JPEG/ICO/memory-bytes decoding into `HICON` & `HBITMAP`, and Win32 `HMENU`.
  - **Linux**: Built on dynamic `dlopen` loading of `libayatana-appindicator3.so.1` / `libappindicator3.so.1` (`StatusNotifierItem`) with automatic fallback to GTK3 `GtkStatusIcon`.
- **Flexible Icon Sources (`TrayIconSource`)**:
  - Load icons from Flutter assets (`TrayIconSource.asset`), local file paths (`TrayIconSource.file`), raw in-memory `Uint8List` bytes (`TrayIconSource.bytes` — ideal for dynamically drawn badges/indicators), or native OS symbols/themes (`TrayIconSource.system` — SF Symbols on macOS, Win32 stock icons on Windows, freedesktop icon theme names on Linux).
  - Supports macOS monochrome template images (`isTemplate: true`) for automatic light/dark menu bar adaptation.
- **Rich Context Menus (`TrayMenuItem`)**:
  - Supports standard clickable actions (`TrayMenuItem.action`), checkboxes (`TrayMenuItem.checkbox`), mutually-exclusive radio groups (`TrayMenuItem.radio`), nested submenus (`TrayMenuItem.submenu`), section headers (`TrayMenuItem.header`), and visual separators (`TrayMenuItem.separator`).
  - Supports menu item icons, keyboard shortcut hints (`TrayMenuShortcut`), tooltips, direct `onTap` / `onChanged` Dart callbacks, and fast in-place item updates (`updateMenuItem`).
- **Complete Mouse & Event Stream (`events`)**:
  - Broadcast stream for `leftClick`, `leftDoubleClick`, `rightClick`, `rightDoubleClick`, `middleClick`, `menuItemClick`, and `notificationClick`, including cursor coordinates and tray icon screen bounds (`TrayBounds`).
- **Window Management & Notifications**:
  - Built-in helpers for "Minimize to Tray" (`hideMainWindow`, `showMainWindow`, `isMainWindowVisible`), macOS Dock icon visibility toggling (`setDockIconVisible`), and native tray notifications (`showNotification`).

---

## Platform Matrix & Differences

| Feature | macOS (`NSStatusItem`) | Windows (`Shell_NotifyIconW`) | Linux (`AppIndicator3` / `GtkStatusIcon`) |
| :--- | :---: | :---: | :---: |
| Asset / File / In-Memory Bytes Icons | Yes | Yes (PNG/ICO/BMP via GDI+) | Yes |
| System Symbol / Theme Icons | Yes (SF Symbols) | Yes (`application`, `info`, `warning`, `error`, `shield`) | Yes (Freedesktop Icon Theme) |
| Monochrome Template Icons (`isTemplate`) | Yes | N/A | N/A |
| Inline Status Bar Title (`setTitle`) | Yes | Fallback to Tooltip | Yes (`AppIndicator` label) |
| Hover Tooltip (`setToolTip`) | Yes | Yes (up to 127 chars) | Yes |
| Nested Submenus / Checkboxes / Radios | Yes | Yes | Yes |
| Menu Item Icons & Shortcuts | Yes | Yes (32-bit ARGB `HBITMAP`) | Shortcuts Yes / Icons No |
| Left / Right / Double Click Events | Yes | Yes | `GtkStatusIcon` Yes / `AppIndicator` Menu-Only |
| Screen Geometry (`getBounds`) | Yes | Yes (`Shell_NotifyIconGetRect`) | `GtkStatusIcon` Yes / `AppIndicator` `null` |
| Dock Icon Toggle (`setDockIconVisible`) | Yes | No-op | No-op |
| System Tray Notifications | Yes (`UNUserNotificationCenter`) | Yes (`NIF_INFO` Balloon/Toast) | Yes (`notify-send`) |

---

## Installation

Add `xue_hua_navite_system_tray` to your `pubspec.yaml`:

```yaml
dependencies:
  xue_hua_navite_system_tray: ^1.0.0
```

### AI Agent Package Skills

This package ships with a built-in AI coding agent skill compliant with [Dart Package Skills](https://dart.dev/tools/pub/package-skills) under `skills/xue-hua-navite-system-tray/SKILL.md`. Consumers can install it into their project with:

```bash
dart run skills@ get
```

---

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tray = XueHuaNaviteSystemTray.instance;

  await tray.initSystemTray(
    TrayConfig(
      icon: const TrayIconSource.system('sparkles', isTemplate: true),
      title: 'XueHua',
      toolTip: 'XueHua Desktop Client • Running',
      menuTrigger: TrayMenuTrigger.rightClick,
      menuItems: [
        const TrayMenuItem.header(id: 'hdr', label: 'XueHua Workspace'),
        TrayMenuItem.action(
          id: 'show_win',
          label: 'Show Main Window',
          shortcut: const TrayMenuShortcut('o', meta: true),
          onTap: () => tray.showMainWindow(focus: true),
        ),
        TrayMenuItem.action(
          id: 'hide_win',
          label: 'Minimize to Tray',
          shortcut: const TrayMenuShortcut('h', meta: true),
          onTap: () => tray.hideMainWindow(),
        ),
        const TrayMenuItem.separator(),
        TrayMenuItem.checkbox(
          id: 'auto_sync',
          label: 'Auto-Sync in Background',
          checked: true,
          onChanged: (bool checked) {
            debugPrint('Auto-sync toggled: $checked');
          },
        ),
        TrayMenuItem.submenu(
          id: 'mode_menu',
          label: 'Performance Mode',
          children: [
            TrayMenuItem.radio(
              id: 'mode_eco',
              groupId: 'perf',
              label: 'Eco Mode',
              checked: false,
            ),
            TrayMenuItem.radio(
              id: 'mode_balanced',
              groupId: 'perf',
              label: 'Balanced Mode',
              checked: true,
            ),
          ],
        ),
        const TrayMenuItem.separator(),
        TrayMenuItem.action(
          id: 'quit',
          label: 'Quit',
          shortcut: const TrayMenuShortcut('q', meta: true),
          onTap: () => tray.destroy(),
        ),
      ],
    ),
  );

  // Listen to tray click and menu events:
  tray.events.listen((TrayEvent event) {
    if (event.type == TrayEventType.leftDoubleClick) {
      tray.showMainWindow(focus: true);
    }
  });

  runApp(const MyApp());
}
```

---

## Advanced Usage

### 1. Dynamic In-Memory Badge Icons (`TrayIconSource.bytes`)

You can render custom status icons or unread counters onto a Flutter `Canvas`, export them to PNG `Uint8List` bytes, and pass them directly to `setIcon`:

```dart
await XueHuaNaviteSystemTray.instance.setIcon(
  TrayIconSource.bytes(pngBytes, isTemplate: false, iconSize: 18.0),
);
```

### 2. Updating a Single Menu Item In-Place (`updateMenuItem`)

Avoid rebuilding the entire menu tree when updating a progress label or toggling a menu item:

```dart
await XueHuaNaviteSystemTray.instance.updateMenuItem(
  'sync_status',
  label: 'Syncing (85%)...',
  enabled: false,
);
```

### 3. macOS Dock Icon & Minimize-to-Tray Workflow

On macOS, you can convert your app into a menu-bar-only utility when the main window is hidden:

```dart
// Hide window and remove from macOS Dock:
await XueHuaNaviteSystemTray.instance.hideMainWindow();
await XueHuaNaviteSystemTray.instance.setDockIconVisible(false);

// Restore window and show in macOS Dock:
await XueHuaNaviteSystemTray.instance.setDockIconVisible(true);
await XueHuaNaviteSystemTray.instance.showMainWindow(focus: true);
```

### 4. Inspecting Runtime Capabilities (`getCapabilities`)

```dart
final caps = await XueHuaNaviteSystemTray.instance.getCapabilities();
debugPrint('Backend: ${caps.backendName}, inlineTitle: ${caps.supportsInlineTitle}');
```

---

## Platform Notes & Caveats

1. **macOS (`NSStatusItem`)**:
   - Use 18×18 pt (`@1x`) / 36×36 px (`@2x`) transparent PNG icons with `isTemplate: true` for monochrome status bar icons so macOS automatically inverts the icon color in Dark Mode and when the status bar button is highlighted.
   - All `TrayIconSource` icons (including SF Symbols via `TrayIconSource.system`) are automatically rendered into normalized 2x Retina `NSBitmapImageRep` images so both `NSStatusBarButton` and `NSMenuItem` display icons reliably across all macOS versions.
   - When `hideMainWindow()` is called, the plugin automatically retains the primary `FlutterViewController` window (`isReleasedWhenClosed = false`) and guards `applicationShouldTerminateAfterLastWindowClosed` on `NSApp.delegate` so ordering out the last window does not cause macOS to terminate the app. You can also return `false` from `applicationShouldTerminateAfterLastWindowClosed` in `macos/Runner/AppDelegate.swift`.
   - `showNotification` uses `UNUserNotificationCenter`, which requires the app to run inside a signed/bundled `.app` with a valid `CFBundleIdentifier` and user notification permission.
2. **Windows (`Shell_NotifyIconW`)**:
   - You do **not** need to convert PNG icons to `.ico` manually — the Windows plugin initializes GDI+ (`Gdiplus::Bitmap`) to convert PNG, BMP, JPEG, and raw `Uint8List` bytes into native `HICON` and 32-bit ARGB menu `HBITMAP` handles automatically.
   - Windows taskbar notification icons do not support inline text labels beside the icon (`supportsInlineTitle == false`). When `title` is provided without `toolTip`, it is used as the fallback tooltip.
   - Win32 popup menus automatically apply the `SetForegroundWindow` + `PostMessage(WM_NULL)` idiom so clicking outside the tray menu always dismisses it cleanly.
3. **Linux (`AppIndicator3` / `GtkStatusIcon`)**:
   - At runtime, the plugin dynamically probes `libayatana-appindicator3.so.1` and `libappindicator3.so.1` via `dlopen`. No extra `-dev` packages are required at compile time beyond standard GTK3 (`pkg-config gtk+-3.0`).
   - On GNOME desktops (Ubuntu/Fedora), ensure the `AppIndicator and KStatusNotifierItem Support` GNOME Shell extension is enabled so status notifier icons are displayed in the top bar.
   - Under the DBus `StatusNotifierItem` (`AppIndicator`) specification, clicking the tray icon always opens the bound `GtkMenu` via the panel host, and exact icon screen bounds (`getBounds()`) are not exposed by the compositor (`null`).

---

## License

MIT License © 2026 Matkurban (`3496354336@qq.com`)
