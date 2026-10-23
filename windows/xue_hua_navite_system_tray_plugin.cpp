#include "xue_hua_navite_system_tray_plugin.h"

#include <windows.h>
#include <gdiplus.h>
#include <shlwapi.h>
#include <shellapi.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <chrono>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

namespace xue_hua_navite_system_tray {

namespace {

constexpr wchar_t kMessageWindowClassName[] =
    L"XueHuaNaviteSystemTrayMessageWindow";

std::wstring Utf8ToWide(const std::string &utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  int count = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                  static_cast<int>(utf8.size()), nullptr, 0);
  if (count <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(count), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      wide.data(), count);
  return wide;
}

const flutter::EncodableValue *FindMapValue(const flutter::EncodableMap &map,
                                            const char *key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end() || it->second.IsNull()) {
    return nullptr;
  }
  return &it->second;
}

std::string GetStringOrDefault(const flutter::EncodableMap &map,
                               const char *key,
                               const std::string &default_val = "") {
  const auto *val = FindMapValue(map, key);
  if (val && std::holds_alternative<std::string>(*val)) {
    return std::get<std::string>(*val);
  }
  return default_val;
}

bool GetBoolOrDefault(const flutter::EncodableMap &map, const char *key,
                      bool default_val = false) {
  const auto *val = FindMapValue(map, key);
  if (val && std::holds_alternative<bool>(*val)) {
    return std::get<bool>(*val);
  }
  return default_val;
}

double GetDoubleOrDefault(const flutter::EncodableMap &map, const char *key,
                          double default_val = 0.0) {
  const auto *val = FindMapValue(map, key);
  if (!val) {
    return default_val;
  }
  if (std::holds_alternative<double>(*val)) {
    return std::get<double>(*val);
  }
  if (std::holds_alternative<int32_t>(*val)) {
    return static_cast<double>(std::get<int32_t>(*val));
  }
  if (std::holds_alternative<int64_t>(*val)) {
    return static_cast<double>(std::get<int64_t>(*val));
  }
  return default_val;
}

int64_t CurrentTimestampMs() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(system_clock::now().time_since_epoch())
      .count();
}

}  // namespace

// static
void XueHuaNaviteSystemTrayPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "xue_hua_navite_system_tray",
          &flutter::StandardMethodCodec::GetInstance());

  auto *channel_raw = channel.get();
  auto plugin = std::make_unique<XueHuaNaviteSystemTrayPlugin>(
      registrar, std::move(channel));

  channel_raw->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

