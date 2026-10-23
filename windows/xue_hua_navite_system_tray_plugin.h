#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace xue_hua_navite_system_tray {

class XueHuaNaviteSystemTrayPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  XueHuaNaviteSystemTrayPlugin();

  virtual ~XueHuaNaviteSystemTrayPlugin();

  // Disallow copy and assign.
  XueHuaNaviteSystemTrayPlugin(const XueHuaNaviteSystemTrayPlugin&) = delete;
  XueHuaNaviteSystemTrayPlugin& operator=(const XueHuaNaviteSystemTrayPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace xue_hua_navite_system_tray

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN_H_
