/// Describes the runtime capabilities of the underlying desktop system tray backend.
///
/// Because macOS (`NSStatusItem`), Windows (`Shell_NotifyIconW`), and Linux
/// (`AppIndicator3` / `GtkStatusIcon`) differ in what their native status areas
/// support, use `XueHuaNaviteSystemTray.instance.getCapabilities()` to inspect
/// available features at runtime.
class TrayCapabilities {
  /// Creates a [TrayCapabilities] snapshot.
  const TrayCapabilities({
    required this.platform,
    required this.backendName,
    required this.supportsInlineTitle,
    required this.supportsTemplateIcon,
    required this.supportsSystemSymbol,
    required this.supportsIconBounds,
    required this.supportsLeftRightClickDistinction,
    required this.supportsDoubleClick,
    required this.supportsMiddleClick,
    required this.supportsMenuIcons,
    required this.supportsMenuShortcuts,
    required this.supportsMenuTooltips,
    required this.supportsProgrammaticMenuPopup,
    required this.supportsDockVisibilityToggle,
    required this.supportsTrayNotification,
  });

  /// Parses a [TrayCapabilities] instance from a native method channel map.
  factory TrayCapabilities.fromMap(Map<dynamic, dynamic> map) {
    return TrayCapabilities(
      platform: (map['platform'] as String?) ?? 'unknown',
      backendName: (map['backendName'] as String?) ?? 'unknown',
      supportsInlineTitle: (map['supportsInlineTitle'] as bool?) ?? false,
      supportsTemplateIcon: (map['supportsTemplateIcon'] as bool?) ?? false,
      supportsSystemSymbol: (map['supportsSystemSymbol'] as bool?) ?? false,
      supportsIconBounds: (map['supportsIconBounds'] as bool?) ?? false,
      supportsLeftRightClickDistinction:
          (map['supportsLeftRightClickDistinction'] as bool?) ?? false,
      supportsDoubleClick: (map['supportsDoubleClick'] as bool?) ?? false,
      supportsMiddleClick: (map['supportsMiddleClick'] as bool?) ?? false,
      supportsMenuIcons: (map['supportsMenuIcons'] as bool?) ?? false,
      supportsMenuShortcuts: (map['supportsMenuShortcuts'] as bool?) ?? false,
      supportsMenuTooltips: (map['supportsMenuTooltips'] as bool?) ?? false,
      supportsProgrammaticMenuPopup:
          (map['supportsProgrammaticMenuPopup'] as bool?) ?? false,
      supportsDockVisibilityToggle:
          (map['supportsDockVisibilityToggle'] as bool?) ?? false,
      supportsTrayNotification:
          (map['supportsTrayNotification'] as bool?) ?? false,
    );
  }

  /// Operating system identifier (`'macos'`, `'windows'`, or `'linux'`).
  final String platform;

  /// Native tray implementation in use (`'NSStatusItem'`, `'Shell_NotifyIconW'`,
  /// `'AppIndicator3'`, `'AyatanaAppIndicator3'`, or `'GtkStatusIcon'`).
  final String backendName;

  /// Whether text can be rendered directly beside the icon in the status bar
  /// (`true` on macOS and Linux `AppIndicator`; `false` on Windows).
  final bool supportsInlineTitle;

  /// Whether monochrome template icons automatically tint to light/dark mode
  /// (`true` on macOS).
  final bool supportsTemplateIcon;

  /// Whether native OS symbol/theme names can be used via `TrayIconSource.system`.
  final bool supportsSystemSymbol;

  /// Whether `getBounds()` returns accurate screen coordinates of the tray icon.
  final bool supportsIconBounds;

  /// Whether left-click and right-click on the tray icon can be handled independently.
  ///
  /// Note: On Linux `AppIndicator` (`StatusNotifierItem`), the panel always opens
  /// the bound `GtkMenu` on primary click.
  final bool supportsLeftRightClickDistinction;

  /// Whether double-clicking the tray icon emits `leftDoubleClick` / `rightDoubleClick`.
  final bool supportsDoubleClick;

  /// Whether middle-clicking the tray icon emits `middleClick`.
  final bool supportsMiddleClick;

  /// Whether custom icons can be displayed inside context menu items.
  final bool supportsMenuIcons;

  /// Whether keyboard shortcut hints can be displayed on context menu items.
  final bool supportsMenuShortcuts;

  /// Whether individual context menu items support hover tooltips.
  final bool supportsMenuTooltips;

  /// Whether `popUpContextMenu()` can open the menu programmatically.
  final bool supportsProgrammaticMenuPopup;

  /// Whether `setDockIconVisible()` can show/hide the app's Dock icon (`true` on macOS).
  final bool supportsDockVisibilityToggle;

  /// Whether `showNotification()` is supported on the current system.
  final bool supportsTrayNotification;

  /// Serializes this [TrayCapabilities] into a map.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'platform': platform,
    'backendName': backendName,
    'supportsInlineTitle': supportsInlineTitle,
    'supportsTemplateIcon': supportsTemplateIcon,
    'supportsSystemSymbol': supportsSystemSymbol,
    'supportsIconBounds': supportsIconBounds,
    'supportsLeftRightClickDistinction': supportsLeftRightClickDistinction,
    'supportsDoubleClick': supportsDoubleClick,
    'supportsMiddleClick': supportsMiddleClick,
    'supportsMenuIcons': supportsMenuIcons,
    'supportsMenuShortcuts': supportsMenuShortcuts,
    'supportsMenuTooltips': supportsMenuTooltips,
    'supportsProgrammaticMenuPopup': supportsProgrammaticMenuPopup,
    'supportsDockVisibilityToggle': supportsDockVisibilityToggle,
    'supportsTrayNotification': supportsTrayNotification,
  };
}
