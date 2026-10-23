#include "include/xue_hua_navite_system_tray/xue_hua_navite_system_tray_plugin.h"

#include <dlfcn.h>
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <limits.h>
#include <unistd.h>

#include <chrono>
#include <cstring>
#include <map>
#include <string>
#include <vector>

#include "xue_hua_navite_system_tray_plugin_private.h"

#define XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN(obj)                               \
  (G_TYPE_CHECK_INSTANCE_CAST((obj),                                         \
                              xue_hua_navite_system_tray_plugin_get_type(),  \
                              XueHuaNaviteSystemTrayPlugin))

namespace {

// AppIndicator3 / AyatanaAppIndicator3 C ABI function pointer types loaded via dlopen.
typedef enum {
  APP_INDICATOR_CATEGORY_APPLICATION_STATUS = 0,
} AppIndicatorCategory;

typedef enum {
  APP_INDICATOR_STATUS_PASSIVE = 0,
  APP_INDICATOR_STATUS_ACTIVE = 1,
  APP_INDICATOR_STATUS_ATTENTION = 2,
} AppIndicatorStatus;

typedef void *(*FnAppIndicatorNew)(const gchar *id, const gchar *icon_name,
                                   AppIndicatorCategory category);
typedef void (*FnAppIndicatorSetStatus)(void *indicator,
                                        AppIndicatorStatus status);
typedef void (*FnAppIndicatorSetIconFull)(void *indicator,
                                          const gchar *icon_name,
                                          const gchar *icon_desc);
typedef void (*FnAppIndicatorSetMenu)(void *indicator, GtkMenu *menu);
typedef void (*FnAppIndicatorSetLabel)(void *indicator, const gchar *label,
                                       const gchar *guide);
typedef void (*FnAppIndicatorSetTitle)(void *indicator, const gchar *title);
typedef void (*FnAppIndicatorSetSecondaryActivateTarget)(void *indicator,
                                                         GtkWidget *menuitem);

struct AppIndicatorSymbols {
  void *handle = nullptr;
  const char *backend_name = "GtkStatusIcon";
  FnAppIndicatorNew app_indicator_new = nullptr;
  FnAppIndicatorSetStatus app_indicator_set_status = nullptr;
  FnAppIndicatorSetIconFull app_indicator_set_icon_full = nullptr;
  FnAppIndicatorSetMenu app_indicator_set_menu = nullptr;
  FnAppIndicatorSetLabel app_indicator_set_label = nullptr;
  FnAppIndicatorSetTitle app_indicator_set_title = nullptr;
  FnAppIndicatorSetSecondaryActivateTarget
      app_indicator_set_secondary_activate_target = nullptr;

  bool Load() {
    if (handle != nullptr) {
      return true;
    }
    const char *candidates[] = {
        "libayatana-appindicator3.so.1",
        "libappindicator3.so.1",
    };
    const char *names[] = {
        "AyatanaAppIndicator3",
        "AppIndicator3",
    };
    for (size_t i = 0; i < 2; ++i) {
      void *h = dlopen(candidates[i], RTLD_LAZY | RTLD_LOCAL);
      if (h != nullptr) {
        auto fn_new = reinterpret_cast<FnAppIndicatorNew>(
            dlsym(h, "app_indicator_new"));
        auto fn_status = reinterpret_cast<FnAppIndicatorSetStatus>(
            dlsym(h, "app_indicator_set_status"));
        auto fn_icon = reinterpret_cast<FnAppIndicatorSetIconFull>(
            dlsym(h, "app_indicator_set_icon_full"));
        auto fn_menu = reinterpret_cast<FnAppIndicatorSetMenu>(
            dlsym(h, "app_indicator_set_menu"));
        auto fn_label = reinterpret_cast<FnAppIndicatorSetLabel>(
            dlsym(h, "app_indicator_set_label"));
        auto fn_title = reinterpret_cast<FnAppIndicatorSetTitle>(
            dlsym(h, "app_indicator_set_title"));
        auto fn_secondary =
            reinterpret_cast<FnAppIndicatorSetSecondaryActivateTarget>(
                dlsym(h, "app_indicator_set_secondary_activate_target"));

        if (fn_new && fn_status && fn_icon && fn_menu) {
          handle = h;
          backend_name = names[i];
          app_indicator_new = fn_new;
          app_indicator_set_status = fn_status;
          app_indicator_set_icon_full = fn_icon;
          app_indicator_set_menu = fn_menu;
          app_indicator_set_label = fn_label;
          app_indicator_set_title = fn_title;
          app_indicator_set_secondary_activate_target = fn_secondary;
          return true;
        }
        dlclose(h);
      }
    }
    return false;
  }
};

struct LinuxMenuItemEntry {
  std::string id;
  std::string type;
  std::string group_id;
  bool checked = false;
  GtkWidget *widget = nullptr;
};

int64_t CurrentTimestampMs() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(system_clock::now().time_since_epoch())
      .count();
}

