
import 'xue_hua_navite_system_tray_platform_interface.dart';

class XueHuaNaviteSystemTray {
  Future<String?> getPlatformVersion() {
    return XueHuaNaviteSystemTrayPlatform.instance.getPlatformVersion();
  }
}
