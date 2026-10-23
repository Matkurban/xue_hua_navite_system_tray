#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include "include/xue_hua_navite_system_tray/xue_hua_navite_system_tray_plugin.h"
#include "xue_hua_navite_system_tray_plugin_private.h"

namespace xue_hua_navite_system_tray {
namespace test {

TEST(XueHuaNaviteSystemTrayPlugin, BuildLinuxCapabilitiesResponse) {
  g_autoptr(FlMethodResponse) response =
      build_linux_capabilities_response("AyatanaAppIndicator3", TRUE);
  ASSERT_NE(response, nullptr);
  ASSERT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  FlValue *result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  ASSERT_EQ(fl_value_get_type(result), FL_VALUE_TYPE_MAP);

  FlValue *platform = fl_value_lookup_string(result, "platform");
  ASSERT_NE(platform, nullptr);
  EXPECT_STREQ(fl_value_get_string(platform), "linux");

  FlValue *backend = fl_value_lookup_string(result, "backendName");
  ASSERT_NE(backend, nullptr);
  EXPECT_STREQ(fl_value_get_string(backend), "AyatanaAppIndicator3");
}

}  // namespace test
}  // namespace xue_hua_navite_system_tray
