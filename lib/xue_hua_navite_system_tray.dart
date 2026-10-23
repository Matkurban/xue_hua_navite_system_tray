import 'src/models/tray_capabilities.dart';
import 'src/models/tray_config.dart';
import 'src/models/tray_event.dart';
import 'src/models/tray_icon_source.dart';
import 'src/models/tray_menu_item.dart';
import 'src/models/tray_notification.dart';
import 'xue_hua_navite_system_tray_platform_interface.dart';

export 'src/models/tray_capabilities.dart';
export 'src/models/tray_config.dart';
export 'src/models/tray_event.dart';
export 'src/models/tray_icon_source.dart';
export 'src/models/tray_menu_item.dart';
export 'src/models/tray_notification.dart';
export 'xue_hua_navite_system_tray_method_channel.dart';
export 'xue_hua_navite_system_tray_platform_interface.dart';

/// High-level API for managing a native desktop System Tray / Status Bar item
/// across **macOS**, **Windows**, and **Linux**.
///
/// Access the shared singleton via [XueHuaNaviteSystemTray.instance]:
/// ```dart
/// final tray = XueHuaNaviteSystemTray.instance;
/// await tray.initSystemTray(
///   TrayConfig(
///     icon: const TrayIconSource.asset('assets/tray_icon.png', isTemplate: true),
///     title: 'XueHua',
///     toolTip: 'XueHua Desktop Client',
///     menuItems: [
///       TrayMenuItem.action(
///         id: 'show_window',
///         label: 'Show Main Window',
///         onTap: () => tray.showMainWindow(),
///       ),
///       const TrayMenuItem.separator(),
///       TrayMenuItem.action(
///         id: 'quit',
///         label: 'Quit',
///         shortcut: const TrayMenuShortcut('q', meta: true),
///       ),
///     ],
///   ),
/// );
/// ```
class XueHuaNaviteSystemTray {
  /// Constructs a [XueHuaNaviteSystemTray] delegating to [XueHuaNaviteSystemTrayPlatform.instance].
  factory XueHuaNaviteSystemTray() => instance;

  const XueHuaNaviteSystemTray._();

  /// Shared singleton instance of [XueHuaNaviteSystemTray].
  static const XueHuaNaviteSystemTray instance = XueHuaNaviteSystemTray._();

  XueHuaNaviteSystemTrayPlatform get _platform =>
      XueHuaNaviteSystemTrayPlatform.instance;

  /// Broadcast stream of all interaction events emitted by the system tray icon,
  /// context menu items, and tray notifications.
  Stream<TrayEvent> get events => _platform.events;

  /// Initializes or updates the system tray icon, title, tooltip, click trigger,
  /// and context menu using [config].
  ///
  /// Returns `true` when the native tray item was created or updated on the host OS.
  Future<bool> initSystemTray(TrayConfig config) {
    return _platform.initSystemTray(config);
  }

  /// Updates the system tray icon dynamically.
  ///
  /// Supports [TrayIconSource.asset], [TrayIconSource.file],
  /// [TrayIconSource.bytes], and [TrayIconSource.system].
  Future<void> setIcon(TrayIconSource icon) {
    return _platform.setIcon(icon);
  }

  /// Sets or clears the inline text displayed next to the tray icon.
  ///
  /// - **macOS**: Updates `NSStatusBarButton.title`.
  /// - **Linux**: Updates `app_indicator_set_label` on `AppIndicator` backends.
  /// - **Windows**: Windows notification icons do not display inline text next
  ///   to icons; if no tooltip was set, the title is used as a fallback tooltip.
  Future<void> setTitle(String? title) {
    return _platform.setTitle(title);
  }

  /// Sets or clears the hover tooltip text of the tray icon.
  Future<void> setToolTip(String? toolTip) {
    return _platform.setToolTip(toolTip);
  }

  /// Configures how mouse clicks on the tray icon open the context menu, and
  /// optionally updates the icon placement relative to the title on macOS.
  Future<void> setMenuTrigger(
    TrayMenuTrigger trigger, {
    TrayImagePosition? imagePosition,
  }) {
    return _platform.setMenuTrigger(trigger, imagePosition: imagePosition);
  }

  /// Shows or hides the system tray icon without destroying its configuration.
  Future<void> setVisible(bool visible) {
    return _platform.setVisible(visible);
  }

  /// Sets or replaces the entire system tray context menu hierarchy.
  Future<void> setContextMenu(List<TrayMenuItem> items) {
    return _platform.setContextMenu(items);
  }

  /// Dynamically updates a single existing menu item by its [id] without
  /// rebuilding the full menu tree.
  Future<void> updateMenuItem(
    String id, {
    String? label,
    String? toolTip,
    bool? enabled,
    bool? checked,
    TrayIconSource? icon,
  }) {
    return _platform.updateMenuItem(
      id,
      label: label,
      toolTip: toolTip,
      enabled: enabled,
      checked: checked,
      icon: icon,
    );
  }

  /// Programmatically opens the bound context menu at the system tray icon or cursor.
  Future<void> popUpContextMenu() {
    return _platform.popUpContextMenu();
  }

  /// Returns the screen rectangle ([TrayBounds]) of the system tray icon, or
  /// `null` if the host desktop environment does not expose icon geometry
  /// (such as Linux Wayland / `StatusNotifierItem`).
  Future<TrayBounds?> getBounds() {
    return _platform.getBounds();
  }

  /// Displays a desktop notification associated with the system tray.
  Future<bool> showNotification(TrayNotification notification) {
    return _platform.showNotification(notification);
  }

  /// Shows or hides the application's Dock icon on macOS (`NSApp.setActivationPolicy`).
  ///
  /// Useful for building menu-bar-only utilities or "Hide Dock Icon when minimized
  /// to tray" workflows on macOS. Safely completes as a no-op on Windows and Linux.
  Future<void> setDockIconVisible(bool visible) {
    return _platform.setDockIconVisible(visible);
  }

  /// Restores and brings the main Flutter desktop window to the foreground.
  Future<void> showMainWindow({bool focus = true}) {
    return _platform.showMainWindow(focus: focus);
  }

  /// Hides the main Flutter desktop window (e.g. when minimizing to the system tray).
  Future<void> hideMainWindow() {
    return _platform.hideMainWindow();
  }

  /// Returns `true` if the main Flutter desktop window is currently visible.
  Future<bool> isMainWindowVisible() {
    return _platform.isMainWindowVisible();
  }

  /// Queries the runtime capabilities of the active desktop system tray backend.
  Future<TrayCapabilities> getCapabilities() {
    return _platform.getCapabilities();
  }

  /// Removes the system tray icon from the status bar / notification area and
  /// releases native resources.
  Future<void> destroy() {
    return _platform.destroy();
  }
}