XueHuaNaviteSystemTrayPlugin::XueHuaNaviteSystemTrayPlugin(
    flutter::PluginRegistrarWindows *registrar,
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
    : registrar_(registrar), channel_(std::move(channel)) {
  Gdiplus::GdiplusStartupInput gdiplus_startup_input;
  Gdiplus::GdiplusStartup(&gdiplus_token_, &gdiplus_startup_input, nullptr);
}

XueHuaNaviteSystemTrayPlugin::~XueHuaNaviteSystemTrayPlugin() {
  DestroyTray();
  if (message_hwnd_ != nullptr) {
    DestroyWindow(message_hwnd_);
    message_hwnd_ = nullptr;
  }
  if (gdiplus_token_ != 0) {
    Gdiplus::GdiplusShutdown(gdiplus_token_);
    gdiplus_token_ = 0;
  }
}

bool XueHuaNaviteSystemTrayPlugin::EnsureMessageWindow() {
  if (message_hwnd_ != nullptr) {
    return true;
  }

  WNDCLASSEXW wc{};
  wc.cbSize = sizeof(WNDCLASSEXW);
  wc.lpfnWndProc = MessageWindowProc;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = kMessageWindowClassName;
  RegisterClassExW(&wc);

  message_hwnd_ = CreateWindowExW(0, kMessageWindowClassName,
                                  L"XueHuaSystemTrayHiddenWindow", WS_POPUP, 0,
                                  0, 0, 0, nullptr, nullptr, wc.hInstance, this);
  return message_hwnd_ != nullptr;
}

// static
LRESULT CALLBACK XueHuaNaviteSystemTrayPlugin::MessageWindowProc(
    HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) {
    auto *create_struct = reinterpret_cast<CREATESTRUCTW *>(lparam);
    auto *self = static_cast<XueHuaNaviteSystemTrayPlugin *>(
        create_struct->lpCreateParams);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    return DefWindowProcW(hwnd, message, wparam, lparam);
  }

  auto *self = reinterpret_cast<XueHuaNaviteSystemTrayPlugin *>(
      GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (self != nullptr) {
    return self->HandleWindowMessage(hwnd, message, wparam, lparam);
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

LRESULT XueHuaNaviteSystemTrayPlugin::HandleWindowMessage(HWND hwnd,
                                                          UINT message,
                                                          WPARAM wparam,
                                                          LPARAM lparam) {
  if (message == kTrayCallbackMessage) {
    UINT event_msg = LOWORD(lparam);
    switch (event_msg) {
      case WM_LBUTTONUP:
        EmitTrayClickEvent("leftClick", "left");
        if (menu_trigger_ == "leftClick" || menu_trigger_ == "anyClick") {
          PopUpContextMenu();
        }
        return 0;
      case WM_LBUTTONDBLCLK:
        EmitTrayClickEvent("leftDoubleClick", "left");
        return 0;
      case WM_RBUTTONUP:
      case WM_CONTEXTMENU:
        EmitTrayClickEvent("rightClick", "right");
        if (menu_trigger_ == "rightClick" || menu_trigger_ == "anyClick") {
          PopUpContextMenu();
        }
        return 0;
      case WM_RBUTTONDBLCLK:
        EmitTrayClickEvent("rightDoubleClick", "right");
        return 0;
      case WM_MBUTTONUP:
        EmitTrayClickEvent("middleClick", "middle");
        return 0;
      case NIN_BALLOONUSERCLICK:
        EmitTrayClickEvent("notificationClick", "none");
        return 0;
      default:
        break;
    }
  } else if (message == WM_COMMAND) {
    UINT cmd_id = LOWORD(wparam);
    HandleMenuCommand(cmd_id);
    return 0;
  }

  return DefWindowProcW(hwnd, message, wparam, lparam);
}

HWND XueHuaNaviteSystemTrayPlugin::GetMainFlutterWindow() const {
  if (registrar_ != nullptr && registrar_->GetView() != nullptr) {
    HWND view_hwnd = registrar_->GetView()->GetNativeWindow();
    if (view_hwnd != nullptr) {
      HWND root = GetAncestor(view_hwnd, GA_ROOT);
      return root != nullptr ? root : view_hwnd;
    }
  }
  return nullptr;
}

void XueHuaNaviteSystemTrayPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string &method = method_call.method_name();
  flutter::EncodableMap args;
  if (method_call.arguments() &&
      std::holds_alternative<flutter::EncodableMap>(*method_call.arguments())) {
    args = std::get<flutter::EncodableMap>(*method_call.arguments());
  }

  if (method == "initSystemTray") {
    bool ok = InitSystemTray(args);
    result->Success(flutter::EncodableValue(ok));
  } else if (method == "setIcon") {
    SetIconFromMap(args);
    result->Success();
  } else if (method == "setTitle") {
    SetTitleText(GetStringOrDefault(args, "title"));
    result->Success();
  } else if (method == "setToolTip") {
    SetToolTipText(GetStringOrDefault(args, "toolTip"));
    result->Success();
  } else if (method == "setMenuTrigger") {
    SetMenuTrigger(args);
    result->Success();
  } else if (method == "setVisible") {
    SetVisible(GetBoolOrDefault(args, "visible", true));
    result->Success();
  } else if (method == "setContextMenu") {
    const auto *items_val = FindMapValue(args, "menuItems");
    if (items_val &&
        std::holds_alternative<flutter::EncodableList>(*items_val)) {
      RebuildContextMenu(std::get<flutter::EncodableList>(*items_val));
    }
    result->Success();
  } else if (method == "updateMenuItem") {
    UpdateMenuItem(args);
    result->Success();
  } else if (method == "popUpContextMenu") {
    PopUpContextMenu();
    result->Success();
  } else if (method == "getBounds") {
    RECT rc{};
    if (GetTrayBounds(&rc)) {
      flutter::EncodableMap bounds_map{
          {flutter::EncodableValue("x"),
           flutter::EncodableValue(static_cast<double>(rc.left))},
          {flutter::EncodableValue("y"),
           flutter::EncodableValue(static_cast<double>(rc.top))},
          {flutter::EncodableValue("width"),
           flutter::EncodableValue(static_cast<double>(rc.right - rc.left))},
          {flutter::EncodableValue("height"),
           flutter::EncodableValue(static_cast<double>(rc.bottom - rc.top))},
      };
      result->Success(flutter::EncodableValue(bounds_map));
    } else {
      result->Success();
    }
  } else if (method == "showNotification") {
    bool shown = ShowNotification(args);
    result->Success(flutter::EncodableValue(shown));
  } else if (method == "setDockIconVisible") {
    // No-op on Windows (macOS-specific Dock concept).
    result->Success();
  } else if (method == "showMainWindow") {
    bool focus = GetBoolOrDefault(args, "focus", true);
    HWND hwnd = GetMainFlutterWindow();
    if (hwnd != nullptr) {
      if (IsIconic(hwnd)) {
        ShowWindow(hwnd, SW_RESTORE);
      } else {
        ShowWindow(hwnd, SW_SHOW);
      }
      if (focus) {
        SetForegroundWindow(hwnd);
      }
    }
    result->Success();
  } else if (method == "hideMainWindow") {
    HWND hwnd = GetMainFlutterWindow();
    if (hwnd != nullptr) {
      ShowWindow(hwnd, SW_HIDE);
    }
    result->Success();
  } else if (method == "isMainWindowVisible") {
    HWND hwnd = GetMainFlutterWindow();
    bool visible =
        hwnd != nullptr && IsWindowVisible(hwnd) && !IsIconic(hwnd);
    result->Success(flutter::EncodableValue(visible));
  } else if (method == "getCapabilities") {
    flutter::EncodableMap caps{
        {flutter::EncodableValue("platform"),
         flutter::EncodableValue("windows")},
        {flutter::EncodableValue("backendName"),
         flutter::EncodableValue("Shell_NotifyIconW")},
        {flutter::EncodableValue("supportsInlineTitle"),
         flutter::EncodableValue(false)},
        {flutter::EncodableValue("supportsTemplateIcon"),
         flutter::EncodableValue(false)},
        {flutter::EncodableValue("supportsSystemSymbol"),
         flutter::EncodableValue(true)},
        {flutter::EncodableValue("supportsIconBounds"),
         flutter::EncodableValue(true)},
        {flutter::EncodableValue("supportsLeftRightClickDistinction"),
         flutter::EncodableValue(true)},
        {flutter::EncodableValue("supportsDoubleClick"),
         flutter::EncodableValue(true)},
        {flutter::EncodableValue("supportsMiddleClick"),
         flutter::EncodableValue(true)},
        {flutter::EncodableValue("supportsMenuIcons"),
         flutter::EncodableValue(true)},
        {flutter::EncodableValue("supportsMenuShortcuts"),
         flutter::EncodableValue(true)},
        {flutter::EncodableValue("supportsMenuTooltips"),
         flutter::EncodableValue(false)},
        {flutter::EncodableValue("supportsProgrammaticMenuPopup"),
         flutter::EncodableValue(true)},
        {flutter::EncodableValue("supportsDockVisibilityToggle"),
         flutter::EncodableValue(false)},
        {flutter::EncodableValue("supportsTrayNotification"),
         flutter::EncodableValue(true)},
    };
    result->Success(flutter::EncodableValue(caps));
  } else if (method == "destroy") {
    DestroyTray();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

bool XueHuaNaviteSystemTrayPlugin::InitSystemTray(
    const flutter::EncodableMap &args) {
  if (!EnsureMessageWindow()) {
    return false;
  }

  menu_trigger_ = GetStringOrDefault(args, "menuTrigger", "rightClick");
  current_title_ = GetStringOrDefault(args, "title");
  current_tooltip_ = GetStringOrDefault(args, "toolTip");
  tray_visible_ = GetBoolOrDefault(args, "visible", true);

  std::memset(&nid_, 0, sizeof(NOTIFYICONDATAW));
  nid_.cbSize = sizeof(NOTIFYICONDATAW);
  nid_.hWnd = message_hwnd_;
  nid_.uID = kTrayIconId;
  nid_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_STATE;
  nid_.uCallbackMessage = kTrayCallbackMessage;

  const auto *icon_val = FindMapValue(args, "icon");
  if (icon_val && std::holds_alternative<flutter::EncodableMap>(*icon_val)) {
    int target_size = GetSystemMetrics(SM_CXSMICON);
    HICON loaded = LoadHIconFromMap(
        std::get<flutter::EncodableMap>(*icon_val), target_size);
    if (loaded != nullptr) {
      if (owns_current_hicon_ && current_hicon_ != nullptr) {
        DestroyIcon(current_hicon_);
      }
      current_hicon_ = loaded;
      owns_current_hicon_ = true;
    }
  }
  if (current_hicon_ == nullptr) {
    current_hicon_ = LoadIconW(nullptr, IDI_APPLICATION);
    owns_current_hicon_ = false;
  }
  nid_.hIcon = current_hicon_;

  std::string effective_tip =
      !current_tooltip_.empty() ? current_tooltip_ : current_title_;
  std::wstring wide_tip = Utf8ToWide(effective_tip);
  wcsncpy_s(nid_.szTip, wide_tip.c_str(), _TRUNCATE);

  nid_.dwState = tray_visible_ ? 0 : NIS_HIDDEN;
  nid_.dwStateMask = NIS_HIDDEN;

  BOOL ok = Shell_NotifyIconW(tray_added_ ? NIM_MODIFY : NIM_ADD, &nid_);
  if (ok) {
    tray_added_ = true;
  }

  const auto *items_val = FindMapValue(args, "menuItems");
  if (items_val && std::holds_alternative<flutter::EncodableList>(*items_val)) {
    RebuildContextMenu(std::get<flutter::EncodableList>(*items_val));
  }

  return ok == TRUE;
}

void XueHuaNaviteSystemTrayPlugin::SetIconFromMap(
    const flutter::EncodableMap &icon_map) {
  if (!tray_added_) {
    return;
  }
  int target_size = GetSystemMetrics(SM_CXSMICON);
  HICON loaded = LoadHIconFromMap(icon_map, target_size);
  if (loaded != nullptr) {
    if (owns_current_hicon_ && current_hicon_ != nullptr) {
      DestroyIcon(current_hicon_);
    }
    current_hicon_ = loaded;
    owns_current_hicon_ = true;
    nid_.uFlags = NIF_ICON;
    nid_.hIcon = current_hicon_;
    Shell_NotifyIconW(NIM_MODIFY, &nid_);
  }
}

void XueHuaNaviteSystemTrayPlugin::SetTitleText(const std::string &title) {
  current_title_ = title;
  if (current_tooltip_.empty() && tray_added_) {
    std::wstring wide_tip = Utf8ToWide(current_title_);
    wcsncpy_s(nid_.szTip, wide_tip.c_str(), _TRUNCATE);
    nid_.uFlags = NIF_TIP;
    Shell_NotifyIconW(NIM_MODIFY, &nid_);
  }
}

void XueHuaNaviteSystemTrayPlugin::SetToolTipText(const std::string &tooltip) {
  current_tooltip_ = tooltip;
  if (tray_added_) {
    std::string effective_tip =
        !current_tooltip_.empty() ? current_tooltip_ : current_title_;
    std::wstring wide_tip = Utf8ToWide(effective_tip);
    wcsncpy_s(nid_.szTip, wide_tip.c_str(), _TRUNCATE);
    nid_.uFlags = NIF_TIP;
    Shell_NotifyIconW(NIM_MODIFY, &nid_);
  }
}

void XueHuaNaviteSystemTrayPlugin::SetMenuTrigger(
    const flutter::EncodableMap &args) {
  std::string trigger = GetStringOrDefault(args, "menuTrigger");
  if (!trigger.empty()) {
    menu_trigger_ = trigger;
  }
}

void XueHuaNaviteSystemTrayPlugin::SetVisible(bool visible) {
  tray_visible_ = visible;
  if (tray_added_) {
    nid_.uFlags = NIF_STATE;
    nid_.dwState = visible ? 0 : NIS_HIDDEN;
    nid_.dwStateMask = NIS_HIDDEN;
    Shell_NotifyIconW(NIM_MODIFY, &nid_);
  }
}

std::wstring XueHuaNaviteSystemTrayPlugin::ResolveFlutterAssetPath(
    const std::string &asset_path) const {
  wchar_t exe_path[MAX_PATH] = {0};
  GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  PathRemoveFileSpecW(exe_path);

  std::wstring rel = Utf8ToWide(asset_path);
  for (wchar_t &ch : rel) {
    if (ch == L'/') {
      ch = L'\\';
    }
  }

  std::wstring candidate =
      std::wstring(exe_path) + L"\\data\\flutter_assets\\" + rel;
  if (PathFileExistsW(candidate.c_str())) {
    return candidate;
  }
  return rel;
}

HICON XueHuaNaviteSystemTrayPlugin::LoadHIconFromMap(
    const flutter::EncodableMap &icon_map, int target_size) {
  std::string type = GetStringOrDefault(icon_map, "type", "asset");
  double custom_size = GetDoubleOrDefault(icon_map, "iconSize", 0.0);
  if (custom_size > 0.0) {
    target_size = static_cast<int>(custom_size);
  }

  if (type == "system") {
    std::string sys_name = GetStringOrDefault(icon_map, "systemName");
    LPCWSTR resource_id = IDI_APPLICATION;
    if (sys_name == "info" || sys_name == "information") {
      resource_id = IDI_INFORMATION;
    } else if (sys_name == "warning" || sys_name == "exclamation") {
      resource_id = IDI_WARNING;
    } else if (sys_name == "error" || sys_name == "hand") {
      resource_id = IDI_ERROR;
    } else if (sys_name == "question") {
      resource_id = IDI_QUESTION;
    } else if (sys_name == "shield") {
      resource_id = IDI_SHIELD;
    }
    HICON sized = static_cast<HICON>(LoadImageW(
        nullptr, resource_id, IMAGE_ICON, target_size, target_size, 0));
    if (sized != nullptr) {
      return sized;
    }
    return CopyIcon(LoadIconW(nullptr, resource_id));
  }

  if (type == "bytes") {
    const auto *bytes_val = FindMapValue(icon_map, "bytes");
    if (bytes_val &&
        std::holds_alternative<std::vector<uint8_t>>(*bytes_val)) {
      const auto &bytes = std::get<std::vector<uint8_t>>(*bytes_val);
      if (!bytes.empty()) {
        IStream *stream = SHCreateMemStream(
            bytes.data(), static_cast<UINT>(bytes.size()));
        if (stream != nullptr) {
          std::unique_ptr<Gdiplus::Bitmap> bmp(
              Gdiplus::Bitmap::FromStream(stream));
          stream->Release();
          if (bmp && bmp->GetLastStatus() == Gdiplus::Ok) {
            if (target_size > 0 &&
                (static_cast<int>(bmp->GetWidth()) != target_size ||
                 static_cast<int>(bmp->GetHeight()) != target_size)) {
              std::unique_ptr<Gdiplus::Bitmap> scaled(
                  new Gdiplus::Bitmap(target_size, target_size,
                                      PixelFormat32bppPARGB));
              if (scaled && scaled->GetLastStatus() == Gdiplus::Ok) {
                Gdiplus::Graphics graphics(scaled.get());
                graphics.SetInterpolationMode(
                    Gdiplus::InterpolationModeHighQualityBicubic);
                graphics.SetSmoothingMode(Gdiplus::SmoothingModeHighQuality);
                graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);
                graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
                graphics.DrawImage(bmp.get(), 0, 0, target_size, target_size);
                HICON hicon = nullptr;
                scaled->GetHICON(&hicon);
                return hicon;
              }
            }
            HICON hicon = nullptr;
            bmp->GetHICON(&hicon);
            return hicon;
          }
        }
      }
    }
    return nullptr;
  }

  std::string raw_path = GetStringOrDefault(icon_map, "path");
  std::wstring file_path =
      (type == "asset") ? ResolveFlutterAssetPath(raw_path)
                        : Utf8ToWide(raw_path);
  if (file_path.empty()) {
    return nullptr;
  }

  // Try loading directly as .ico first, then via GDI+ for PNG/BMP/JPEG.
  HICON direct_ico = static_cast<HICON>(LoadImageW(
      nullptr, file_path.c_str(), IMAGE_ICON, target_size, target_size,
      LR_LOADFROMFILE | LR_DEFAULTCOLOR));
  if (direct_ico != nullptr) {
    return direct_ico;
  }

  std::unique_ptr<Gdiplus::Bitmap> bmp(
      Gdiplus::Bitmap::FromFile(file_path.c_str()));
  if (bmp && bmp->GetLastStatus() == Gdiplus::Ok) {
    if (target_size > 0 &&
        (static_cast<int>(bmp->GetWidth()) != target_size ||
         static_cast<int>(bmp->GetHeight()) != target_size)) {
      std::unique_ptr<Gdiplus::Bitmap> scaled(
          new Gdiplus::Bitmap(target_size, target_size,
                              PixelFormat32bppPARGB));
      if (scaled && scaled->GetLastStatus() == Gdiplus::Ok) {
        Gdiplus::Graphics graphics(scaled.get());
        graphics.SetInterpolationMode(
            Gdiplus::InterpolationModeHighQualityBicubic);
        graphics.SetSmoothingMode(Gdiplus::SmoothingModeHighQuality);
        graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);
        graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
        graphics.DrawImage(bmp.get(), 0, 0, target_size, target_size);
        HICON hicon = nullptr;
        scaled->GetHICON(&hicon);
        return hicon;
      }
    }
    HICON hicon = nullptr;
    bmp->GetHICON(&hicon);
    return hicon;
  }

  return nullptr;
}

HBITMAP XueHuaNaviteSystemTrayPlugin::LoadHBitmapFromMap(
    const flutter::EncodableMap &icon_map, int target_size) {
  // Menu bitmaps (MIIM_BITMAP / hbmpItem) are drawn 1:1 by Win32. Always emit
  // exactly target_size (typically SM_CXMENUCHECK) so asset/system icons that
  // arrive larger -- or whose iconSize overrides LoadHIconFromMap -- do not
  // blow up the popup row height relative to the text.
  if (target_size <= 0) {
    target_size = GetSystemMetrics(SM_CXMENUCHECK);
  }

  HICON hicon = LoadHIconFromMap(icon_map, target_size);
  if (hicon == nullptr) {
    return nullptr;
  }

  std::unique_ptr<Gdiplus::Bitmap> source(Gdiplus::Bitmap::FromHICON(hicon));
  DestroyIcon(hicon);
  if (!source || source->GetLastStatus() != Gdiplus::Ok) {
    return nullptr;
  }

  std::unique_ptr<Gdiplus::Bitmap> scaled(
      new Gdiplus::Bitmap(target_size, target_size, PixelFormat32bppPARGB));
  if (!scaled || scaled->GetLastStatus() != Gdiplus::Ok) {
    return nullptr;
  }

  {
    Gdiplus::Graphics graphics(scaled.get());
    graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeHighQuality);
    graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);
    graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
    graphics.DrawImage(source.get(), 0, 0, target_size, target_size);
  }

  HBITMAP hbitmap = nullptr;
  scaled->GetHBITMAP(Gdiplus::Color(0, 0, 0, 0), &hbitmap);
  if (hbitmap != nullptr) {
    allocated_bitmaps_.push_back(hbitmap);
    return hbitmap;
  }
  return nullptr;
}
void XueHuaNaviteSystemTrayPlugin::FreeMenuResources() {
  if (root_menu_ != nullptr) {
    DestroyMenu(root_menu_);
    root_menu_ = nullptr;
  }
  for (HBITMAP bmp : allocated_bitmaps_) {
    if (bmp != nullptr) {
      DeleteObject(bmp);
    }
  }
  allocated_bitmaps_.clear();
  menu_by_cmd_.clear();
  cmd_by_id_.clear();
  next_command_id_ = 2000;
}