std::string ResolveExecutableDir() {
  char buf[PATH_MAX] = {0};
  ssize_t len = readlink("/proc/self/exe", buf, sizeof(buf) - 1);
  if (len <= 0) {
    return ".";
  }
  buf[len] = '\0';
  std::string full(buf);
  auto slash = full.find_last_of('/');
  return (slash != std::string::npos) ? full.substr(0, slash) : ".";
}

std::string ResolveFlutterAssetPath(const std::string &asset_path) {
  std::string candidate =
      ResolveExecutableDir() + "/data/flutter_assets/" + asset_path;
  if (g_file_test(candidate.c_str(), G_FILE_TEST_EXISTS)) {
    return candidate;
  }
  return asset_path;
}

}  // namespace

struct _XueHuaNaviteSystemTrayPlugin {
  GObject parent_instance;
  FlPluginRegistrar *registrar;
  FlMethodChannel *channel;

  AppIndicatorSymbols indicator_api;
  bool using_app_indicator;
  void *app_indicator;

  G_GNUC_BEGIN_IGNORE_DEPRECATIONS
  GtkStatusIcon *status_icon;
  G_GNUC_END_IGNORE_DEPRECATIONS

  GtkWidget *context_menu;
  std::string menu_trigger;
  bool suppress_menu_signals;
  int temp_icon_counter;
  std::map<std::string, LinuxMenuItemEntry> *menu_items;
};

G_DEFINE_TYPE(XueHuaNaviteSystemTrayPlugin, xue_hua_navite_system_tray_plugin,
              g_object_get_type())

static const gchar *GetFlMapString(FlValue *map, const char *key,
                                   const gchar *default_val = "") {
  if (!map || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return default_val;
  }
  FlValue *v = fl_value_lookup_string(map, key);
  if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
    return fl_value_get_string(v);
  }
  return default_val;
}

static bool GetFlMapBool(FlValue *map, const char *key,
                         bool default_val = false) {
  if (!map || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return default_val;
  }
  FlValue *v = fl_value_lookup_string(map, key);
  if (v && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
    return fl_value_get_bool(v);
  }
  return default_val;
}

static GtkWindow *GetMainGtkWindow(XueHuaNaviteSystemTrayPlugin *self) {
  if (self->registrar != nullptr) {
    FlView *view = fl_plugin_registrar_get_view(self->registrar);
    if (view != nullptr) {
      GtkWidget *toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
      if (GTK_IS_WINDOW(toplevel)) {
        return GTK_WINDOW(toplevel);
      }
    }
  }
  return nullptr;
}

