import 'dart:io';

import 'package:flutter/services.dart';
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

  testWidgets(
    'gap coverage: file icon, imagePosition, dock toggle, popUpContextMenu',
    (WidgetTester tester) async {
      final XueHuaNaviteSystemTray tray = XueHuaNaviteSystemTray.instance;
      final TrayCapabilities caps = await tray.getCapabilities();

      final bool initialized = await tray.initSystemTray(
        TrayConfig(
          icon: platformSystemIcon(),
          title: 'Gap',
          toolTip: 'Gap coverage',
          menuTrigger: TrayMenuTrigger.rightClick,
          imagePosition: TrayImagePosition.leading,
          menuItems: <TrayMenuItem>[
            TrayMenuItem.action(id: 'ok', label: 'OK', onTap: () {}),
          ],
        ),
      );
      expect(initialized, isTrue);

      final ByteData asset = await rootBundle.load('assets/icons/tray_logo.png');
      final String filePath =
          '${Directory.systemTemp.path}/xh_tray_gap_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(filePath).writeAsBytes(asset.buffer.asUint8List());
      addTearDown(() {
        final File f = File(filePath);
        if (f.existsSync()) {
          f.deleteSync();
        }
      });
      await tray.setIcon(
        TrayIconSource.file(
          filePath,
          isTemplate: Platform.isMacOS,
          iconSize: 18,
        ),
      );

      await tray.setMenuTrigger(
        TrayMenuTrigger.anyClick,
        imagePosition: TrayImagePosition.trailing,
      );
      await tray.setMenuTrigger(
        TrayMenuTrigger.rightClick,
        imagePosition: TrayImagePosition.leading,
      );

      if (caps.supportsDockVisibilityToggle) {
        await tray.setDockIconVisible(false);
        await tester.pump(const Duration(milliseconds: 200));
        await tray.setDockIconVisible(true);
        await tester.pump(const Duration(milliseconds: 200));
      } else {
        await tray.setDockIconVisible(false);
        await tray.setDockIconVisible(true);
      }

      if (caps.supportsProgrammaticMenuPopup) {
        try {
          await const MethodChannel('xue_hua_navite_system_tray')
              .invokeMethod<void>('popUpContextMenu', <String, Object?>{
            'autoDismissMs': 400,
          });
        } on MissingPluginException {
          await tray.popUpContextMenu();
        }
        await tester.pump(const Duration(milliseconds: 500));
        try {
          await const MethodChannel('xue_hua_navite_system_tray')
              .invokeMethod<void>('dismissContextMenu');
        } on MissingPluginException {
          // Older native builds may omit dismiss.
        }
      }

      await tray.destroy();
    },
    skip: !Platform.isLinux && !Platform.isWindows && !Platform.isMacOS,
  );
}