void XueHuaNaviteSystemTrayPlugin::RebuildContextMenu(
    const flutter::EncodableList &items) {
  FreeMenuResources();
  root_menu_ = BuildSubMenu(items);
}

HMENU XueHuaNaviteSystemTrayPlugin::BuildSubMenu(
    const flutter::EncodableList &items) {
  HMENU menu = CreatePopupMenu();
  UINT pos = 0;

  for (const auto &raw_val : items) {
    if (!std::holds_alternative<flutter::EncodableMap>(raw_val)) {
      continue;
    }
    const auto &item_map = std::get<flutter::EncodableMap>(raw_val);
    std::string type = GetStringOrDefault(item_map, "type", "action");
    std::string id = GetStringOrDefault(item_map, "id");

    if (type == "separator") {
      MENUITEMINFOW sep{};
      sep.cbSize = sizeof(MENUITEMINFOW);
      sep.fMask = MIIM_FTYPE;
      sep.fType = MFT_SEPARATOR;
      InsertMenuItemW(menu, pos++, TRUE, &sep);
      continue;
    }

    WinMenuItemRecord rec;
    rec.command_id = next_command_id_++;
    rec.id = id;
    rec.type = type;
    rec.label = GetStringOrDefault(item_map, "label");
    rec.shortcut_label = GetStringOrDefault(item_map, "shortcutLabel");
    rec.group_id = GetStringOrDefault(item_map, "groupId");
    rec.enabled =
        (type == "header") ? false : GetBoolOrDefault(item_map, "enabled", true);
    rec.checked = GetBoolOrDefault(item_map, "checked", false);
    rec.parent_menu = menu;

    std::string full_label = rec.label;
    if (!rec.shortcut_label.empty()) {
      full_label += "\t" + rec.shortcut_label;
    }
    std::wstring wide_label = Utf8ToWide(full_label);

    MENUITEMINFOW mii{};
    mii.cbSize = sizeof(MENUITEMINFOW);
    mii.fMask = MIIM_ID | MIIM_STRING | MIIM_STATE | MIIM_FTYPE;
    mii.wID = rec.command_id;
    mii.dwTypeData = wide_label.data();
    mii.fType = (type == "radio") ? MFT_RADIOCHECK : MFT_STRING;
    mii.fState = (rec.enabled ? MFS_ENABLED : MFS_DISABLED) |
                 (rec.checked ? MFS_CHECKED : MFS_UNCHECKED);

    const auto *icon_val = FindMapValue(item_map, "icon");
    if (icon_val && std::holds_alternative<flutter::EncodableMap>(*icon_val)) {
      HBITMAP hbmp = LoadHBitmapFromMap(
          std::get<flutter::EncodableMap>(*icon_val),
          GetSystemMetrics(SM_CXMENUCHECK));
      if (hbmp != nullptr) {
        mii.fMask |= MIIM_BITMAP;
        mii.hbmpItem = hbmp;
        rec.bitmap = hbmp;
      }
    }

    if (type == "submenu") {
      const auto *children_val = FindMapValue(item_map, "children");
      if (children_val &&
          std::holds_alternative<flutter::EncodableList>(*children_val)) {
        HMENU sub =
            BuildSubMenu(std::get<flutter::EncodableList>(*children_val));
        mii.fMask |= MIIM_SUBMENU;
        mii.hSubMenu = sub;
      }
    }

    InsertMenuItemW(menu, pos++, TRUE, &mii);
    menu_by_cmd_[rec.command_id] = rec;
    if (!rec.id.empty()) {
      cmd_by_id_[rec.id] = rec.command_id;
    }
  }

  return menu;
}

