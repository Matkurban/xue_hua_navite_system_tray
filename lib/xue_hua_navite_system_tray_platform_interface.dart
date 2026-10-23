import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/models/tray_capabilities.dart';
import 'src/models/tray_config.dart';
import 'src/models/tray_event.dart';
import 'src/models/tray_icon_source.dart';
import 'src/models/tray_menu_item.dart';
import 'src/models/tray_notification.dart';
import 'xue_hua_navite_system_tray_method_channel.dart';

/// The common platform interface for the `xue_hua_navite_system_tray` plugin.
///
/// Platform-specific implementations should extend [XueHuaNaviteSystemTrayPlatform]
/// rather than implement it directly to ensure forward compatibility with newly
/// added methods.
abstract class XueHuaNaviteSystemTrayPlatform extends PlatformInterface {
  /// Constructs a [XueHuaNaviteSystemTrayPlatform].
  XueHuaNaviteSystemTrayPlatform() : super(token: _token);

  static final Object _token = Object();

  static XueHuaNaviteSystemTrayPlatform _instance =
      MethodChannelXueHuaNaviteSystemTray();

  /// The default instance of [XueHuaNaviteSystemTrayPlatform] to use.
  ///
  /// Defaults to [MethodChannelXueHuaNaviteSystemTray].
  static XueHuaNaviteSystemTrayPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XueHuaNaviteSystemTrayPlatform]
  /// when they register themselves.
  static set instance(XueHuaNaviteSystemTrayPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Broadcast stream of interaction events from the system tray icon,
  /// context menu items, and tray notifications.
  Stream<TrayEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  /// Initializes or reconfigures the desktop system tray with [config].
  Future<bool> initSystemTray(TrayConfig config) {
    throw UnimplementedError('initSystemTray() has not been implemented.');
  }

  /// Updates the system tray icon using [icon].
  Future<void> setIcon(TrayIconSource icon) {
    throw UnimplementedError('setIcon() has not been implemented.');
  }

  /// Updates the inline title displayed next to the tray icon (macOS & Linux AppIndicator).
  ///
  /// Pass `null` or an empty string to clear the inline title.
  Future<void> setTitle(String? title) {
    throw UnimplementedError('setTitle() has not been implemented.');
  }

  /// Updates the hover tooltip text of the system tray icon.
  ///
  /// Pass `null` or an empty string to clear the tooltip.
  Future<void> setToolTip(String? toolTip) {
    throw UnimplementedError('setToolTip() has not been implemented.');
  }

  /// Updates how mouse clicks on the tray icon trigger the context menu.
  Future<void> setMenuTrigger(
    TrayMenuTrigger trigger, {
    TrayImagePosition? imagePosition,
  }) {
    throw UnimplementedError('setMenuTrigger() has not been implemented.');
  }

  /// Shows or hides the system tray icon without destroying its state.
  Future<void> setVisible(bool visible) {
    throw UnimplementedError('setVisible() has not been implemented.');
  }

  /// Replaces the system tray context menu with [items].
  Future<void> setContextMenu(List<TrayMenuItem> items) {
    throw UnimplementedError('setContextMenu() has not been implemented.');
  }

  /// Updates a single menu item identified by [id] in-place.
  Future<void> updateMenuItem(
    String id, {
    String? label,
    String? toolTip,
    bool? enabled,
    bool? checked,
    TrayIconSource? icon,
  }) {
    throw UnimplementedError('updateMenuItem() has not been implemented.');
  }

  /// Programmatically pops up the bound context menu at the tray icon or cursor.
  Future<void> popUpContextMenu() {
    throw UnimplementedError('popUpContextMenu() has not been implemented.');
  }

  /// Retrieves the screen bounds of the system tray icon, or `null` if unavailable.
  Future<TrayBounds?> getBounds() {
    throw UnimplementedError('getBounds() has not been implemented.');
  }

  /// Displays a system tray / balloon notification.
  Future<bool> showNotification(TrayNotification notification) {
    throw UnimplementedError('showNotification() has not been implemented.');
  }

  /// Shows or hides the application's Dock icon on macOS.
  ///
  /// On Windows and Linux, this method completes safely as a no-op.
  Future<void> setDockIconVisible(bool visible) {
    throw UnimplementedError('setDockIconVisible() has not been implemented.');
  }

  /// Restores and brings the main application window to the foreground.
  Future<void> showMainWindow({bool focus = true}) {
    throw UnimplementedError('showMainWindow() has not been implemented.');
  }

  /// Hides the main application window (e.g. for "Minimize to Tray").
  Future<void> hideMainWindow() {
    throw UnimplementedError('hideMainWindow() has not been implemented.');
  }

  /// Returns `true` if the main application window is currently visible.
  Future<bool> isMainWindowVisible() {
    throw UnimplementedError('isMainWindowVisible() has not been implemented.');
  }

  /// Queries the runtime capabilities of the underlying platform tray backend.
  Future<TrayCapabilities> getCapabilities() {
    throw UnimplementedError('getCapabilities() has not been implemented.');
  }

  /// Removes the system tray icon and releases associated native resources.
  Future<void> destroy() {
    throw UnimplementedError('destroy() has not been implemented.');
  }
}
