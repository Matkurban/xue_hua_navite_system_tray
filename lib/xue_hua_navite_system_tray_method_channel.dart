import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'xue_hua_navite_system_tray_platform_interface.dart';

/// An implementation of [XueHuaNaviteSystemTrayPlatform] that uses method channels.
class MethodChannelXueHuaNaviteSystemTray extends XueHuaNaviteSystemTrayPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('xue_hua_navite_system_tray');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