void XueHuaNaviteSystemTrayPlugin::UpdateMenuItem(
    const flutter::EncodableMap &args) {
  std::string id = GetStringOrDefault(args, "id");
  auto it = cmd_by_id_.find(id);
  if (it == cmd_by_id_.end()) {
    return;
  }
  auto rec_it = menu_by_cmd_.find(it->second);
  if (rec_it == menu_by_cmd_.end()) {
    return;
  }
  WinMenuItemRecord &rec = rec_it->second;

  MENUITEMINFOW mii{};
  mii.cbSize = sizeof(MENUITEMINFOW);

  std::wstring wide_label;
  if (FindMapValue(args, "label") != nullptr) {
    rec.label = GetStringOrDefault(args, "label");
    std::string full_label = rec.label;
    if (!rec.shortcut_label.empty()) {
      full_label += "\t" + rec.shortcut_label;
    }
    wide_label = Utf8ToWide(full_label);
    mii.fMask |= MIIM_STRING;
    mii.dwTypeData = wide_label.data();
  }

  if (FindMapValue(args, "enabled") != nullptr ||
      FindMapValue(args, "checked") != nullptr) {
    if (FindMapValue(args, "enabled") != nullptr) {
      rec.enabled = GetBoolOrDefault(args, "enabled", rec.enabled);
    }
    if (FindMapValue(args, "checked") != nullptr) {
      rec.checked = GetBoolOrDefault(args, "checked", rec.checked);
    }
    mii.fMask |= MIIM_STATE;
    mii.fState = (rec.enabled ? MFS_ENABLED : MFS_DISABLED) |
                 (rec.checked ? MFS_CHECKED : MFS_UNCHECKED);
  }

  const auto *icon_val = FindMapValue(args, "icon");
  if (icon_val && std::holds_alternative<flutter::EncodableMap>(*icon_val)) {
    HBITMAP hbmp = LoadHBitmapFromMap(
        std::get<flutter::EncodableMap>(*icon_val),
        GetSystemMetrics(SM_CXMENUCHECK));
    if (hbmp != nullptr) {
      mii.fMask |= MIIM_BITMAP;
      mii.hbmpItem = hbmp;
      rec.bitmap = hbmp;
    }
  }

  if (mii.fMask != 0 && rec.parent_menu != nullptr) {
    SetMenuItemInfoW(rec.parent_menu, rec.command_id, FALSE, &mii);
  }
}

