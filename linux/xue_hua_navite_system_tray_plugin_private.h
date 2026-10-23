#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN_PRIVATE_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN_PRIVATE_H_

#include <flutter_linux/flutter_linux.h>

#include "include/xue_hua_navite_system_tray/xue_hua_navite_system_tray_plugin.h"

// Builds the Linux capabilities map response for unit testing and runtime queries.
FlMethodResponse *build_linux_capabilities_response(const gchar *backend_name,
                                                    gboolean is_app_indicator);

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_SYSTEM_TRAY_PLUGIN_PRIVATE_H_
