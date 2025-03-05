import Cocoa
import FlutterMacOS
import Foundation
import AVFoundation

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

    case "getVideoDuration":
      guard let args = call.arguments as? [String: Any],
            let videoPath = args["videoPath"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments for getting video duration", details: nil))
        return
      }
      
      getVideoDuration(videoPath: videoPath) { duration, error in
        if let error = error {
          result(FlutterError(code: "DURATION_ERROR", message: error.localizedDescription, details: nil))
        } else {
          result(duration)
        }
      }
      
    case "downloadVideo":
      guard let args = call.arguments as? [String: Any],
            let url = args["url"] as? String,
            let localPath = args["localPath"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments for downloading video", details: nil))
        return
      }
      
      downloadVideo(url: url, localPath: localPath) { outputPath, error in
        if let error = error {
          result(FlutterError(code: "DOWNLOAD_ERROR", message: error.localizedDescription, details: nil))
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
  private func getVideoDuration(videoPath: String, completion: @escaping (Double?, Error?) -> Void) {
    // Create asset from the input path
    let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
    
    // Load duration synchronously
    let duration = CMTimeGetSeconds(asset.duration)
    completion(duration, nil)
  }
  
  private func downloadVideo(url: String, localPath: String, completion: @escaping (String?, Error?) -> Void) {
    guard let videoURL = URL(string: url) else {
      completion(nil, NSError(domain: "com.moonnative", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
      return
    }
    
    let downloadTask = URLSession.shared.downloadTask(with: videoURL) { tempURL, response, error in
      if let error = error {
        DispatchQueue.main.async {
          completion(nil, error)
        }
        return
      }
      
      guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let error = NSError(domain: "com.moonnative", code: statusCode, 
                           userInfo: [NSLocalizedDescriptionKey: "HTTP error with status: \(statusCode)"])
        DispatchQueue.main.async {
          completion(nil, error)
        }
        return
      }
      
      guard let tempURL = tempURL else {
        DispatchQueue.main.async {
          completion(nil, NSError(domain: "com.moonnative", code: 500, 
                                userInfo: [NSLocalizedDescriptionKey: "No data received"]))
        }
        return
      }
      
      let fileManager = FileManager.default
      let destinationURL = URL(fileURLWithPath: localPath)
      
      do {
        // Remove existing file if it exists
        if fileManager.fileExists(atPath: destinationURL.path) {
          try fileManager.removeItem(at: destinationURL)
        }
        
        // Move downloaded file to destination
        try fileManager.moveItem(at: tempURL, to: destinationURL)
        
        DispatchQueue.main.async {
          completion(localPath, nil)
        }
      } catch {
        DispatchQueue.main.async {
          completion(nil, error)
        }
      }
    }
    
    downloadTask.resume()
  }
  
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
