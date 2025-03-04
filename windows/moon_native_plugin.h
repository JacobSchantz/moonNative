#ifndef FLUTTER_PLUGIN_MOON_NATIVE_PLUGIN_H_
#define FLUTTER_PLUGIN_MOON_NATIVE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace moon_native {

class MoonNativePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  MoonNativePlugin();

  virtual ~MoonNativePlugin();

  // Disallow copy and assign.
  MoonNativePlugin(const MoonNativePlugin&) = delete;
  MoonNativePlugin& operator=(const MoonNativePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace moon_native

#endif  // FLUTTER_PLUGIN_MOON_NATIVE_PLUGIN_H_
