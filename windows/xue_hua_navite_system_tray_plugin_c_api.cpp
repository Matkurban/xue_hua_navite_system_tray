#include "include/xue_hua_navite_system_tray/xue_hua_navite_system_tray_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "xue_hua_navite_system_tray_plugin.h"

void XueHuaNaviteSystemTrayPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  xue_hua_navite_system_tray::XueHuaNaviteSystemTrayPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
