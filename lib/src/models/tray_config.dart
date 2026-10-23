import 'tray_icon_source.dart';
import 'tray_menu_item.dart';

/// Controls how user mouse clicks on the system tray icon trigger the context menu.
enum TrayMenuTrigger {
  /// Right-clicking opens the context menu; left-clicking emits a [TrayEventType.leftClick]
  /// event to Dart without automatically opening the menu.
  ///
  /// This is the standard convention on Windows and cross-platform desktop apps.
  /// Note: On Linux `AppIndicator` (`StatusNotifierItem`), the desktop panel host
  /// always opens the menu on primary click per the SNI specification.
  rightClick,

  /// Left-clicking opens the context menu; right-clicking emits a [TrayEventType.rightClick]
  /// event to Dart.
  leftClick,

  /// Both left-clicking and right-clicking open the context menu automatically.
  ///
  /// This matches the standard macOS `NSStatusItem` menu bar behavior.
  anyClick,

  /// Never open the context menu automatically on click; all clicks are forwarded
  /// as events to Dart, and the app can call `popUpContextMenu()` manually.
  ///
  /// Note: On Linux `AppIndicator`, the menu remains attached to the indicator
  /// because `StatusNotifierItem` requires a bound `GtkMenu`.
  manual,
}

/// Controls the placement of the icon relative to the inline title on macOS.
enum TrayImagePosition {
  /// Places the icon to the left of the title (leading edge in LTR).
  leading,

  /// Places the icon to the right of the title (trailing edge in LTR).
  trailing,

  /// Displays only the icon, hiding the title until changed.
  onlyImage,

  /// Displays only the title, hiding the icon.
  onlyTitle,
}

/// Configuration parameters for initializing or updating the desktop system tray.
class TrayConfig {
  /// Creates a [TrayConfig] for initializing the system tray.
  const TrayConfig({
    this.icon,
    this.title,
    this.toolTip,
    this.visible = true,
    this.menuTrigger = TrayMenuTrigger.rightClick,
    this.imagePosition = TrayImagePosition.leading,
    this.menuItems = const <TrayMenuItem>[],
  });

  /// The icon displayed in the system tray / status bar.
  final TrayIconSource? icon;

  /// Optional inline text displayed next to the tray icon.
  ///
  /// - **macOS**: Rendered directly in the `NSStatusBarButton` next to the icon.
  /// - **Linux**: Rendered via `app_indicator_set_label` on supported desktop panels.
  /// - **Windows**: Windows notification area icons do not display inline text;
  ///   when [toolTip] is omitted, [title] is used as the fallback tooltip.
  final String? title;

  /// Hover tooltip text displayed when the user points at the tray icon.
  ///
  /// On Windows, tooltips are truncated to 127 characters by the Win32 shell.
  final String? toolTip;

  /// Whether the system tray icon is initially visible.
  final bool visible;

  /// Defines which mouse button automatically opens the context menu.
  final TrayMenuTrigger menuTrigger;

  /// Placement of the icon relative to [title] on macOS.
  final TrayImagePosition imagePosition;

  /// Initial list of context menu items to attach to the system tray.
  final List<TrayMenuItem> menuItems;

  /// Serializes this [TrayConfig] into a map for method channel transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (icon != null) 'icon': icon!.toMap(),
      if (title != null) 'title': title,
      if (toolTip != null) 'toolTip': toolTip,
      'visible': visible,
      'menuTrigger': menuTrigger.name,
      'imagePosition': imagePosition.name,
      'menuItems': menuItems.map((TrayMenuItem item) => item.toMap()).toList(),
    };
  }
}
