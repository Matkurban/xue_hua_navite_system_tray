import 'dart:typed_data';

/// Defines the source type of an icon used in the system tray or context menu.
enum TrayIconSourceType {
  /// A Flutter asset path declared in `pubspec.yaml` (e.g. `'assets/tray_icon.png'`).
  asset,

  /// An absolute file path on the local file system.
  file,

  /// Raw encoded image bytes (such as PNG, ICO, or BMP) in memory.
  bytes,

  /// A platform-provided system icon or symbol name:
  /// - **macOS**: SF Symbols name (e.g. `'sparkles'`, `'bell.fill'`, `'tray.full'`).
  /// - **Windows**: Standard Win32 system icon identifier (`'application'`,
  ///   `'info'`, `'warning'`, `'error'`, `'shield'`, `'question'`).
  /// - **Linux**: Freedesktop Icon Theme name (e.g. `'application-exit'`,
  ///   `'dialog-information'`, `'indicator-messages'`).
  system,
}

/// Represents an icon source for the system tray button or a context menu item.
///
/// Use one of the named constructors ([TrayIconSource.asset],
/// [TrayIconSource.file], [TrayIconSource.bytes], or [TrayIconSource.system])
/// to provide an icon across macOS, Windows, and Linux.
class TrayIconSource {
  /// Creates a [TrayIconSource] from a Flutter asset key.
  ///
  /// Example:
  /// ```dart
  /// const icon = TrayIconSource.asset('assets/icons/tray_template.png');
  /// ```
  const TrayIconSource.asset(
    String this.path, {
    this.isTemplate = false,
    this.iconSize,
  }) : type = TrayIconSourceType.asset,
       bytes = null,
       systemName = null;

  /// Creates a [TrayIconSource] from an absolute file system path.
  ///
  /// Example:
  /// ```dart
  /// const icon = TrayIconSource.file('/path/to/custom_icon.png');
  /// ```
  const TrayIconSource.file(
    String this.path, {
    this.isTemplate = false,
    this.iconSize,
  }) : type = TrayIconSourceType.file,
       bytes = null,
       systemName = null;

  /// Creates a [TrayIconSource] from raw encoded image bytes (PNG/ICO/BMP).
  ///
  /// Useful for dynamically generated icons, badges, or downloaded images.
  const TrayIconSource.bytes(
    Uint8List this.bytes, {
    this.isTemplate = false,
    this.iconSize,
  }) : type = TrayIconSourceType.bytes,
       path = null,
       systemName = null;

  /// Creates a [TrayIconSource] referencing a native OS symbol or theme icon.
  ///
  /// - On **macOS**, pass an SF Symbol name (e.g. `'bolt.fill'`, `'cloud.sun.fill'`).
  /// - On **Windows**, pass `'application'`, `'info'`, `'warning'`, `'error'`,
  ///   `'shield'`, or `'question'`.
  /// - On **Linux**, pass a freedesktop icon theme name (e.g. `'dialog-information'`,
  ///   `'audio-volume-high'`, `'network-transmit-receive'`).
  const TrayIconSource.system(
    String this.systemName, {
    this.isTemplate = true,
    this.iconSize,
  }) : type = TrayIconSourceType.system,
       path = null,
       bytes = null;

  /// The underlying source type of this icon.
  final TrayIconSourceType type;

  /// The asset key or local file path when [type] is [TrayIconSourceType.asset]
  /// or [TrayIconSourceType.file].
  final String? path;

  /// Raw encoded image bytes when [type] is [TrayIconSourceType.bytes].
  final Uint8List? bytes;

  /// The platform system symbol or icon theme identifier when [type] is
  /// [TrayIconSourceType.system].
  final String? systemName;

  /// Whether the icon should be rendered as a monochrome template image on macOS.
  ///
  /// When `true` on macOS, `NSImage.isTemplate` is enabled so the operating
  /// system automatically adapts the icon tint to light and dark menu bars.
  /// Ignored on Windows and Linux.
  final bool isTemplate;

  /// Optional target logical size in points/pixels (default is `18.0` on macOS
  /// status bar and `16.0` for menu items).
  final double? iconSize;

  /// Serializes this [TrayIconSource] into a map suitable for method channel transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.name,
      if (path != null) 'path': path,
      if (bytes != null) 'bytes': bytes,
      if (systemName != null) 'systemName': systemName,
      'isTemplate': isTemplate,
      if (iconSize != null) 'iconSize': iconSize,
    };
  }

  /// Creates a copy of this [TrayIconSource] with the given fields replaced.
  TrayIconSource copyWith({
    bool? isTemplate,
    double? iconSize,
  }) {
    switch (type) {
      case TrayIconSourceType.asset:
        return TrayIconSource.asset(
          path!,
          isTemplate: isTemplate ?? this.isTemplate,
          iconSize: iconSize ?? this.iconSize,
        );
      case TrayIconSourceType.file:
        return TrayIconSource.file(
          path!,
          isTemplate: isTemplate ?? this.isTemplate,
          iconSize: iconSize ?? this.iconSize,
        );
      case TrayIconSourceType.bytes:
        return TrayIconSource.bytes(
          bytes!,
          isTemplate: isTemplate ?? this.isTemplate,
          iconSize: iconSize ?? this.iconSize,
        );
      case TrayIconSourceType.system:
        return TrayIconSource.system(
          systemName!,
          isTemplate: isTemplate ?? this.isTemplate,
          iconSize: iconSize ?? this.iconSize,
        );
    }
  }
}