void XueHuaNaviteSystemTrayPlugin::PopUpContextMenu() {
  if (root_menu_ == nullptr || message_hwnd_ == nullptr) {
    return;
  }
  POINT pt{};
  GetCursorPos(&pt);

  // Required by Win32 Shell_NotifyIcon guidelines so clicking outside the popup
  // menu dismisses the menu cleanly.
  SetForegroundWindow(message_hwnd_);
  UINT selected_cmd = static_cast<UINT>(TrackPopupMenu(
      root_menu_, TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY, pt.x, pt.y, 0,
      message_hwnd_, nullptr));
  PostMessageW(message_hwnd_, WM_NULL, 0, 0);

  if (selected_cmd != 0) {
    HandleMenuCommand(selected_cmd);
  }
}

void XueHuaNaviteSystemTrayPlugin::HandleMenuCommand(UINT command_id) {
  auto it = menu_by_cmd_.find(command_id);
  if (it == menu_by_cmd_.end()) {
    return;
  }
  WinMenuItemRecord &rec = it->second;

  bool has_checked_state = false;
  if (rec.type == "checkbox") {
    rec.checked = !rec.checked;
    has_checked_state = true;
    MENUITEMINFOW mii{};
    mii.cbSize = sizeof(MENUITEMINFOW);
    mii.fMask = MIIM_STATE;
    mii.fState = (rec.enabled ? MFS_ENABLED : MFS_DISABLED) |
                 (rec.checked ? MFS_CHECKED : MFS_UNCHECKED);
    SetMenuItemInfoW(rec.parent_menu, rec.command_id, FALSE, &mii);
  } else if (rec.type == "radio") {
    has_checked_state = true;
    for (auto &pair : menu_by_cmd_) {
      WinMenuItemRecord &other = pair.second;
      if (other.type == "radio" && other.group_id == rec.group_id) {
        other.checked = (other.command_id == rec.command_id);
        MENUITEMINFOW mii{};
        mii.cbSize = sizeof(MENUITEMINFOW);
        mii.fMask = MIIM_STATE;
        mii.fState = (other.enabled ? MFS_ENABLED : MFS_DISABLED) |
                     (other.checked ? MFS_CHECKED : MFS_UNCHECKED);
        SetMenuItemInfoW(other.parent_menu, other.command_id, FALSE, &mii);
      }
    }
  }

  if (channel_ != nullptr) {
    flutter::EncodableMap payload{
        {flutter::EncodableValue("type"),
         flutter::EncodableValue("menuItemClick")},
        {flutter::EncodableValue("mouseButton"),
         flutter::EncodableValue("left")},
        {flutter::EncodableValue("menuItemId"),
         flutter::EncodableValue(rec.id)},
        {flutter::EncodableValue("timestamp"),
         flutter::EncodableValue(CurrentTimestampMs())},
    };
    if (has_checked_state) {
      payload[flutter::EncodableValue("checked")] =
          flutter::EncodableValue(rec.checked);
    }
    channel_->InvokeMethod("onTrayEvent",
                           std::make_unique<flutter::EncodableValue>(payload));
  }
}

