import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
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

  testWidgets('hideMainWindow toggles visibility without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('hide-window-safe'))),
      ),
    );
    await tester.pumpAndSettle();

    final XueHuaNaviteSystemTray tray = XueHuaNaviteSystemTray.instance;
    final Completer<void> hideFromMenu = Completer<void>();

    final bool initialized = await tray.initSystemTray(
      TrayConfig(
        icon: platformSystemIcon(),
        title: 'Hide Safe',
        toolTip: 'Hide Safe',
        menuItems: <TrayMenuItem>[
          TrayMenuItem.action(
            id: 'hide_window',
            label: 'Minimize to System Tray',
            onTap: () async {
              await tray.hideMainWindow();
              if (!hideFromMenu.isCompleted) {
                hideFromMenu.complete();
              }
            },
          ),
        ],
      ),
    );
    expect(initialized, isTrue);
    expect(await tray.isMainWindowVisible(), isTrue);

    // Direct API path.
    await tray.hideMainWindow();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await tray.isMainWindowVisible(), isFalse);
    expect(find.text('hide-window-safe'), findsOneWidget);

    await tray.showMainWindow(focus: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await tray.isMainWindowVisible(), isTrue);

    // Menu onTap path (inbound onTrayEvent -> deferred callback -> hide).
    const MethodChannel channel = MethodChannel('xue_hua_navite_system_tray');
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onTrayEvent', <String, dynamic>{
          'type': 'menuItemClick',
          'mouseButton': 'left',
          'menuItemId': 'hide_window',
          'timestamp': 0,
        }),
      ),
      (_) {},
    );
    await hideFromMenu.future.timeout(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await tray.isMainWindowVisible(), isFalse);

    await tray.showMainWindow(focus: true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(await tray.isMainWindowVisible(), isTrue);

    await tray.destroy();
  }, skip: !(Platform.isWindows || Platform.isLinux || Platform.isMacOS));
}