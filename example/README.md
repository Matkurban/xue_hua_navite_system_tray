# xue_hua_navite_system_tray_example

Interactive desktop workbench demonstrating all features of `xue_hua_navite_system_tray`:

- System tray initialization (`initSystemTray`), visibility toggling (`setVisible`), and cleanup (`destroy`)
- Switching between OS system symbols (`TrayIconSource.system`) and dynamically rendered in-memory PNG badge icons (`TrayIconSource.bytes`)
- Inline status bar titles (`setTitle`) with a live 1-second CPU metric ticker and hover tooltips (`setToolTip`)
- Context menu construction (`TrayMenuItem.header`, `action`, `checkbox`, `radio`, `submenu`, `separator`) with keyboard shortcuts (`TrayMenuShortcut`) and in-place single-item updates (`updateMenuItem`)
- Click trigger mode switching (`TrayMenuTrigger.rightClick`, `leftClick`, `anyClick`, `manual`) and programmatic menu popup (`popUpContextMenu`)
- Main window visibility control (`hideMainWindow`, `showMainWindow`), macOS Dock icon visibility toggling (`setDockIconVisible`), tray notifications (`showNotification`), screen bounds inspection (`getBounds`), and live event logging (`events`)
