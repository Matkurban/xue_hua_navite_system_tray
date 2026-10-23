import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';

class MockXueHuaNaviteSystemTrayPlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteSystemTrayPlatform {
  final StreamController<TrayEvent> controller =
      StreamController<TrayEvent>.broadcast();

  TrayConfig? lastInitConfig;
  TrayIconSource? lastIcon;
  String? lastTitle;
  String? lastToolTip;
  TrayMenuTrigger? lastTrigger;
  TrayImagePosition? lastImagePosition;
  bool? lastVisible;
  List<TrayMenuItem>? lastMenuItems;
  Map<String, dynamic>? lastUpdatedItem;
  bool popUpCalled = false;
  TrayNotification? lastNotification;
  bool? lastDockVisible;
  bool mainWindowVisible = true;
  bool destroyCalled = false;

  @override
  Stream<TrayEvent> get events => controller.stream;

  @override
  Future<bool> initSystemTray(TrayConfig config) async {
    lastInitConfig = config;
    return true;
  }

  @override
  Future<void> setIcon(TrayIconSource icon) async {
    lastIcon = icon;
  }

  @override
  Future<void> setTitle(String? title) async {
    lastTitle = title;
  }

  @override
  Future<void> setToolTip(String? toolTip) async {
    lastToolTip = toolTip;
  }

  @override
  Future<void> setMenuTrigger(
    TrayMenuTrigger trigger, {
    TrayImagePosition? imagePosition,
  }) async {
    lastTrigger = trigger;
    lastImagePosition = imagePosition;
  }

  @override
  Future<void> setVisible(bool visible) async {
    lastVisible = visible;
  }

  @override
  Future<void> setContextMenu(List<TrayMenuItem> items) async {
    lastMenuItems = items;
  }

  @override
  Future<void> updateMenuItem(
    String id, {
    String? label,
    String? toolTip,
    bool? enabled,
    bool? checked,
    TrayIconSource? icon,
  }) async {
    lastUpdatedItem = <String, dynamic>{
      'id': id,
      'label': label,
      'toolTip': toolTip,
      'enabled': enabled,
      'checked': checked,
      'icon': icon,
    };
  }

  @override
  Future<void> popUpContextMenu() async {
    popUpCalled = true;
  }

  @override
  Future<TrayBounds?> getBounds() async {
    return const TrayBounds(x: 1200, y: 4, width: 28, height: 22);
  }

  @override
  Future<bool> showNotification(TrayNotification notification) async {
    lastNotification = notification;
    return true;
  }

  @override
  Future<void> setDockIconVisible(bool visible) async {
    lastDockVisible = visible;
  }

  @override
  Future<void> showMainWindow({bool focus = true}) async {
    mainWindowVisible = true;
  }

  @override
  Future<void> hideMainWindow() async {
    mainWindowVisible = false;
  }

  @override
  Future<bool> isMainWindowVisible() async {
    return mainWindowVisible;
  }

  @override
  Future<TrayCapabilities> getCapabilities() async {
    return const TrayCapabilities(
      platform: 'macos',
      backendName: 'NSStatusItem',
      supportsInlineTitle: true,
      supportsTemplateIcon: true,
      supportsSystemSymbol: true,
      supportsIconBounds: true,
      supportsLeftRightClickDistinction: true,
      supportsDoubleClick: true,
      supportsMiddleClick: true,
      supportsMenuIcons: true,
      supportsMenuShortcuts: true,
      supportsMenuTooltips: true,
      supportsProgrammaticMenuPopup: true,
      supportsDockVisibilityToggle: true,
      supportsTrayNotification: true,
    );
  }

  @override
  Future<void> destroy() async {
    destroyCalled = true;
  }
}

void main() {
  final XueHuaNaviteSystemTrayPlatform initialPlatform =
      XueHuaNaviteSystemTrayPlatform.instance;

  test('$MethodChannelXueHuaNaviteSystemTray is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelXueHuaNaviteSystemTray>(),
    );
  });

  test('XueHuaNaviteSystemTray delegates all operations to platform', () async {
    final MockXueHuaNaviteSystemTrayPlatform fakePlatform =
        MockXueHuaNaviteSystemTrayPlatform();
    XueHuaNaviteSystemTrayPlatform.instance = fakePlatform;
    final XueHuaNaviteSystemTray tray = XueHuaNaviteSystemTray.instance;

    final bool initialized = await tray.initSystemTray(
      TrayConfig(
        icon: const TrayIconSource.system('sparkles', isTemplate: true),
        title: 'XueHua',
        toolTip: 'XueHua System Tray',
        menuTrigger: TrayMenuTrigger.rightClick,
        menuItems: <TrayMenuItem>[
          const TrayMenuItem.header(id: 'hdr', label: 'Controls'),
          TrayMenuItem.action(
            id: 'open',
            label: 'Open App',
            shortcut: const TrayMenuShortcut('o', meta: true),
          ),
          const TrayMenuItem.separator(),
        ],
      ),
    );
    expect(initialized, isTrue);
    expect(fakePlatform.lastInitConfig?.title, 'XueHua');
    expect(fakePlatform.lastInitConfig?.menuItems.length, 3);

    final Uint8List rawBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    await tray.setIcon(TrayIconSource.bytes(rawBytes, iconSize: 18));
    expect(fakePlatform.lastIcon?.type, TrayIconSourceType.bytes);

    await tray.setTitle('98%');
    expect(fakePlatform.lastTitle, '98%');

    await tray.setToolTip('CPU Load: 98%');
    expect(fakePlatform.lastToolTip, 'CPU Load: 98%');

    await tray.setMenuTrigger(
      TrayMenuTrigger.anyClick,
      imagePosition: TrayImagePosition.trailing,
    );
    expect(fakePlatform.lastTrigger, TrayMenuTrigger.anyClick);
    expect(fakePlatform.lastImagePosition, TrayImagePosition.trailing);

    await tray.setVisible(false);
    expect(fakePlatform.lastVisible, isFalse);

    await tray.updateMenuItem('open', label: 'Restore Window', enabled: false);
    expect(fakePlatform.lastUpdatedItem?['id'], 'open');
    expect(fakePlatform.lastUpdatedItem?['label'], 'Restore Window');

    await tray.popUpContextMenu();
    expect(fakePlatform.popUpCalled, isTrue);

    final TrayBounds? bounds = await tray.getBounds();
    expect(bounds?.centerX, 1214.0);
    expect(bounds?.centerY, 15.0);

    final bool notified = await tray.showNotification(
      const TrayNotification(
        title: 'Sync Complete',
        message: 'All files have been synchronized.',
        iconType: TrayNotificationIconType.info,
      ),
    );
    expect(notified, isTrue);
    expect(fakePlatform.lastNotification?.title, 'Sync Complete');

    await tray.setDockIconVisible(false);
    expect(fakePlatform.lastDockVisible, isFalse);

    await tray.hideMainWindow();
    expect(await tray.isMainWindowVisible(), isFalse);
    await tray.showMainWindow();
    expect(await tray.isMainWindowVisible(), isTrue);

    final TrayCapabilities caps = await tray.getCapabilities();
    expect(caps.platform, 'macos');
    expect(caps.supportsInlineTitle, isTrue);

    await tray.destroy();
    expect(fakePlatform.destroyCalled, isTrue);
  });
}
