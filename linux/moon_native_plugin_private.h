#include <flutter_linux/flutter_linux.h>

#include "include/moon_native/moon_native_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// Handles the getPlatformVersion method call.
FlMethodResponse *get_platform_version();

// Handles the performNativeCalculation method call.
FlMethodResponse *perform_native_calculation(FlMethodCall* method_call);

// Handles the trimVideo method call.
FlMethodResponse *trim_video(FlMethodCall* method_call);
