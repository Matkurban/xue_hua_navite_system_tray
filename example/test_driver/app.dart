import 'dart:typed_data';
import 'package:flutter_driver/driver_extension.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';
import 'package:xue_hua_navite_system_tray_example/main.dart' as app;

Future<String> _handleDriverCommand(String? command) async {
  final XueHuaNaviteSystemTray tray = XueHuaNaviteSystemTray.instance;
  switch (command) {
    case 'ping':
      return 'pong';
    case 'setTitle':
      await tray.setTitle('DriverTitle');
      return 'ok';
    case 'setToolTip':
      await tray.setToolTip('Driver tooltip');
      return 'ok';
    case 'updateSyncLabel':
      await tray.updateMenuItem('sync_now', label: 'Sync Now (driver)');
      return 'ok';
    case 'rebuildMenu':
      // Re-init is heavier; setContextMenu with a minimal safe menu.
      await tray.setContextMenu(<TrayMenuItem>[
        TrayMenuItem.action(
          id: 'show_window',
          label: 'Show Main Window',
          onTap: () async {
            await tray.showMainWindow(focus: true);
          },
        ),
        TrayMenuItem.action(
          id: 'hide_window',
          label: 'Minimize to System Tray',
          onTap: () async {
            await tray.hideMainWindow();
          },
        ),
        TrayMenuItem.action(
          id: 'sync_now',
          label: 'Sync Now (driver)',
          onTap: () {},
        ),
      ]);
      return 'ok';
    case 'popUpMenu':
      await tray.popUpContextMenu();
      return 'ok';
    case 'hideWindow':
      await tray.hideMainWindow();
      return 'ok';
    case 'showWindow':
      await tray.showMainWindow(focus: true);
      return 'ok';
    case 'isWindowVisible':
      return (await tray.isMainWindowVisible()) ? 'true' : 'false';
    case 'notify':
      final bool sent = await tray.showNotification(
        const TrayNotification(
          title: 'Driver Notify',
          message: 'from flutter_driver',
        ),
      );
      return sent ? 'true' : 'false';
    case 'queryBounds':
      final TrayBounds? b = await tray.getBounds();
      return b?.toString() ?? 'null';
    case 'setAssetIcon':
      await tray.setIcon(
        const TrayIconSource.asset(
          'assets/icons/tray_logo.png',
          iconSize: 18,
        ),
      );
      return 'ok';
    case 'setBytesIcon':
      // Tiny 1x1 PNG
      await tray.setIcon(
        TrayIconSource.bytes(
          Uint8List.fromList(<int>[
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00,
            0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
            0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
            0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63,
            0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x05,
            0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59, 0xE7, 0x00, 0x00, 0x00, 0x00,
            0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
          ]),
          iconSize: 16,
        ),
      );
      return 'ok';
    case 'caps':
      final TrayCapabilities c = await tray.getCapabilities();
      return '${c.platform}|${c.backendName}|notif=${c.supportsTrayNotification}';
    default:
      return 'unknown:$command';
  }
}

void main() {
  enableFlutterDriverExtension(handler: _handleDriverCommand);
  app.main();
}