static void EmitTrayEvent(XueHuaNaviteSystemTrayPlugin *self,
                          const char *event_type, const char *mouse_button,
                          const char *menu_item_id = nullptr,
                          const bool *checked = nullptr) {
  if (self->channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) payload = fl_value_new_map();
  fl_value_set_string_take(payload, "type", fl_value_new_string(event_type));
  fl_value_set_string_take(payload, "mouseButton",
                           fl_value_new_string(mouse_button));
  fl_value_set_string_take(payload, "timestamp",
                           fl_value_new_int(CurrentTimestampMs()));

  if (menu_item_id != nullptr) {
    fl_value_set_string_take(payload, "menuItemId",
                             fl_value_new_string(menu_item_id));
  }
  if (checked != nullptr) {
    fl_value_set_string_take(payload, "checked", fl_value_new_bool(*checked));
  }

  fl_method_channel_invoke_method(self->channel, "onTrayEvent", payload,
                                  nullptr, nullptr, nullptr);
}

static std::string ResolveIconPathOrName(XueHuaNaviteSystemTrayPlugin *self,
                                         FlValue *icon_map,
                                         bool *out_is_theme_name) {
  *out_is_theme_name = false;
  if (!icon_map || fl_value_get_type(icon_map) != FL_VALUE_TYPE_MAP) {
    *out_is_theme_name = true;
    return "application-x-executable";
  }

  std::string type = GetFlMapString(icon_map, "type", "asset");
  if (type == "system") {
    *out_is_theme_name = true;
    std::string sys_name =
        GetFlMapString(icon_map, "systemName", "dialog-information");
    return sys_name;
  }

  if (type == "bytes") {
    FlValue *bytes_val = fl_value_lookup_string(icon_map, "bytes");
    if (bytes_val && fl_value_get_type(bytes_val) == FL_VALUE_TYPE_UINT8_LIST) {
      const uint8_t *data = fl_value_get_uint8_list(bytes_val);
      size_t len = fl_value_get_length(bytes_val);
      g_mkdir_with_parents("/tmp/xue_hua_system_tray", 0700);
      g_autofree gchar *tmp_path =
          g_strdup_printf("/tmp/xue_hua_system_tray/tray_icon_%d.png",
                          ++self->temp_icon_counter);
      if (g_file_set_contents(tmp_path, reinterpret_cast<const gchar *>(data),
                              static_cast<gssize>(len), nullptr)) {
        return std::string(tmp_path);
      }
    }
    *out_is_theme_name = true;
    return "application-x-executable";
  }

  std::string raw_path = GetFlMapString(icon_map, "path");
  return (type == "asset") ? ResolveFlutterAssetPath(raw_path) : raw_path;
}

static void ApplyTrayIcon(XueHuaNaviteSystemTrayPlugin *self,
                          FlValue *icon_map) {
  bool is_theme = false;
  std::string icon_ref = ResolveIconPathOrName(self, icon_map, &is_theme);

  if (self->using_app_indicator && self->app_indicator != nullptr) {
    self->indicator_api.app_indicator_set_icon_full(
        self->app_indicator, icon_ref.c_str(), "System Tray Icon");
  } else if (self->status_icon != nullptr) {
    G_GNUC_BEGIN_IGNORE_DEPRECATIONS
    if (is_theme) {
      gtk_status_icon_set_from_icon_name(self->status_icon, icon_ref.c_str());
    } else {
      gtk_status_icon_set_from_file(self->status_icon, icon_ref.c_str());
    }
    G_GNUC_END_IGNORE_DEPRECATIONS
  }
}

