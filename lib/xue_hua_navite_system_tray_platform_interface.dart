import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'xue_hua_navite_system_tray_method_channel.dart';

abstract class XueHuaNaviteSystemTrayPlatform extends PlatformInterface {
  /// Constructs a XueHuaNaviteSystemTrayPlatform.
  XueHuaNaviteSystemTrayPlatform() : super(token: _token);

  static final Object _token = Object();

  static XueHuaNaviteSystemTrayPlatform _instance = MethodChannelXueHuaNaviteSystemTray();

  /// The default instance of [XueHuaNaviteSystemTrayPlatform] to use.
  ///
  /// Defaults to [MethodChannelXueHuaNaviteSystemTray].
  static XueHuaNaviteSystemTrayPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XueHuaNaviteSystemTrayPlatform] when
  /// they register themselves.
  static set instance(XueHuaNaviteSystemTrayPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