bool XueHuaNaviteSystemTrayPlugin::GetTrayBounds(RECT *out_rect) const {
  if (!tray_added_ || message_hwnd_ == nullptr || out_rect == nullptr) {
    return false;
  }
  NOTIFYICONIDENTIFIER ident{};
  ident.cbSize = sizeof(NOTIFYICONIDENTIFIER);
  ident.hWnd = message_hwnd_;
  ident.uID = kTrayIconId;
  HRESULT hr = Shell_NotifyIconGetRect(&ident, out_rect);
  if (SUCCEEDED(hr)) {
    return true;
  }
  POINT pt{};
  if (GetCursorPos(&pt)) {
    out_rect->left = pt.x;
    out_rect->top = pt.y;
    out_rect->right = pt.x + GetSystemMetrics(SM_CXSMICON);
    out_rect->bottom = pt.y + GetSystemMetrics(SM_CYSMICON);
    return true;
  }
  return false;
}

void XueHuaNaviteSystemTrayPlugin::EmitTrayClickEvent(
    const std::string &event_type, const std::string &mouse_button) {
  if (channel_ == nullptr) {
    return;
  }
  POINT pt{};
  GetCursorPos(&pt);

  flutter::EncodableMap payload{
      {flutter::EncodableValue("type"), flutter::EncodableValue(event_type)},
      {flutter::EncodableValue("mouseButton"),
       flutter::EncodableValue(mouse_button)},
      {flutter::EncodableValue("cursorX"),
       flutter::EncodableValue(static_cast<double>(pt.x))},
      {flutter::EncodableValue("cursorY"),
       flutter::EncodableValue(static_cast<double>(pt.y))},
      {flutter::EncodableValue("timestamp"),
       flutter::EncodableValue(CurrentTimestampMs())},
  };

  RECT rc{};
  if (GetTrayBounds(&rc)) {
    flutter::EncodableMap bounds_map{
        {flutter::EncodableValue("x"),
         flutter::EncodableValue(static_cast<double>(rc.left))},
        {flutter::EncodableValue("y"),
         flutter::EncodableValue(static_cast<double>(rc.top))},
        {flutter::EncodableValue("width"),
         flutter::EncodableValue(static_cast<double>(rc.right - rc.left))},
        {flutter::EncodableValue("height"),
         flutter::EncodableValue(static_cast<double>(rc.bottom - rc.top))},
    };
    payload[flutter::EncodableValue("bounds")] =
        flutter::EncodableValue(bounds_map);
  }

  channel_->InvokeMethod("onTrayEvent",
                         std::make_unique<flutter::EncodableValue>(payload));
}

