import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray_platform_interface.dart';
import 'package:xue_hua_navite_system_tray/xue_hua_navite_system_tray_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockXueHuaNaviteSystemTrayPlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteSystemTrayPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final XueHuaNaviteSystemTrayPlatform initialPlatform = XueHuaNaviteSystemTrayPlatform.instance;

  test('$MethodChannelXueHuaNaviteSystemTray is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelXueHuaNaviteSystemTray>());
  });

  test('getPlatformVersion', () async {
    XueHuaNaviteSystemTray xueHuaNaviteSystemTrayPlugin = XueHuaNaviteSystemTray();
    MockXueHuaNaviteSystemTrayPlatform fakePlatform = MockXueHuaNaviteSystemTrayPlatform();
    XueHuaNaviteSystemTrayPlatform.instance = fakePlatform;

    expect(await xueHuaNaviteSystemTrayPlugin.getPlatformVersion(), '42');
  });
}
