import 'tray_icon_source.dart';

/// Specifies the kind of entry in a system tray context menu.
enum TrayMenuItemType {
  /// A standard clickable command item.
  action,

  /// A toggleable checkbox menu item with a boolean `checked` state.
  checkbox,

  /// A mutually-exclusive radio menu item belonging to a `groupId`.
  radio,

  /// A parent menu item that expands a nested list of `children`.
  submenu,

  /// A horizontal visual divider line between menu items.
  separator,

  /// A non-interactive section header label used to group related menu items.
  header,
}

/// Represents a keyboard shortcut displayed alongside a [TrayMenuItem].
class TrayMenuShortcut {
  /// Creates a keyboard shortcut definition for a menu item.
  ///
  /// [key] should be a single character (e.g. `'s'`, `'q'`, `'1'`) or key name.
  const TrayMenuShortcut(
    this.key, {
    this.meta = false,
    this.control = false,
    this.alt = false,
    this.shift = false,
  });

  /// The primary key trigger (e.g. `'n'`, `'q'`, `'r'`).
  final String key;

  /// Command (`⌘`) modifier on macOS, or Super/Windows key on Windows/Linux.
  final bool meta;

  /// Control (`⌃` / `Ctrl`) modifier.
  final bool control;

  /// Option (`⌥`) on macOS or `Alt` modifier on Windows/Linux.
  final bool alt;

  /// Shift (`⇧`) modifier.
  final bool shift;

  /// Serializes this [TrayMenuShortcut] into a map for method channel transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'key': key,
      'meta': meta,
      'control': control,
      'alt': alt,
      'shift': shift,
    };
  }

  /// Formats a human-readable shortcut hint for Windows/Linux labels (e.g. `Ctrl+Shift+S`).
  String toDisplayLabel() {
    final List<String> parts = <String>[];
    if (control) parts.add('Ctrl');
    if (alt) parts.add('Alt');
    if (shift) parts.add('Shift');
    if (meta) parts.add('Cmd');
    parts.add(key.toUpperCase());
    return parts.join('+');
  }
}

/// Callback signature for standard or radio menu item clicks.
typedef TrayMenuActionCallback = void Function();

/// Callback signature for checkbox menu item toggles.
typedef TrayMenuCheckboxCallback = void Function(bool checked);

/// Represents a single entry in the native system tray context menu.
///
/// Use the named constructors to build a structured menu hierarchy:
/// - [TrayMenuItem.action] for standard clickable commands
/// - [TrayMenuItem.checkbox] for checkable toggle items
/// - [TrayMenuItem.radio] for radio-group selections
/// - [TrayMenuItem.submenu] for nested submenus
/// - [TrayMenuItem.separator] for visual dividers
/// - [TrayMenuItem.header] for section headers
class TrayMenuItem {
  /// Creates a standard clickable menu item.
  const TrayMenuItem.action({
    required this.id,
    required this.label,
    this.toolTip,
    this.enabled = true,
    this.icon,
    this.shortcut,
    this.onTap,
  }) : type = TrayMenuItemType.action,
       checked = false,
       groupId = null,
       children = const <TrayMenuItem>[],
       onChanged = null;

  /// Creates a toggleable checkbox menu item.
  const TrayMenuItem.checkbox({
    required this.id,
    required this.label,
    this.checked = false,
    this.toolTip,
    this.enabled = true,
    this.icon,
    this.shortcut,
    this.onChanged,
  }) : type = TrayMenuItemType.checkbox,
       groupId = null,
       children = const <TrayMenuItem>[],
       onTap = null;

  /// Creates a radio button menu item associated with an optional [groupId].
  const TrayMenuItem.radio({
    required this.id,
    required this.label,
    this.groupId,
    this.checked = false,
    this.toolTip,
    this.enabled = true,
    this.shortcut,
    this.onTap,
  }) : type = TrayMenuItemType.radio,
       icon = null,
       children = const <TrayMenuItem>[],
       onChanged = null;

  /// Creates a submenu item containing nested [children] items.
  const TrayMenuItem.submenu({
    required this.id,
    required this.label,
    required this.children,
    this.toolTip,
    this.enabled = true,
    this.icon,
  }) : type = TrayMenuItemType.submenu,
       checked = false,
       groupId = null,
       shortcut = null,
       onTap = null,
       onChanged = null;

  /// Creates a horizontal separator divider item.
  const TrayMenuItem.separator({
    this.id = 'separator',
  }) : type = TrayMenuItemType.separator,
       label = '',
       toolTip = null,
       enabled = false,
       checked = false,
       groupId = null,
       icon = null,
       shortcut = null,
       children = const <TrayMenuItem>[],
       onTap = null,
       onChanged = null;

  /// Creates a non-interactive section header item.
  const TrayMenuItem.header({
    required this.id,
    required this.label,
  }) : type = TrayMenuItemType.header,
       toolTip = null,
       enabled = false,
       checked = false,
       groupId = null,
       icon = null,
       shortcut = null,
       children = const <TrayMenuItem>[],
       onTap = null,
       onChanged = null;

  /// Unique identifier used to identify the menu item in events and dynamic updates.
  final String id;

  /// The type of this menu item.
  final TrayMenuItemType type;

  /// Display text shown in the menu.
  final String label;

  /// Optional hover tooltip or subtitle description (supported on macOS).
  final String? toolTip;

  /// Whether the user can interact with this menu item.
  final bool enabled;

  /// Whether this checkbox or radio item is currently checked.
  final bool checked;

  /// Optional group identifier for [TrayMenuItemType.radio] items.
  final String? groupId;

  /// Optional icon displayed next to the menu item label.
  final TrayIconSource? icon;

  /// Optional keyboard shortcut hint displayed next to the menu item.
  final TrayMenuShortcut? shortcut;

  /// Nested menu items when [type] is [TrayMenuItemType.submenu].
  final List<TrayMenuItem> children;

  /// Optional callback invoked automatically when this action or radio item is clicked.
  final TrayMenuActionCallback? onTap;

  /// Optional callback invoked automatically when this checkbox item is toggled.
  final TrayMenuCheckboxCallback? onChanged;

  /// Serializes this [TrayMenuItem] and any nested [children] for method channel transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'label': label,
      if (toolTip != null) 'toolTip': toolTip,
      'enabled': enabled,
      'checked': checked,
      if (groupId != null) 'groupId': groupId,
      if (icon != null) 'icon': icon!.toMap(),
      if (shortcut != null) ...<String, dynamic>{
        'shortcut': shortcut!.toMap(),
        'shortcutLabel': shortcut!.toDisplayLabel(),
      },
      if (children.isNotEmpty)
        'children': children.map((TrayMenuItem e) => e.toMap()).toList(),
    };
  }
}
