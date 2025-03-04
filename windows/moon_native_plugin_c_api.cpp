#include "include/moon_native/moon_native_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "moon_native_plugin.h"

void MoonNativePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  moon_native::MoonNativePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
