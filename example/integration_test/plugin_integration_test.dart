import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  TrayIconSource platformSystemIcon() {
    if (Platform.isWindows) {
      return const TrayIconSource.system('application');
    }
    if (Platform.isMacOS) {
      return const TrayIconSource.system('sparkles', isTemplate: true);
    }
    return const TrayIconSource.system('applications-system');
  }

  testWidgets('Tray API smoke: capabilities, init, menu, notify, bounds', (
    WidgetTester tester,
  ) async {
    final XueHuaNaviteSystemTray tray = XueHuaNaviteSystemTray.instance;

    final TrayCapabilities capabilities = await tray.getCapabilities();
    expect(capabilities.platform.isNotEmpty, isTrue);
    expect(capabilities.backendName.isNotEmpty, isTrue);
    // Platform backend identity.
    if (Platform.isWindows) {
      expect(capabilities.backendName.toLowerCase(), contains('shell_notifyicon'));
      expect(capabilities.supportsInlineTitle, isFalse);
    }
    if (Platform.isLinux) {
      final String backend = capabilities.backendName.toLowerCase();
      expect(
        backend.contains('ayatana') ||
            backend.contains('appindicator') ||
            backend.contains('gtkstatusicon'),
        isTrue,
        reason: 'Unexpected Linux tray backend: ${capabilities.backendName}',
      );
    }

    final bool initialized = await tray.initSystemTray(
      TrayConfig(
        icon: platformSystemIcon(),
        title: 'XH Tray Test',
        toolTip: 'Integration Test Tray',
        menuTrigger: TrayMenuTrigger.rightClick,
        menuItems: <TrayMenuItem>[
          const TrayMenuItem.header(id: 'hdr', label: 'Test Header'),
          TrayMenuItem.action(id: 'ping', label: 'Ping', onTap: () {}),
          const TrayMenuItem.separator(),
          TrayMenuItem.checkbox(
            id: 'cb',
            label: 'Checked',
            checked: true,
            onChanged: (_) {},
          ),
        ],
      ),
    );
    expect(initialized, isTrue);

    await tray.setToolTip('Updated tooltip from integration test');
    await tray.setTitle('XH');
    await tray.setVisible(true);
    await tray.updateMenuItem('ping', label: 'Ping (updated)', enabled: true);

    final TrayBounds? bounds = await tray.getBounds();
    // Bounds should be available on Windows via Shell_NotifyIconGetRect.
    // On Linux, AppIndicator backends often cannot report icon geometry.
    if (Platform.isWindows) {
      expect(bounds, isNotNull);
      expect(bounds!.width > 0, isTrue);
      expect(bounds.height > 0, isTrue);
    }

    final bool notified = await tray.showNotification(
      const TrayNotification(
        title: 'XueHua Tray Test',
        message: 'Integration notification body',
        iconType: TrayNotificationIconType.info,
      ),
    );
    // Linux uses notify-send; capability reflects whether the binary is on PATH.
    // Delivery still needs a desktop notification daemon, which is environment-dependent.
    if (capabilities.supportsTrayNotification) {
      expect(notified, isTrue);
    }

    // Window helpers should be callable without throwing.
    final bool visibleBefore = await tray.isMainWindowVisible();
    expect(visibleBefore, isA<bool>());
    await tray.hideMainWindow();
    await tray.showMainWindow(focus: true);
    await tray.setDockIconVisible(true); // no-op outside macOS

    await tray.destroy();
  });
}
