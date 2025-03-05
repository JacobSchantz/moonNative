#include "include/moon_native/moon_native_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include <fstream>
#include <filesystem>
#include <thread>
#include <chrono>

#include "moon_native_plugin_private.h"

#define MOON_NATIVE_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), moon_native_plugin_get_type(), \
                              MoonNativePlugin))

struct _MoonNativePlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(MoonNativePlugin, moon_native_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void moon_native_plugin_handle_method_call(
    MoonNativePlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "performNativeCalculation") == 0) {
    response = perform_native_calculation(method_call);
  } else if (strcmp(method, "trimVideo") == 0) {
    response = trim_video(method_call);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* trim_video(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENTS",
        "Arguments must be a map",
        nullptr));
  }
  
  FlValue* video_path_value = fl_value_lookup_string(args, "videoPath");
  FlValue* start_time_value = fl_value_lookup_string(args, "startTime");
  FlValue* end_time_value = fl_value_lookup_string(args, "endTime");
  
  if (video_path_value == nullptr || 
      start_time_value == nullptr || 
      end_time_value == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENTS",
        "Arguments 'videoPath', 'startTime', and 'endTime' must be provided",
        nullptr));
  }
  
  if (fl_value_get_type(video_path_value) != FL_VALUE_TYPE_STRING ||
      fl_value_get_type(start_time_value) != FL_VALUE_TYPE_FLOAT ||
      fl_value_get_type(end_time_value) != FL_VALUE_TYPE_FLOAT) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENTS",
        "videoPath must be a string, startTime and endTime must be numbers",
        nullptr));
  }
  
  const char* video_path = fl_value_get_string(video_path_value);
  double start_time = fl_value_get_float(start_time_value);
  double end_time = fl_value_get_float(end_time_value);
  
  try {
    // Verify the input file exists
    if (!std::filesystem::exists(video_path)) {
      g_autofree gchar* error_msg = g_strdup_printf("Input video file not found: %s", video_path);
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "FILE_NOT_FOUND",
          error_msg,
          nullptr));
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
      g_autofree gchar* error_msg = g_strdup_printf("Could not create output file: %s", output_path.c_str());
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "FILE_ERROR",
          error_msg,
          nullptr));
    }
    
    // Copy a portion of the original file to simulate trimming
    std::ifstream input_file(video_path, std::ios::binary);
    if (!input_file) {
      g_autofree gchar* error_msg = g_strdup_printf("Could not open input file: %s", video_path);
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "FILE_ERROR",
          error_msg,
          nullptr));
    }
    
    // Just copy the file for demonstration (in a real implementation, you would trim it)
    output_file << input_file.rdbuf();
    
    output_file.close();
    input_file.close();
    
    // Return the path to the trimmed video
    g_autoptr(FlValue) result = fl_value_new_string(output_path.c_str());
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    
  } catch (const std::exception& e) {
    g_autofree gchar* error_msg = g_strdup_printf("Error trimming video: %s", e.what());
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "TRIM_ERROR",
        error_msg,
        nullptr));
  }
}

static void moon_native_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(moon_native_plugin_parent_class)->dispose(object);
}

static void moon_native_plugin_class_init(MoonNativePluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = moon_native_plugin_dispose;
}

static void moon_native_plugin_init(MoonNativePlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  MoonNativePlugin* plugin = MOON_NATIVE_PLUGIN(user_data);
  moon_native_plugin_handle_method_call(plugin, method_call);
}

void moon_native_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  MoonNativePlugin* plugin = MOON_NATIVE_PLUGIN(
      g_object_new(moon_native_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "moon_native",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
