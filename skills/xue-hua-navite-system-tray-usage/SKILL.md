---
name: xue-hua-navite-system-tray-usage
description: Use when the user is working with xue_hua_navite_system_tray APIs to implement native desktop system tray / menu bar icons, inline status text, tooltips, nested context menus with checkboxes/radios/shortcuts, tray notifications, Dock visibility toggling, and minimize-to-tray window management across macOS, Windows, and Linux.
---
# xue-hua-navite-system-tray

Provide idiomatic integration patterns, platform difference handling, and best practices for the `xue_hua_navite_system_tray` Flutter desktop plugin across macOS, Windows, and Linux.

## When to Use

- Initializing and updating a desktop system tray / status bar item (`initSystemTray`, `TrayConfig`)
- Setting tray icons from Flutter assets, local files, raw in-memory `Uint8List` bytes, or OS system symbols (`TrayIconSource.asset`, `file`, `bytes`, `system`)
- Building context menus with action items, checkboxes, radio groups, nested submenus, headers, separators, icons, and keyboard shortcuts (`TrayMenuItem`, `TrayMenuShortcut`)
- Updating individual context menu items in-place (`updateMenuItem`) or popping up the menu programmatically (`popUpContextMenu`)
- Handling left-click, right-click, double-click, middle-click, menu item clicks, and screen geometry (`events`, `getBounds`)
- Implementing "Minimize to Tray" (`hideMainWindow`, `showMainWindow`, `setDockIconVisible`) and tray notifications (`showNotification`)

## Guidelines

* Always access the plugin via `XueHuaNaviteSystemTray.instance` and call `initSystemTray(TrayConfig(...))` after `WidgetsFlutterBinding.ensureInitialized()`.
* Prefer `isTemplate: true` on `TrayIconSource` for monochrome icons on macOS so `NSStatusItem` and `NSMenuItem` automatically adapt to light and dark appearances.
* Use `updateMenuItem(id, ...)` instead of rebuilding the entire menu via `setContextMenu(...)` when updating a single item's label, enabled state, or checked state at high frequency.
* Subscribe to `XueHuaNaviteSystemTray.instance.events` in `initState()` and cancel the `StreamSubscription<TrayEvent>` in `dispose()`, or attach `onTap` / `onChanged` callbacks directly to `TrayMenuItem` instances.
* Inspect `getCapabilities()` when designing UI that relies on platform-specific features such as inline status bar text (`supportsInlineTitle`), icon screen bounds (`supportsIconBounds`), or macOS Dock visibility toggling (`supportsDockVisibilityToggle`).
* Call `destroy()` when tearing down the tray icon permanently to release native OS status bar / notification area handles.

## Platform Gotchas

* **macOS (`NSStatusItem`)**:
  - Supports inline `title` text next to the icon, `isTemplate` adaptive monochrome icons, SF Symbols via `TrayIconSource.system('sparkles')`, and hiding the Dock icon via `setDockIconVisible(false)`.
  - In `macos/Runner/AppDelegate.swift`, return `false` from `applicationShouldTerminateAfterLastWindowClosed(_:)` when using minimize-to-tray workflows (the plugin also installs a runtime guard on `NSApp.delegate` while the tray is active so `hideMainWindow()` does not terminate the app).
* **Windows (`Shell_NotifyIconW`)**: Taskbar tray icons do not render inline text next to the icon (`supportsInlineTitle` is `false`); `setTitle` is used as a fallback tooltip when `toolTip` is empty. Both `.ico` and `.png`/`.bmp` assets or raw `Uint8List` bytes are decoded automatically via GDI+.
* **Linux (`AyatanaAppIndicator3` / `AppIndicator3` / `GtkStatusIcon`)**: Dynamically loads `libayatana-appindicator3.so.1` or `libappindicator3.so.1` at runtime via `dlopen` and falls back to `GtkStatusIcon` if neither is installed. Under the DBus `StatusNotifierItem` (`AppIndicator`) protocol, primary clicks on the tray icon are managed by the desktop panel to open the bound `GtkMenu`, and icon screen coordinates (`getBounds()`) return `null`.

## Examples

### Initialize System Tray with Context Menu and Minimize-to-Tray

```dart
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';

Future<void> setupSystemTray() async {
  final tray = XueHuaNaviteSystemTray.instance;

  await tray.initSystemTray(
    TrayConfig(
      icon: const TrayIconSource.asset(
        'assets/icons/tray_icon.png',
        isTemplate: true,
      ),
      title: 'Online',
      toolTip: 'XueHua Desktop Client',
      menuTrigger: TrayMenuTrigger.rightClick,
      menuItems: [
        const TrayMenuItem.header(id: 'hdr', label: 'XueHua Client'),
        TrayMenuItem.action(
          id: 'restore',
          label: 'Show Window',
          shortcut: const TrayMenuShortcut('o', meta: true),
          onTap: () => tray.showMainWindow(focus: true),
        ),
        TrayMenuItem.checkbox(
          id: 'auto_sync',
          label: 'Background Sync',
          checked: true,
          onChanged: (checked) {
            // Handle toggle state
          },
        ),
        const TrayMenuItem.separator(),
        TrayMenuItem.action(
          id: 'quit',
          label: 'Quit',
          shortcut: const TrayMenuShortcut('q', meta: true),
          onTap: () async {
            await tray.destroy();
          },
        ),
      ],
    ),
  );

  tray.events.listen((TrayEvent event) {
    if (event.type == TrayEventType.leftClick) {
      tray.showMainWindow(focus: true);
    }
  });
}
```
