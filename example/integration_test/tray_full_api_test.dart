import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

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

  Future<Uint8List> makePngBadge() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(0, 0, 24, 24),
        const ui.Radius.circular(6),
      ),
      ui.Paint()..color = const ui.Color(0xFF2563EB),
    );
    final ui.Image img = await recorder.endRecording().toImage(24, 24);
    final ByteData? bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  Future<void> simulateMenuClick(String menuItemId, {bool? checked}) async {
    const MethodChannel channel = MethodChannel('xue_hua_navite_system_tray');
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onTrayEvent', <String, dynamic>{
          'type': 'menuItemClick',
          'mouseButton': 'left',
          'menuItemId': menuItemId,
          'timestamp': 0,
          'checked': ?checked,
        }),
      ),
      (_) {},
    );
  }

  testWidgets('full tray API: icons, menu, visibility, callbacks, destroy', (
    WidgetTester tester,
  ) async {
    final XueHuaNaviteSystemTray tray = XueHuaNaviteSystemTray.instance;
    final Completer<void> actionTapped = Completer<void>();
    final Completer<bool> checkboxChanged = Completer<bool>();
    final Completer<void> radioTapped = Completer<void>();
    final List<TrayEvent> events = <TrayEvent>[];
    final StreamSubscription<TrayEvent> sub = tray.events.listen(events.add);

    final TrayCapabilities caps = await tray.getCapabilities();
    expect(caps.platform.isNotEmpty, isTrue);
    expect(caps.backendName.isNotEmpty, isTrue);
    if (Platform.isWindows) {
      expect(caps.platform.toLowerCase(), contains('windows'));
      expect(caps.backendName.toLowerCase(), contains('shell_notifyicon'));
    } else if (Platform.isLinux) {
      expect(caps.platform.toLowerCase(), contains('linux'));
    } else if (Platform.isMacOS) {
      expect(caps.platform.toLowerCase(), contains('macos'));
    }

    final bool initialized = await tray.initSystemTray(
      TrayConfig(
        icon: platformSystemIcon(),
        title: 'FullAPI',
        toolTip: 'Full API Tray',
        menuTrigger: TrayMenuTrigger.rightClick,
        menuItems: <TrayMenuItem>[
          const TrayMenuItem.header(id: 'hdr', label: 'Header'),
          TrayMenuItem.action(
            id: 'do_action',
            label: 'Do Action',
            icon: const TrayIconSource.asset(
              'assets/icons/menu_star.png',
              iconSize: 16,
            ),
            onTap: () {
              if (!actionTapped.isCompleted) {
                actionTapped.complete();
              }
            },
          ),
          TrayMenuItem.checkbox(
            id: 'cb',
            label: 'Toggle Me',
            checked: false,
            onChanged: (bool v) {
              if (!checkboxChanged.isCompleted) {
                checkboxChanged.complete(v);
              }
            },
          ),
          TrayMenuItem.submenu(
            id: 'sub',
            label: 'Modes',
            children: <TrayMenuItem>[
              TrayMenuItem.radio(
                id: 'mode_a',
                groupId: 'g',
                label: 'Mode A',
                checked: true,
                onTap: () {},
              ),
              TrayMenuItem.radio(
                id: 'mode_b',
                groupId: 'g',
                label: 'Mode B',
                checked: false,
                onTap: () {
                  if (!radioTapped.isCompleted) {
                    radioTapped.complete();
                  }
                },
              ),
            ],
          ),
          const TrayMenuItem.separator(),
          TrayMenuItem.action(
            id: 'hide_window',
            label: 'Hide',
            onTap: () async {
              await tray.hideMainWindow();
            },
          ),
          TrayMenuItem.action(
            id: 'show_window',
            label: 'Show',
            onTap: () async {
              await tray.showMainWindow(focus: true);
            },
          ),
        ],
      ),
    );
    expect(initialized, isTrue);

    // Icon sources: system -> asset -> bytes -> system
    await tray.setIcon(platformSystemIcon());
    await tray.setIcon(
      const TrayIconSource.asset('assets/icons/tray_logo.png', iconSize: 18),
    );
    final Uint8List badge = await makePngBadge();
    await tray.setIcon(TrayIconSource.bytes(badge, iconSize: 18));
    await tray.setIcon(const TrayIconSource.system('dialog-warning'));

    await tray.setTitle('XH-Full');
    await tray.setToolTip('Tooltip updated');
    await tray.setMenuTrigger(TrayMenuTrigger.anyClick);
    await tray.setVisible(false);
    await tray.setVisible(true);

    await tray.updateMenuItem('do_action', label: 'Do Action (upd)', enabled: true);
    await tray.setContextMenu(<TrayMenuItem>[
      TrayMenuItem.action(
        id: 'do_action',
        label: 'Do Action',
        onTap: () {
          if (!actionTapped.isCompleted) {
            actionTapped.complete();
          }
        },
      ),
      TrayMenuItem.checkbox(
        id: 'cb',
        label: 'Toggle Me',
        checked: false,
        onChanged: (bool v) {
          if (!checkboxChanged.isCompleted) {
            checkboxChanged.complete(v);
          }
        },
      ),
      TrayMenuItem.radio(
        id: 'mode_b',
        groupId: 'g',
        label: 'Mode B',
        checked: false,
        onTap: () {
          if (!radioTapped.isCompleted) {
            radioTapped.complete();
          }
        },
      ),
      TrayMenuItem.action(
        id: 'hide_window',
        label: 'Hide',
        onTap: () async {
          await tray.hideMainWindow();
        },
      ),
      TrayMenuItem.action(
        id: 'show_window',
        label: 'Show',
        onTap: () async {
          await tray.showMainWindow(focus: true);
        },
      ),
    ]);

    // Simulated inbound menu callbacks (covers Dart deferred-dispatch path).
    await simulateMenuClick('do_action');
    await actionTapped.future.timeout(const Duration(seconds: 5));

    await simulateMenuClick('cb', checked: true);
    expect(
      await checkboxChanged.future.timeout(const Duration(seconds: 5)),
      isTrue,
    );

    await simulateMenuClick('mode_b', checked: true);
    await radioTapped.future.timeout(const Duration(seconds: 5));

    expect(await tray.isMainWindowVisible(), isTrue);
    await simulateMenuClick('hide_window');
    await tester.pump(const Duration(milliseconds: 400));
    // Native hide is async on macOS; wait for visibility to settle.
    final DateTime hideDeadline = DateTime.now().add(const Duration(seconds: 5));
    while (await tray.isMainWindowVisible()) {
      if (DateTime.now().isAfter(hideDeadline)) {
        fail('hideMainWindow did not hide within timeout');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await tray.isMainWindowVisible(), isFalse);
    await simulateMenuClick('show_window');
    await tester.pump(const Duration(milliseconds: 400));
    final DateTime showDeadline = DateTime.now().add(const Duration(seconds: 5));
    while (!(await tray.isMainWindowVisible())) {
      if (DateTime.now().isAfter(showDeadline)) {
        fail('showMainWindow did not show within timeout');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await tray.isMainWindowVisible(), isTrue);

    // Programmatic popup after window cycle. autoDismissMs prevents macOS
    // NSMenu tracking from wedging the platform main queue.
    await const MethodChannel('xue_hua_navite_system_tray')
        .invokeMethod<void>('popUpContextMenu', <String, Object?>{
      'autoDismissMs': 400,
    });
    await tester.pump(const Duration(milliseconds: 500));
    try {
      await const MethodChannel('xue_hua_navite_system_tray')
          .invokeMethod<void>('dismissContextMenu');
    } on MissingPluginException {
      // Older native builds may omit dismiss.
    }

    final bool notified = await tray.showNotification(
      const TrayNotification(
        title: 'Full API',
        message: 'notification probe',
        iconType: TrayNotificationIconType.info,
      ),
    );
    if (caps.supportsTrayNotification) {
      expect(notified, isTrue);
    }

    // Bounds optional on AppIndicator.
    final TrayBounds? bounds = await tray.getBounds();
    if (caps.supportsIconBounds) {
      expect(bounds, isNotNull);
    }

    await tray.destroy();

    // Re-init after destroy must succeed.
    final bool again = await tray.initSystemTray(
      TrayConfig(
        icon: platformSystemIcon(),
        title: 'Reinit',
        toolTip: 'Reinit',
        menuItems: <TrayMenuItem>[
          TrayMenuItem.action(id: 'ok', label: 'OK', onTap: () {}),
        ],
      ),
    );
    expect(again, isTrue);
    await tray.destroy();

    expect(
      events.any((TrayEvent e) => e.type == TrayEventType.menuItemClick),
      isTrue,
    );
    await sub.cancel();
  }, skip: !Platform.isLinux && !Platform.isWindows && !Platform.isMacOS);
}
