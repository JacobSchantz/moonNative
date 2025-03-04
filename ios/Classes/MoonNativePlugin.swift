import Flutter
import UIKit
import Foundation

public class MoonNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "moon_native", binaryMessenger: registrar.messenger())
    let instance = MoonNativePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
      
    case "performNativeCalculation":
      guard let args = call.arguments as? [String: Any],
            let a = args["a"] as? Double,
            let b = args["b"] as? Double else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      
      // iOS-specific implementation: Multiply and add 10 (just as an example)
      let calculationResult = (a * b) + 10.0
      result(calculationResult)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
