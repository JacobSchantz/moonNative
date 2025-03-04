import Cocoa
import FlutterMacOS
import Foundation

public class MoonNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "moon_native", binaryMessenger: registrar.messenger)
    let instance = MoonNativePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
      
    case "performNativeCalculation":
      guard let args = call.arguments as? [String: Any],
            let a = args["a"] as? Double,
            let b = args["b"] as? Double else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      
      // macOS-specific implementation: Average and multiply by core count
      let coreCount = Double(ProcessInfo.processInfo.processorCount)
      let calculationResult = ((a + b) / 2.0) * coreCount
      result(calculationResult)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
