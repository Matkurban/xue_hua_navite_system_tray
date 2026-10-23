/// Severity / icon style displayed on a system tray notification.
enum TrayNotificationIconType {
  /// No icon displayed on the notification balloon.
  none,

  /// Informational icon.
  info,

  /// Warning icon.
  warning,

  /// Error / critical icon.
  error,
}

/// Configuration for displaying a desktop notification associated with the system tray.
///
/// - **Windows**: Uses `Shell_NotifyIconW` (`NIF_INFO`) to display a native
///   taskbar tray balloon / toast notification.
/// - **macOS**: Uses `UNUserNotificationCenter` (or `NSUserNotification` fallback)
///   to deliver a system notification banner.
/// - **Linux**: Uses `notify-send` / `Gio.Notification` to display a desktop
///   notification popup.
class TrayNotification {
  /// Creates a [TrayNotification].
  const TrayNotification({
    required this.title,
    required this.message,
    this.iconType = TrayNotificationIconType.info,
    this.playSound = true,
  });

  /// Primary title of the notification.
  final String title;

  /// Body text of the notification.
  final String message;

  /// Visual icon style on platforms that support notification severity icons (such as Windows).
  final TrayNotificationIconType iconType;

  /// Whether the operating system should play a notification sound.
  final bool playSound;

  /// Serializes this [TrayNotification] into a map for method channel transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'message': message,
      'iconType': iconType.name,
      'playSound': playSound,
    };
  }
}
