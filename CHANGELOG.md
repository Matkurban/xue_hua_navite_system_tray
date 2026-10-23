## 1.0.0

* Initial stable release of `xue_hua_navite_system_tray` by Matkurban (`3496354336@qq.com`).
* Implemented full native desktop System Tray / Status Bar support across **macOS** (`NSStatusItem`), **Windows** (`Shell_NotifyIconW` + GDI+), and **Linux** (`AyatanaAppIndicator3` / `AppIndicator3` dynamic loading with `GtkStatusIcon` fallback).
* Added `TrayIconSource` supporting Flutter assets, local files, raw in-memory `Uint8List` image bytes, and native system symbols / icon themes (`SF Symbols` on macOS, Win32 stock icons on Windows, freedesktop icon theme names on Linux).
* Added rich context menu support (`TrayMenuItem.action`, `checkbox`, `radio`, `submenu`, `separator`, `header`) with icons, keyboard shortcuts (`TrayMenuShortcut`), tooltips, automatic callback dispatch, and in-place single-item updates (`updateMenuItem`).
* Added configurable click triggers (`TrayMenuTrigger.rightClick`, `leftClick`, `anyClick`, `manual`), screen bounds inspection (`getBounds`), tray notifications (`showNotification`), main window visibility helpers (`showMainWindow`, `hideMainWindow`, `isMainWindowVisible`), macOS Dock icon toggling (`setDockIconVisible`), and runtime capability discovery (`getCapabilities`).
