import Flutter
import UIKit
import Foundation
import AVFoundation

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
      
    case "trimVideo":
      guard let args = call.arguments as? [String: Any],
            let videoPath = args["videoPath"] as? String,
            let startTime = args["startTime"] as? Double,
            let endTime = args["endTime"] as? Double else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments for video trimming", details: nil))
        return
      }
      
      trimVideo(videoPath: videoPath, startTime: startTime, endTime: endTime) { outputPath, error in
        if let error = error {
          result(FlutterError(code: "TRIM_ERROR", message: error.localizedDescription, details: nil))
        } else {
          result(outputPath)
        }
      }
    
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // MARK: - Video Editing Functions
  
  /// Trims a video to the specified time range
  /// - Parameters:
  ///   - videoPath: Path to the source video file
  ///   - startTime: Start time in seconds
  ///   - endTime: End time in seconds
  ///   - completion: Callback with the output path or error
  private func trimVideo(videoPath: String, startTime: Double, endTime: Double, completion: @escaping (String?, Error?) -> Void) {
    // Create asset from the input path
    let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
    
    // Create export session
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
      completion(nil, NSError(domain: "com.moonnative", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
      return
    }
    
    // Create a temporary file path for the output
    let outputPath = NSTemporaryDirectory() + UUID().uuidString + ".mp4"
    let outputURL = URL(fileURLWithPath: outputPath)
    
    // Set up export session parameters
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    
    // Set time range
    let startCMTime = CMTime(seconds: startTime, preferredTimescale: 1000)
    let endCMTime = CMTime(seconds: endTime, preferredTimescale: 1000)
    let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)
    exportSession.timeRange = timeRange
    
    // Export the file
    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        completion(outputPath, nil)
      case .failed:
        completion(nil, exportSession.error)
      case .cancelled:
        completion(nil, NSError(domain: "com.moonnative", code: 501, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
      default:
        completion(nil, NSError(domain: "com.moonnative", code: 502, userInfo: [NSLocalizedDescriptionKey: "Unknown export error"]))
      }
    }
  }
}
