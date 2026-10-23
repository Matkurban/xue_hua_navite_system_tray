/// Enumeration of interaction event types emitted by the system tray.
enum TrayEventType {
  /// The user single-clicked the tray icon with the left (primary) mouse button.
  leftClick,

  /// The user double-clicked the tray icon with the left (primary) mouse button.
  leftDoubleClick,

  /// The user single-clicked the tray icon with the right (secondary) mouse button.
  rightClick,

  /// The user double-clicked the tray icon with the right (secondary) mouse button.
  rightDoubleClick,

  /// The user clicked the tray icon with the middle (auxiliary) mouse button.
  middleClick,

  /// The user selected an item in the system tray context menu.
  menuItemClick,

  /// The user clicked on a system tray notification / balloon popup.
  notificationClick,
}

/// Mouse button associated with a tray click event.
enum TrayMouseButton {
  /// Primary (left) mouse button.
  left,

  /// Secondary (right) mouse button.
  right,

  /// Auxiliary (middle/wheel) mouse button.
  middle,

  /// No mouse button (e.g. keyboard activation or notification click).
  none,
}

/// Represents the screen position and size of the system tray icon.
class TrayBounds {
  /// Creates a [TrayBounds] rectangle in screen coordinates.
  const TrayBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Parses a [TrayBounds] from a native method channel map.
  factory TrayBounds.fromMap(Map<dynamic, dynamic> map) {
    return TrayBounds(
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Horizontal screen coordinate of the tray icon's origin.
  final double x;

  /// Vertical screen coordinate of the tray icon's origin.
  final double y;

  /// Width of the tray icon button in screen units.
  final double width;

  /// Height of the tray icon button in screen units.
  final double height;

  /// Horizontal center point of the tray icon.
  double get centerX => x + width / 2.0;

  /// Vertical center point of the tray icon.
  double get centerY => y + height / 2.0;

  /// Serializes this [TrayBounds] into a map.
  Map<String, double> toMap() => <String, double>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  @override
  String toString() =>
      'TrayBounds(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, '
      'width: ${width.toStringAsFixed(1)}, height: ${height.toStringAsFixed(1)})';
}

/// Represents an interaction event originating from the system tray icon,
/// context menu, or tray notification.
class TrayEvent {
  /// Creates a [TrayEvent].
  const TrayEvent({
    required this.type,
    this.mouseButton = TrayMouseButton.none,
    this.menuItemId,
    this.checked,
    this.bounds,
    this.cursorX,
    this.cursorY,
    this.timestamp,
  });

  /// Constructs a [TrayEvent] from a raw method channel payload map.
  factory TrayEvent.fromMap(Map<dynamic, dynamic> map) {
    final String rawType = (map['type'] as String?) ?? 'leftClick';
    final TrayEventType parsedType = TrayEventType.values.firstWhere(
      (TrayEventType e) => e.name == rawType,
      orElse: () => TrayEventType.leftClick,
    );

    final String rawButton = (map['mouseButton'] as String?) ?? 'none';
    final TrayMouseButton parsedButton = TrayMouseButton.values.firstWhere(
      (TrayMouseButton e) => e.name == rawButton,
      orElse: () => TrayMouseButton.none,
    );

    final Map<dynamic, dynamic>? rawBounds =
        map['bounds'] as Map<dynamic, dynamic>?;

    return TrayEvent(
      type: parsedType,
      mouseButton: parsedButton,
      menuItemId: map['menuItemId'] as String?,
      checked: map['checked'] as bool?,
      bounds: rawBounds != null ? TrayBounds.fromMap(rawBounds) : null,
      cursorX: (map['cursorX'] as num?)?.toDouble(),
      cursorY: (map['cursorY'] as num?)?.toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['timestamp'] as num).toInt(),
            )
          : DateTime.now(),
    );
  }

  /// The type of system tray interaction that occurred.
  final TrayEventType type;

  /// The mouse button involved in the click, if applicable.
  final TrayMouseButton mouseButton;

  /// The identifier of the clicked menu item when [type] is [TrayEventType.menuItemClick].
  final String? menuItemId;

  /// The updated checked state when a checkbox or radio menu item is clicked.
  final bool? checked;

  /// The screen bounds of the tray icon at the moment of the event, if available.
  final TrayBounds? bounds;

  /// Horizontal screen coordinate of the mouse cursor when the event occurred.
  final double? cursorX;

  /// Vertical screen coordinate of the mouse cursor when the event occurred.
  final double? cursorY;

  /// Timestamp when the event was received.
  final DateTime? timestamp;

  @override
  String toString() {
    return 'TrayEvent(type: ${type.name}, mouseButton: ${mouseButton.name}, '
        'menuItemId: $menuItemId, checked: $checked, bounds: $bounds)';
  }
}
