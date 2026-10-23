import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelXueHuaNaviteSystemTray platform =
      MethodChannelXueHuaNaviteSystemTray();
  const MethodChannel channel = MethodChannel('xue_hua_navite_system_tray');

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          switch (methodCall.method) {
            case 'initSystemTray':
              return true;
            case 'getBounds':
              return <String, double>{
                'x': 800.0,
                'y': 0.0,
                'width': 24.0,
                'height': 24.0,
              };
            case 'showNotification':
              return true;
            case 'isMainWindowVisible':
              return true;
            case 'getCapabilities':
              return <String, dynamic>{
                'platform': 'macos',
                'backendName': 'NSStatusItem',
                'supportsInlineTitle': true,
                'supportsTemplateIcon': true,
                'supportsSystemSymbol': true,
                'supportsIconBounds': true,
                'supportsLeftRightClickDistinction': true,
                'supportsDoubleClick': true,
                'supportsMiddleClick': true,
                'supportsMenuIcons': true,
                'supportsMenuShortcuts': true,
                'supportsMenuTooltips': true,
                'supportsProgrammaticMenuPopup': true,
                'supportsDockVisibilityToggle': true,
                'supportsTrayNotification': true,
              };
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initSystemTray serializes config and dispatches menu callbacks', () async {
    bool actionTapped = false;
    bool? checkboxValue;

    final bool ok = await platform.initSystemTray(
      TrayConfig(
        icon: const TrayIconSource.asset('assets/tray.png', isTemplate: true),
        title: 'Status',
        toolTip: 'Hover tip',
        menuItems: <TrayMenuItem>[
          TrayMenuItem.action(
            id: 'sync_now',
            label: 'Sync Now',
            onTap: () {
              actionTapped = true;
            },
          ),
          TrayMenuItem.checkbox(
            id: 'auto_launch',
            label: 'Launch at Login',
            checked: false,
            onChanged: (bool val) {
              checkboxValue = val;
            },
          ),
        ],
      ),
    );

    expect(ok, isTrue);
    expect(log.single.method, 'initSystemTray');

    // Simulate native menuItemClick callbacks from the host platform.
    final ByteData? actionMessage = const StandardMethodCodec()
        .encodeMethodCall(
          const MethodCall('onTrayEvent', <String, dynamic>{
            'type': 'menuItemClick',
            'mouseButton': 'left',
            'menuItemId': 'sync_now',
          }),
        );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'xue_hua_navite_system_tray',
          actionMessage,
          (_) {},
        );
    expect(actionTapped, isTrue);

    final ByteData? checkMessage = const StandardMethodCodec().encodeMethodCall(
      const MethodCall('onTrayEvent', <String, dynamic>{
        'type': 'menuItemClick',
        'mouseButton': 'left',
        'menuItemId': 'auto_launch',
        'checked': true,
      }),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'xue_hua_navite_system_tray',
          checkMessage,
          (_) {},
        );
    expect(checkboxValue, isTrue);
  });

  test('getBounds and getCapabilities parse native maps accurately', () async {
    final TrayBounds? bounds = await platform.getBounds();
    expect(bounds, isNotNull);
    expect(bounds!.width, 24.0);

    final TrayCapabilities caps = await platform.getCapabilities();
    expect(caps.backendName, 'NSStatusItem');
    expect(caps.supportsDockVisibilityToggle, isTrue);
  });
}