static void OnGtkMenuItemActivated(GtkMenuItem *menu_item, gpointer user_data) {
  auto *self = XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN(user_data);
  if (self->suppress_menu_signals) {
    return;
  }
  const char *item_id = static_cast<const char *>(
      g_object_get_data(G_OBJECT(menu_item), "xue_hua_item_id"));
  if (item_id == nullptr) {
    return;
  }

  auto it = self->menu_items->find(item_id);
  if (it == self->menu_items->end()) {
    return;
  }
  LinuxMenuItemEntry &entry = it->second;

  if (entry.type == "checkbox" && GTK_IS_CHECK_MENU_ITEM(menu_item)) {
    bool active =
        gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(menu_item));
    entry.checked = active;
    EmitTrayEvent(self, "menuItemClick", "left", item_id, &active);
  } else if (entry.type == "radio" && GTK_IS_CHECK_MENU_ITEM(menu_item)) {
    self->suppress_menu_signals = true;
    for (auto &pair : *self->menu_items) {
      LinuxMenuItemEntry &other = pair.second;
      if (other.type == "radio" && other.group_id == entry.group_id &&
          GTK_IS_CHECK_MENU_ITEM(other.widget)) {
        bool is_target = (other.id == entry.id);
        other.checked = is_target;
        gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(other.widget),
                                       is_target);
      }
    }
    self->suppress_menu_signals = false;
    bool checked_val = true;
    EmitTrayEvent(self, "menuItemClick", "left", item_id, &checked_val);
  } else {
    EmitTrayEvent(self, "menuItemClick", "left", item_id, nullptr);
  }
}

static GtkWidget *BuildGtkMenuHierarchy(XueHuaNaviteSystemTrayPlugin *self,
                                        FlValue *items_list) {
  GtkWidget *menu = gtk_menu_new();
  if (!items_list || fl_value_get_type(items_list) != FL_VALUE_TYPE_LIST) {
    return menu;
  }

  size_t count = fl_value_get_length(items_list);
  for (size_t i = 0; i < count; ++i) {
    FlValue *item_map = fl_value_get_list_value(items_list, i);
    if (!item_map || fl_value_get_type(item_map) != FL_VALUE_TYPE_MAP) {
      continue;
    }

    std::string type = GetFlMapString(item_map, "type", "action");
    std::string id = GetFlMapString(item_map, "id");

    if (type == "separator") {
      GtkWidget *sep = gtk_separator_menu_item_new();
      gtk_widget_show(sep);
      gtk_menu_shell_append(GTK_MENU_SHELL(menu), sep);
      continue;
    }

    std::string label = GetFlMapString(item_map, "label");
    std::string shortcut_label = GetFlMapString(item_map, "shortcutLabel");
    std::string display_label =
        shortcut_label.empty() ? label : (label + "  (" + shortcut_label + ")");

    GtkWidget *item_widget = nullptr;
    bool checked = GetFlMapBool(item_map, "checked", false);

    if (type == "checkbox" || type == "radio") {
      item_widget =
          gtk_check_menu_item_new_with_label(display_label.c_str());
      if (type == "radio") {
        gtk_check_menu_item_set_draw_as_radio(
            GTK_CHECK_MENU_ITEM(item_widget), TRUE);
      }
      gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(item_widget), checked);
    } else {
      item_widget = gtk_menu_item_new_with_label(display_label.c_str());
    }

    bool enabled =
        (type == "header") ? false : GetFlMapBool(item_map, "enabled", true);
    gtk_widget_set_sensitive(item_widget, enabled);

    if (type == "submenu") {
      FlValue *children = fl_value_lookup_string(item_map, "children");
      GtkWidget *sub_menu = BuildGtkMenuHierarchy(self, children);
      gtk_menu_item_set_submenu(GTK_MENU_ITEM(item_widget), sub_menu);
    } else if (type != "header") {
      g_object_set_data_full(G_OBJECT(item_widget), "xue_hua_item_id",
                             g_strdup(id.c_str()), g_free);
      g_signal_connect(item_widget, "activate",
                       G_CALLBACK(OnGtkMenuItemActivated), self);
    }

    gtk_widget_show(item_widget);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_widget);

    LinuxMenuItemEntry entry;
    entry.id = id;
    entry.type = type;
    entry.group_id = GetFlMapString(item_map, "groupId");
    entry.checked = checked;
    entry.widget = item_widget;
    (*self->menu_items)[id] = entry;
  }

  return menu;
}

