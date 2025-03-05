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
#include <fstream>
#include <string>
#include <filesystem>
#include <chrono>
#include <thread>

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
  } else if (method_call.method_name().compare("trimVideo") == 0) {
    // Check if arguments exist and are of the expected type
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
      return;
    }

    auto video_path_it = arguments->find(flutter::EncodableValue("videoPath"));
    auto start_time_it = arguments->find(flutter::EncodableValue("startTime"));
    auto end_time_it = arguments->find(flutter::EncodableValue("endTime"));

    if (video_path_it == arguments->end() || 
        start_time_it == arguments->end() || 
        end_time_it == arguments->end()) {
      result->Error("INVALID_ARGUMENTS", 
                  "Arguments 'videoPath', 'startTime', and 'endTime' must be provided");
      return;
    }

    std::string video_path;
    double start_time = 0.0;
    double end_time = 0.0;
    
    try {
      video_path = std::get<std::string>(video_path_it->second);
      start_time = std::get<double>(start_time_it->second);
      end_time = std::get<double>(end_time_it->second);
    } catch (const std::bad_variant_access&) {
      result->Error("INVALID_ARGUMENTS", 
                  "videoPath must be a string, startTime and endTime must be numbers");
      return;
    }

    // In a real implementation, you would use Windows-specific video processing APIs
    // like Media Foundation or DirectShow to trim the video
    // For this demo, we'll implement a placeholder version

    try {
      // Verify the input file exists
      if (!std::filesystem::exists(video_path)) {
        result->Error("FILE_NOT_FOUND", "Input video file not found: " + video_path);
        return;
      }

      // Generate output path by adding '_trimmed' before the extension
      std::filesystem::path input_path(video_path);
      std::filesystem::path output_dir = input_path.parent_path();
      std::string filename = input_path.stem().string() + "_trimmed" + input_path.extension().string();
      std::filesystem::path output_path = output_dir / filename;

      // In a real implementation, you would use video processing libraries here
      // For demonstration purposes, we'll simulate the process with a delay
      std::this_thread::sleep_for(std::chrono::seconds(2));

      // Create a dummy file to simulate the output
      std::ofstream output_file(output_path.string(), std::ios::binary);
      if (!output_file) {
        result->Error("FILE_ERROR", "Could not create output file: " + output_path.string());
        return;
      }

      // Copy a portion of the original file to simulate trimming
      std::ifstream input_file(video_path, std::ios::binary);
      if (!input_file) {
        result->Error("FILE_ERROR", "Could not open input file: " + video_path);
        return;
      }

      // Just copy the file for demonstration (in a real implementation, you would trim it)
      output_file << input_file.rdbuf();
      
      output_file.close();
      input_file.close();

      // Return the path to the trimmed video
      result->Success(flutter::EncodableValue(output_path.string()));

    } catch (const std::exception& e) {
      result->Error("TRIM_ERROR", std::string("Error trimming video: ") + e.what());
    }
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
