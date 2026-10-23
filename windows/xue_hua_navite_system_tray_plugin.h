#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN_H_

#include <windows.h>
#include <shellapi.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <string>
#include <vector>

namespace xue_hua_navite_system_tray {

/// Internal representation of a context menu entry on Windows.
struct WinMenuItemRecord {
  UINT command_id = 0;
  std::string id;
  std::string type;
  std::string label;
  std::string shortcut_label;
  std::string group_id;
  bool enabled = true;
  bool checked = false;
  HMENU parent_menu = nullptr;
  HBITMAP bitmap = nullptr;
};

/// Native Windows implementation of the `xue_hua_navite_system_tray` plugin.
///
/// Uses `Shell_NotifyIconW` (`NOTIFYICONDATAW`) for taskbar notification area
/// integration, GDI+ (`Gdiplus::Bitmap`) for decoding PNG/ICO/BMP assets and raw
/// bytes into `HICON` / `HBITMAP`, and Win32 `HMENU` popup menus.
class XueHuaNaviteSystemTrayPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  explicit XueHuaNaviteSystemTrayPlugin(
      flutter::PluginRegistrarWindows *registrar = nullptr,
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel =
          nullptr);

  virtual ~XueHuaNaviteSystemTrayPlugin();

  // Disallow copy and assign.
  XueHuaNaviteSystemTrayPlugin(const XueHuaNaviteSystemTrayPlugin &) = delete;
  XueHuaNaviteSystemTrayPlugin &operator=(
      const XueHuaNaviteSystemTrayPlugin &) = delete;

  /// Called when a method is invoked on the `xue_hua_navite_system_tray` channel.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  static constexpr UINT kTrayCallbackMessage = WM_APP + 0x241;
  static constexpr UINT kHideMainWindowMessage = WM_APP + 0x242;
  static constexpr UINT kShowMainWindowMessage = WM_APP + 0x243;
  static constexpr UINT kTrayIconId = 1001;

  static LRESULT CALLBACK MessageWindowProc(HWND hwnd, UINT message,
                                            WPARAM wparam, LPARAM lparam);

  LRESULT HandleWindowMessage(HWND hwnd, UINT message, WPARAM wparam,
                              LPARAM lparam);

  bool EnsureMessageWindow();
  HWND GetMainFlutterWindow() const;
  void HideMainFlutterWindow();
  void ShowMainFlutterWindow(bool focus);

  bool InitSystemTray(const flutter::EncodableMap &args);
  void SetIconFromMap(const flutter::EncodableMap &icon_map);
  void SetTitleText(const std::string &title);
  void SetToolTipText(const std::string &tooltip);
  void SetMenuTrigger(const flutter::EncodableMap &args);
  void SetVisible(bool visible);
  void RebuildContextMenu(const flutter::EncodableList &items);
  HMENU BuildSubMenu(const flutter::EncodableList &items);
  void UpdateMenuItem(const flutter::EncodableMap &args);
  void PopUpContextMenu();
  bool GetTrayBounds(RECT *out_rect) const;
  bool ShowNotification(const flutter::EncodableMap &args);
  void DestroyTray();
  void FreeMenuResources();

  HICON LoadHIconFromMap(const flutter::EncodableMap &icon_map, int target_size);
  HBITMAP LoadHBitmapFromMap(const flutter::EncodableMap &icon_map,
                             int target_size);
  std::wstring ResolveFlutterAssetPath(const std::string &asset_path) const;

  void EmitTrayClickEvent(const std::string &event_type,
                          const std::string &mouse_button);
  void HandleMenuCommand(UINT command_id);

  flutter::PluginRegistrarWindows *registrar_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  ULONG_PTR gdiplus_token_ = 0;
  HWND message_hwnd_ = nullptr;
  NOTIFYICONDATAW nid_{};
  bool tray_added_ = false;
  bool tray_visible_ = true;
  HICON current_hicon_ = nullptr;
  bool owns_current_hicon_ = false;

  std::string current_title_;
  std::string current_tooltip_;
  std::string menu_trigger_ = "rightClick";

  HMENU root_menu_ = nullptr;
  UINT next_command_id_ = 2000;
  std::map<UINT, WinMenuItemRecord> menu_by_cmd_;
  std::map<std::string, UINT> cmd_by_id_;
  std::vector<HBITMAP> allocated_bitmaps_;
};

}  // namespace xue_hua_navite_system_tray

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN_H_