static void RebuildGtkContextMenu(XueHuaNaviteSystemTrayPlugin *self,
                                  FlValue *items_list) {
  self->menu_items->clear();
  if (self->context_menu != nullptr) {
    gtk_widget_destroy(self->context_menu);
    self->context_menu = nullptr;
  }
  self->context_menu = BuildGtkMenuHierarchy(self, items_list);
  g_object_ref_sink(self->context_menu);

  if (self->using_app_indicator && self->app_indicator != nullptr) {
    self->indicator_api.app_indicator_set_menu(self->app_indicator,
                                               GTK_MENU(self->context_menu));
  }
}

G_GNUC_BEGIN_IGNORE_DEPRECATIONS
static void OnStatusIconActivate(GtkStatusIcon *status_icon,
                                 gpointer user_data) {
  auto *self = XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN(user_data);
  EmitTrayEvent(self, "leftClick", "left");
  if ((self->menu_trigger == "leftClick" || self->menu_trigger == "anyClick") &&
      self->context_menu != nullptr) {
    gtk_menu_popup_at_pointer(GTK_MENU(self->context_menu), nullptr);
  }
}

static void OnStatusIconPopupMenu(GtkStatusIcon *status_icon, guint button,
                                  guint activate_time, gpointer user_data) {
  auto *self = XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN(user_data);
  EmitTrayEvent(self, "rightClick", "right");
  if ((self->menu_trigger == "rightClick" ||
       self->menu_trigger == "anyClick") &&
      self->context_menu != nullptr) {
    gtk_menu_popup(GTK_MENU(self->context_menu), nullptr, nullptr,
                   gtk_status_icon_position_menu, status_icon, button,
                   activate_time);
  }
}
G_GNUC_END_IGNORE_DEPRECATIONS

static void EnsureTrayBackend(XueHuaNaviteSystemTrayPlugin *self) {
  if (self->app_indicator != nullptr || self->status_icon != nullptr) {
    return;
  }

  if (self->indicator_api.Load()) {
    self->using_app_indicator = true;
    self->app_indicator = self->indicator_api.app_indicator_new(
        "xue_hua_navite_system_tray", "application-x-executable",
        APP_INDICATOR_CATEGORY_APPLICATION_STATUS);
    self->indicator_api.app_indicator_set_status(self->app_indicator,
                                                 APP_INDICATOR_STATUS_ACTIVE);
    if (self->context_menu == nullptr) {
      self->context_menu = gtk_menu_new();
      g_object_ref_sink(self->context_menu);
    }
    self->indicator_api.app_indicator_set_menu(self->app_indicator,
                                               GTK_MENU(self->context_menu));
  } else {
    self->using_app_indicator = false;
    G_GNUC_BEGIN_IGNORE_DEPRECATIONS
    self->status_icon =
        gtk_status_icon_new_from_icon_name("application-x-executable");
    g_signal_connect(self->status_icon, "activate",
                     G_CALLBACK(OnStatusIconActivate), self);
    g_signal_connect(self->status_icon, "popup-menu",
                     G_CALLBACK(OnStatusIconPopupMenu), self);
    G_GNUC_END_IGNORE_DEPRECATIONS
  }
}

FlMethodResponse *build_linux_capabilities_response(const gchar *backend_name,
                                                    gboolean is_app_indicator) {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "platform", fl_value_new_string("linux"));
  fl_value_set_string_take(map, "backendName",
                           fl_value_new_string(backend_name));
  fl_value_set_string_take(map, "supportsInlineTitle",
                           fl_value_new_bool(is_app_indicator));
  fl_value_set_string_take(map, "supportsTemplateIcon",
                           fl_value_new_bool(FALSE));
  fl_value_set_string_take(map, "supportsSystemSymbol",
                           fl_value_new_bool(TRUE));
  fl_value_set_string_take(map, "supportsIconBounds",
                           fl_value_new_bool(!is_app_indicator));
  fl_value_set_string_take(map, "supportsLeftRightClickDistinction",
                           fl_value_new_bool(!is_app_indicator));
  fl_value_set_string_take(map, "supportsDoubleClick",
                           fl_value_new_bool(FALSE));
  fl_value_set_string_take(map, "supportsMiddleClick",
                           fl_value_new_bool(is_app_indicator));
  fl_value_set_string_take(map, "supportsMenuIcons", fl_value_new_bool(FALSE));
  fl_value_set_string_take(map, "supportsMenuShortcuts",
                           fl_value_new_bool(TRUE));
  fl_value_set_string_take(map, "supportsMenuTooltips",
                           fl_value_new_bool(FALSE));
  fl_value_set_string_take(map, "supportsProgrammaticMenuPopup",
                           fl_value_new_bool(!is_app_indicator));
  fl_value_set_string_take(map, "supportsDockVisibilityToggle",
                           fl_value_new_bool(FALSE));
  fl_value_set_string_take(map, "supportsTrayNotification",
                           fl_value_new_bool(TRUE));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
}

