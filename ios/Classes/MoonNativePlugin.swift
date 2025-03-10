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
    
    case "rotateVideo":
      guard let args = call.arguments as? [String: Any],
            let videoPath = args["videoPath"] as? String,
            let quarterTurns = args["quarterTurns"] as? Int else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments for video rotation", details: nil))
        return
      }
      
      rotateVideo(videoPath: videoPath, quarterTurns: quarterTurns) { outputPath, error in
        if let error = error {
          result(FlutterError(code: "ROTATION_ERROR", message: error.localizedDescription, details: nil))
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
  
  /// Rotates a video by the specified quarter turns
  /// - Parameters:
  ///   - videoPath: Path to the source video file
  ///   - quarterTurns: Number of 90° rotations (1=90° clockwise, 2=180°, 3=270°, -1=90° counterclockwise)
  ///   - completion: Callback with the output path or error
  private func rotateVideo(videoPath: String, quarterTurns: Int, completion: @escaping (String?, Error?) -> Void) {
    // Create asset from the input path
    let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
    
    // Check if the asset can be exported
    guard asset.isExportable else {
      completion(nil, NSError(domain: "com.moonnative", code: 504, userInfo: [NSLocalizedDescriptionKey: "Asset is not exportable"]))
      return
    }
    
    // Get video tracks
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
      completion(nil, NSError(domain: "com.moonnative", code: 503, userInfo: [NSLocalizedDescriptionKey: "No video track found"]))
      return
    }
    
    // Create a temporary file path for the output
    let outputPath = NSTemporaryDirectory() + UUID().uuidString + ".mp4"
    let outputURL = URL(fileURLWithPath: outputPath)
    
    // Calculate rotation angle in degrees
    var rotationDegrees = 0
    switch quarterTurns {
    case 1: rotationDegrees = 90
    case 2: rotationDegrees = 180
    case 3: rotationDegrees = 270
    case -1: rotationDegrees = 270
    case -2: rotationDegrees = 180
    case -3: rotationDegrees = 90
    default: rotationDegrees = 0
    }
    
    // Get natural dimensions of the video
    let naturalSize = videoTrack.naturalSize
    let isPortrait = rotationDegrees == 90 || rotationDegrees == 270
    
    // Determine the output dimensions based on rotation
    let outputWidth = isPortrait ? naturalSize.height : naturalSize.width
    let outputHeight = isPortrait ? naturalSize.width : naturalSize.height
    
    // Create a composition for the video
    let composition = AVMutableComposition()
    
    // Create a video composition track
    guard let compositionTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      completion(nil, NSError(domain: "com.moonnative", code: 505, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition track"]))
      return
    }
    
    // Try to add the video track to the composition
    do {
      let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
      try compositionTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
    } catch {
      completion(nil, error)
      return
    }
    
    // Create a video composition for the rotation
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = CGSize(width: outputWidth, height: outputHeight)
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30 fps
    videoComposition.renderScale = 1.0
    
    // Create a video instruction
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
    
    // Create a layer instruction
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
    
    // Apply the appropriate transform based on rotation degrees
    var transform = CGAffineTransform.identity
    
    if rotationDegrees == 90 {
      // 90 degrees clockwise
      transform = transform.translatedBy(x: naturalSize.height, y: 0)
      transform = transform.rotated(by: .pi / 2)
    } else if rotationDegrees == 180 {
      // 180 degrees
      transform = transform.translatedBy(x: naturalSize.width, y: naturalSize.height)
      transform = transform.rotated(by: .pi)
    } else if rotationDegrees == 270 {
      // 270 degrees clockwise (90 degrees counterclockwise)
      transform = transform.translatedBy(x: 0, y: naturalSize.width)
      transform = transform.rotated(by: -.pi / 2)
    }
    
    // Set transform
    layerInstruction.setTransform(transform, at: .zero)
    
    // Set the instruction
    instruction.layerInstructions = [layerInstruction]
    videoComposition.instructions = [instruction]
    
    // Create export session with the composition
    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
      completion(nil, NSError(domain: "com.moonnative", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
      return
    }
    
    // Configure export session
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true
    exportSession.videoComposition = videoComposition
    
    // Perform the export
    exportSession.exportAsynchronously {
      DispatchQueue.main.async {
        if exportSession.status == .completed {
          print("Video rotation successful: \(outputPath)")
          completion(outputPath, nil)
        } else {
          print("Video rotation failed with status: \(exportSession.status.rawValue), error: \(exportSession.error?.localizedDescription ?? "Unknown")")
          completion(nil, exportSession.error ?? NSError(domain: "com.moonnative", code: 502, userInfo: [NSLocalizedDescriptionKey: "Unknown export error"]))
        }
      }
    }
  }
}
