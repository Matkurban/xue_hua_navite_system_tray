#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "xue_hua_navite_system_tray_plugin.h"

namespace xue_hua_navite_system_tray {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(XueHuaNaviteSystemTrayPlugin, GetCapabilitiesReturnsWindowsMetadata) {
  XueHuaNaviteSystemTrayPlugin plugin;
  EncodableMap capabilities_result;
  plugin.HandleMethodCall(
      MethodCall("getCapabilities", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&capabilities_result](const EncodableValue *result) {
            capabilities_result = std::get<EncodableMap>(*result);
          },
          nullptr, nullptr));

  EXPECT_EQ(std::get<std::string>(
                capabilities_result[EncodableValue("platform")]),
            "windows");
  EXPECT_EQ(std::get<std::string>(
                capabilities_result[EncodableValue("backendName")]),
            "Shell_NotifyIconW");
  EXPECT_TRUE(std::get<bool>(
      capabilities_result[EncodableValue("supportsTrayNotification")]));
}

}  // namespace test
}  // namespace xue_hua_navite_system_tray