static void xue_hua_navite_system_tray_plugin_handle_method_call(
    XueHuaNaviteSystemTrayPlugin *self, FlMethodCall *method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar *method = fl_method_call_get_name(method_call);
  FlValue *args = fl_method_call_get_args(method_call);

  if (strcmp(method, "initSystemTray") == 0) {
    EnsureTrayBackend(self);
    self->menu_trigger = GetFlMapString(args, "menuTrigger", "rightClick");

    FlValue *icon_map =
        (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP)
            ? fl_value_lookup_string(args, "icon")
            : nullptr;
    if (icon_map != nullptr) {
      ApplyTrayIcon(self, icon_map);
    }

    const gchar *title = GetFlMapString(args, "title", "");
    const gchar *tooltip = GetFlMapString(args, "toolTip", "");
    if (self->using_app_indicator && self->app_indicator != nullptr) {
      if (self->indicator_api.app_indicator_set_label != nullptr) {
        self->indicator_api.app_indicator_set_label(self->app_indicator, title,
                                                    "");
      }
      if (self->indicator_api.app_indicator_set_title != nullptr) {
        self->indicator_api.app_indicator_set_title(
            self->app_indicator, strlen(tooltip) > 0 ? tooltip : title);
      }
    } else if (self->status_icon != nullptr) {
      G_GNUC_BEGIN_IGNORE_DEPRECATIONS
      gtk_status_icon_set_tooltip_text(
          self->status_icon, strlen(tooltip) > 0 ? tooltip : title);
      G_GNUC_END_IGNORE_DEPRECATIONS
    }

    bool visible = GetFlMapBool(args, "visible", true);
    if (self->using_app_indicator && self->app_indicator != nullptr) {
      self->indicator_api.app_indicator_set_status(
          self->app_indicator,
          visible ? APP_INDICATOR_STATUS_ACTIVE : APP_INDICATOR_STATUS_PASSIVE);
    } else if (self->status_icon != nullptr) {
      G_GNUC_BEGIN_IGNORE_DEPRECATIONS
      gtk_status_icon_set_visible(self->status_icon, visible);
      G_GNUC_END_IGNORE_DEPRECATIONS
    }

    FlValue *menu_items =
        (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP)
            ? fl_value_lookup_string(args, "menuItems")
            : nullptr;
    if (menu_items != nullptr) {
      RebuildGtkContextMenu(self, menu_items);
    }

    g_autoptr(FlValue) ok = fl_value_new_bool(TRUE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(ok));
  } else if (strcmp(method, "setIcon") == 0) {
    EnsureTrayBackend(self);
    ApplyTrayIcon(self, args);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "setTitle") == 0) {
    EnsureTrayBackend(self);
    const gchar *title = GetFlMapString(args, "title", "");
    if (self->using_app_indicator && self->app_indicator != nullptr &&
        self->indicator_api.app_indicator_set_label != nullptr) {
      self->indicator_api.app_indicator_set_label(self->app_indicator, title,
                                                  "");
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "setToolTip") == 0) {
    EnsureTrayBackend(self);
    const gchar *tooltip = GetFlMapString(args, "toolTip", "");
    if (self->using_app_indicator && self->app_indicator != nullptr &&
        self->indicator_api.app_indicator_set_title != nullptr) {
      self->indicator_api.app_indicator_set_title(self->app_indicator, tooltip);
    } else if (self->status_icon != nullptr) {
      G_GNUC_BEGIN_IGNORE_DEPRECATIONS
      gtk_status_icon_set_tooltip_text(self->status_icon, tooltip);
      G_GNUC_END_IGNORE_DEPRECATIONS
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "setMenuTrigger") == 0) {
    self->menu_trigger = GetFlMapString(args, "menuTrigger", "rightClick");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "setVisible") == 0) {
    bool visible = GetFlMapBool(args, "visible", true);
    if (self->using_app_indicator && self->app_indicator != nullptr) {
      self->indicator_api.app_indicator_set_status(
          self->app_indicator,
          visible ? APP_INDICATOR_STATUS_ACTIVE : APP_INDICATOR_STATUS_PASSIVE);
    } else if (self->status_icon != nullptr) {
      G_GNUC_BEGIN_IGNORE_DEPRECATIONS
      gtk_status_icon_set_visible(self->status_icon, visible);
      G_GNUC_END_IGNORE_DEPRECATIONS
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "setContextMenu") == 0) {
    FlValue *menu_items =
        (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP)
            ? fl_value_lookup_string(args, "menuItems")
            : nullptr;
    RebuildGtkContextMenu(self, menu_items);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "updateMenuItem") == 0) {
    std::string id = GetFlMapString(args, "id");
    auto it = self->menu_items->find(id);
    if (it != self->menu_items->end() && it->second.widget != nullptr) {
      LinuxMenuItemEntry &entry = it->second;
      self->suppress_menu_signals = true;
      FlValue *label_val = fl_value_lookup_string(args, "label");
      if (label_val && fl_value_get_type(label_val) == FL_VALUE_TYPE_STRING) {
        gtk_menu_item_set_label(GTK_MENU_ITEM(entry.widget),
                                fl_value_get_string(label_val));
      }
      FlValue *enabled_val = fl_value_lookup_string(args, "enabled");
      if (enabled_val && fl_value_get_type(enabled_val) == FL_VALUE_TYPE_BOOL) {
        gtk_widget_set_sensitive(entry.widget,
                                 fl_value_get_bool(enabled_val));
      }
      FlValue *checked_val = fl_value_lookup_string(args, "checked");
      if (checked_val && fl_value_get_type(checked_val) == FL_VALUE_TYPE_BOOL &&
          GTK_IS_CHECK_MENU_ITEM(entry.widget)) {
        entry.checked = fl_value_get_bool(checked_val);
        gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(entry.widget),
                                       entry.checked);
      }
      self->suppress_menu_signals = false;
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "popUpContextMenu") == 0) {
    if (self->context_menu != nullptr) {
      gtk_menu_popup_at_pointer(GTK_MENU(self->context_menu), nullptr);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "getBounds") == 0) {
    GdkRectangle area{};
    gboolean has_rect = FALSE;
    if (!self->using_app_indicator && self->status_icon != nullptr) {
      G_GNUC_BEGIN_IGNORE_DEPRECATIONS
      has_rect = gtk_status_icon_get_geometry(self->status_icon, nullptr, &area,
                                              nullptr);
      G_GNUC_END_IGNORE_DEPRECATIONS
    }
    if (has_rect) {
      g_autoptr(FlValue) bounds = fl_value_new_map();
      fl_value_set_string_take(bounds, "x", fl_value_new_float(area.x));
      fl_value_set_string_take(bounds, "y", fl_value_new_float(area.y));
      fl_value_set_string_take(bounds, "width", fl_value_new_float(area.width));
      fl_value_set_string_take(bounds, "height",
                               fl_value_new_float(area.height));
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(bounds));
    } else {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    }
  } else if (strcmp(method, "showNotification") == 0) {
    const gchar *title = GetFlMapString(args, "title", "");
    const gchar *message = GetFlMapString(args, "message", "");
    gchar *argv[] = {
        const_cast<gchar *>("notify-send"),
        const_cast<gchar *>(title),
        const_cast<gchar *>(message),
        nullptr,
    };
    gboolean spawned = g_spawn_async(nullptr, argv, nullptr,
                                     G_SPAWN_SEARCH_PATH, nullptr, nullptr,
                                     nullptr, nullptr);
    g_autoptr(FlValue) res = fl_value_new_bool(spawned);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (strcmp(method, "setDockIconVisible") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "showMainWindow") == 0) {
    GtkWindow *window = GetMainGtkWindow(self);
    if (window != nullptr) {
      gtk_widget_show(GTK_WIDGET(window));
      if (GetFlMapBool(args, "focus", true)) {
        gtk_window_present(window);
      }
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "hideMainWindow") == 0) {
    GtkWindow *window = GetMainGtkWindow(self);
    if (window != nullptr) {
      gtk_widget_hide(GTK_WIDGET(window));
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "isMainWindowVisible") == 0) {
    GtkWindow *window = GetMainGtkWindow(self);
    gboolean vis =
        (window != nullptr) ? gtk_widget_get_visible(GTK_WIDGET(window)) : FALSE;
    g_autoptr(FlValue) val = fl_value_new_bool(vis);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(val));
  } else if (strcmp(method, "getCapabilities") == 0) {
    bool has_ai = self->indicator_api.Load();
    response = build_linux_capabilities_response(
        has_ai ? self->indicator_api.backend_name : "GtkStatusIcon", has_ai);
  } else if (strcmp(method, "destroy") == 0) {
    if (self->using_app_indicator && self->app_indicator != nullptr) {
      self->indicator_api.app_indicator_set_status(
          self->app_indicator, APP_INDICATOR_STATUS_PASSIVE);
    }
    if (self->status_icon != nullptr) {
      G_GNUC_BEGIN_IGNORE_DEPRECATIONS
      gtk_status_icon_set_visible(self->status_icon, FALSE);
      G_GNUC_END_IGNORE_DEPRECATIONS
    }
    self->menu_items->clear();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void xue_hua_navite_system_tray_plugin_dispose(GObject *object) {
  auto *self = XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN(object);
  if (self->context_menu != nullptr) {
    gtk_widget_destroy(self->context_menu);
    g_object_unref(self->context_menu);
    self->context_menu = nullptr;
  }
  if (self->status_icon != nullptr) {
    g_object_unref(self->status_icon);
    self->status_icon = nullptr;
  }
  if (self->app_indicator != nullptr) {
    g_object_unref(G_OBJECT(self->app_indicator));
    self->app_indicator = nullptr;
  }
  delete self->menu_items;
  self->menu_items = nullptr;
  g_clear_object(&self->channel);
  g_clear_object(&self->registrar);
  G_OBJECT_CLASS(xue_hua_navite_system_tray_plugin_parent_class)
      ->dispose(object);
}

static void xue_hua_navite_system_tray_plugin_class_init(
    XueHuaNaviteSystemTrayPluginClass *klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_navite_system_tray_plugin_dispose;
}

static void xue_hua_navite_system_tray_plugin_init(
    XueHuaNaviteSystemTrayPlugin *self) {
  self->menu_trigger = "rightClick";
  self->suppress_menu_signals = false;
  self->temp_icon_counter = 0;
  self->menu_items = new std::map<std::string, LinuxMenuItemEntry>();
}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data) {
  XueHuaNaviteSystemTrayPlugin *plugin =
      XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN(user_data);
  xue_hua_navite_system_tray_plugin_handle_method_call(plugin, method_call);
}

void xue_hua_navite_system_tray_plugin_register_with_registrar(
    FlPluginRegistrar *registrar) {
  XueHuaNaviteSystemTrayPlugin *plugin = XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN(
      g_object_new(xue_hua_navite_system_tray_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "xue_hua_navite_system_tray",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
