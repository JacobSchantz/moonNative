#include "moon_native_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace moon_native {

// static
void MoonNativePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "moon_native",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<MoonNativePlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

MoonNativePlugin::MoonNativePlugin() {}

MoonNativePlugin::~MoonNativePlugin() {}

void MoonNativePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method_call.method_name().compare("performNativeCalculation") == 0) {
    // Check if arguments exist and are of the expected type
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
      return;
    }

    auto a_it = arguments->find(flutter::EncodableValue("a"));
    auto b_it = arguments->find(flutter::EncodableValue("b"));

    if (a_it == arguments->end() || b_it == arguments->end()) {
      result->Error("INVALID_ARGUMENTS", "Arguments 'a' and 'b' must be provided");
      return;
    }

    double a = 0.0;
    double b = 0.0;
    
    try {
      a = std::get<double>(a_it->second);
      b = std::get<double>(b_it->second);
    } catch (const std::bad_variant_access&) {
      result->Error("INVALID_ARGUMENTS", "Arguments 'a' and 'b' must be numbers");
      return;
    }

    // Windows-specific implementation: Subtract and square
    double calculation_result = (a - b) * (a - b);
    result->Success(flutter::EncodableValue(calculation_result));
  } else {
    result->NotImplemented();
  }
}

}  // namespace moon_native
