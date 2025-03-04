
import 'moon_native_platform_interface.dart';

class MoonNative {
  Future<String?> getPlatformVersion() {
    return MoonNativePlatform.instance.getPlatformVersion();
  }
  
  /// Performs a calculation on the native side
  /// 
  /// Each platform implements this differently to demonstrate
  /// native code integration.
  /// 
  /// Parameters:
  ///   a - First operand
  ///   b - Second operand
  /// 
  /// Returns the result of the platform-specific calculation.
  Future<double> performNativeCalculation(double a, double b) {
    return MoonNativePlatform.instance.performNativeCalculation(a, b);
  }
}