bool XueHuaNaviteSystemTrayPlugin::ShowNotification(
    const flutter::EncodableMap &args) {
  if (!tray_added_) {
    return false;
  }
  std::wstring title = Utf8ToWide(GetStringOrDefault(args, "title"));
  std::wstring message = Utf8ToWide(GetStringOrDefault(args, "message"));
  std::string icon_type = GetStringOrDefault(args, "iconType", "info");
  bool play_sound = GetBoolOrDefault(args, "playSound", true);

  nid_.uFlags = NIF_INFO;
  wcsncpy_s(nid_.szInfoTitle, title.c_str(), _TRUNCATE);
  wcsncpy_s(nid_.szInfo, message.c_str(), _TRUNCATE);

  DWORD info_flags = NIIF_INFO;
  if (icon_type == "none") {
    info_flags = NIIF_NONE;
  } else if (icon_type == "warning") {
    info_flags = NIIF_WARNING;
  } else if (icon_type == "error") {
    info_flags = NIIF_ERROR;
  }
  if (!play_sound) {
    info_flags |= NIIF_NOSOUND;
  }
  nid_.dwInfoFlags = info_flags;

  return Shell_NotifyIconW(NIM_MODIFY, &nid_) == TRUE;
}

void XueHuaNaviteSystemTrayPlugin::DestroyTray() {
  if (tray_added_) {
    Shell_NotifyIconW(NIM_DELETE, &nid_);
    tray_added_ = false;
  }
  if (owns_current_hicon_ && current_hicon_ != nullptr) {
    DestroyIcon(current_hicon_);
  }
  current_hicon_ = nullptr;
  owns_current_hicon_ = false;
  FreeMenuResources();
}

}  // namespace xue_hua_navite_system_tray
