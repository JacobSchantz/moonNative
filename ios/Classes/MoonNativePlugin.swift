import Flutter
import UIKit
import Foundation
import AVFoundation
import AudioToolbox
import CoreImage

public class MoonNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "moon_native", binaryMessenger: registrar.messenger())
    let instance = MoonNativePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    // Register video compression event channel
    VideoCompressionManager.shared.registerEventChannel(registrar: registrar)
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
        
    case "playBeep":
      // Extract optional parameters with default values
      let args = call.arguments as? [String: Any]
      let frequency = args?["frequency"] as? Int ?? 1000
      let durationMs = args?["durationMs"] as? Int ?? 200
      let volume = args?["volume"] as? Double ?? 1.0
      
      playBeep(frequency: frequency, durationMs: durationMs, volume: Float(volume)) { success, error in
        if let error = error {
          result(FlutterError(code: "BEEP_ERROR", message: error.localizedDescription, details: nil))
        } else {
          result(success)
        }
      }
      
    // Handle both method names for image compression from path
    case "compressImage", "compressImageFromPath":
      guard let args = call.arguments as? [String: Any],
            let quality = args["quality"] as? Int else {
        result(FlutterError(code: "INVALID_ARGS", message: "Quality is required for image compression", details: nil))
        return
      }
      
      let format = args["format"] as? String
      let imagePath = args["imagePath"] as? String
      let imageBytes = args["imageBytes"] as? FlutterStandardTypedData
      
      if imagePath == nil && imageBytes == nil {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments for image compression", details: nil))
        return
      }
      
      if let path = imagePath {
        compressImage(
          imagePath: path,
          quality: quality,
          format: format
        ) { outputPath, error in
          if let error = error {
            result(FlutterError(code: "COMPRESSION_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(outputPath)
          }
        }
      } else if let bytes = imageBytes {
        // Check if bytes are empty
        if bytes.data.isEmpty {
          result(FlutterError(code: "INVALID_ARGS", message: "Image bytes cannot be empty", details: nil))
          return
        }
        
        compressImageFromBytes(
          imageBytes: bytes.data,
          quality: quality,
          format: format
        ) { outputPath, error in
          if let error = error {
            result(FlutterError(code: "COMPRESSION_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(outputPath)
          }
        }
      }
      
    // Handle bytes-specific compression method
    case "compressImageFromBytes":
      guard let args = call.arguments as? [String: Any],
            let quality = args["quality"] as? Int,
            let imageBytes = args["imageBytes"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGS", message: "Quality and imageBytes are required for image compression", details: nil))
        return
      }
      
      let format = args["format"] as? String
      
      // Check if bytes are empty
      if imageBytes.data.isEmpty {
        result(FlutterError(code: "INVALID_ARGS", message: "Image bytes cannot be empty", details: nil))
        return
      }
      
      compressImageFromBytes(
        imageBytes: imageBytes.data,
        quality: quality,
        format: format
      ) { outputData, error in
        if let error = error {
          result(FlutterError(code: "COMPRESSION_ERROR", message: error.localizedDescription, details: nil))
        } else if let data = outputData {
          // Return the actual bytes data instead of a file path
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(FlutterError(code: "COMPRESSION_ERROR", message: "Failed to compress image", details: nil))
        }
      }
    
    case "enqueueVideoCompression":
      guard let args = call.arguments as? [String: Any],
            let videoPath = args["videoPath"] as? String,
            let quality = args["quality"] as? Int else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments for video compression", details: nil))
        return
      }
      
      let resolution = args["resolution"] as? String
      let bitrate = args["bitrate"] as? Int
      
      let success = VideoCompressionManager.shared.enqueueCompression(
        videoPath: videoPath,
        quality: quality,
        resolution: resolution,
        bitrate: bitrate
      )
      
      result(success)
    
    case "cancelVideoCompression":
      guard let args = call.arguments as? [String: Any],
            let compressionId = args["compressionId"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Compression ID is required", details: nil))
        return
      }
      
      let success = VideoCompressionManager.shared.cancelCompression(compressionId: compressionId)
      result(success)
      
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
  
  /// Plays a short beep sound
  /// - Parameters:
  ///   - frequency: The frequency of the beep in Hz (not used in iOS implementation - uses system sound)
  ///   - durationMs: The duration of the beep in milliseconds (not used in iOS implementation)
  ///   - volume: The volume of the beep from 0.0 to 1.0 (not used in iOS implementation)
  ///   - completion: Callback with the success status or error
  private func playBeep(frequency: Int, durationMs: Int, volume: Float, completion: @escaping (Bool, Error?) -> Void) {
    do {
      // On iOS, we'll use a system sound for the beep
      // Note: System sound 1057 is a standard beep sound on iOS
      AudioServicesPlaySystemSound(1057)
      
      // Since AudioServicesPlaySystemSound is non-blocking and has no completion callback,
      // we'll wait for the approximate duration before calling the completion handler
      DispatchQueue.main.asyncAfter(deadline: .now() + Double(durationMs) / 1000.0) {
        completion(true, nil)
      }
      
      print("Played system beep sound")
    } catch {
      print("Error playing beep: \(error.localizedDescription)")
      completion(false, error)
    }
  }
  
  /// Compresses an image file with the specified parameters
  /// - Parameters:
  ///   - imagePath: Path to the source image file
  ///   - quality: Quality of the compressed image (0-100)
  ///   - format: Output format (jpg, png, webp) (optional)
  ///   - completion: Callback with the output path or error
  private func compressImage(
    imagePath: String,
    quality: Int,
    format: String?,
    completion: @escaping (String?, Error?) -> Void
  ) {
    // Use a background queue for image processing
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        // Load the image from file
        guard let image = UIImage(contentsOfFile: imagePath) else {
          throw NSError(domain: "com.moonnative", code: 600, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
        }
        
        // Use the original image without resizing
        let processedImage = image
        
        // Determine output format
        let outputFormat: String
        if let format = format?.lowercased() {
          outputFormat = format
        } else {
          // Extract extension from the original file
          let pathExtension = URL(fileURLWithPath: imagePath).pathExtension.lowercased()
          outputFormat = (pathExtension == "png" || pathExtension == "webp") ? pathExtension : "jpg"
        }
        
        // Create a temporary file path for the output
        let outputFileName = "compressed_\(UUID().uuidString).\(outputFormat)"
        let outputPath = NSTemporaryDirectory() + outputFileName
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Convert quality from 0-100 scale to 0.0-1.0 scale
        let compressionQuality = Float(quality) / 100.0
        
        // Compress and save the image based on format
        switch outputFormat {
        case "png":
          guard let pngData = processedImage.pngData() else {
            throw NSError(domain: "com.moonnative", code: 601, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
          }
          try pngData.write(to: outputURL)
          
        case "webp":
          // iOS doesn't natively support WebP, so we'll use JPEG instead
          // and inform the user
          print("WebP format not natively supported on iOS, using JPEG instead")
          guard let jpegData = processedImage.jpegData(compressionQuality: CGFloat(compressionQuality)) else {
            throw NSError(domain: "com.moonnative", code: 602, userInfo: [NSLocalizedDescriptionKey: "Failed to create JPEG data"])
          }
          try jpegData.write(to: outputURL)
          
        case "jpg", "jpeg", _:
          guard let jpegData = processedImage.jpegData(compressionQuality: CGFloat(compressionQuality)) else {
            throw NSError(domain: "com.moonnative", code: 602, userInfo: [NSLocalizedDescriptionKey: "Failed to create JPEG data"])
          }
          try jpegData.write(to: outputURL)
        }
        
        // Return the output path on the main thread
        DispatchQueue.main.async {
          completion(outputPath, nil)
        }
      } catch {
        // Return the error on the main thread
        DispatchQueue.main.async {
          completion(nil, error)
        }
      }
    }
  }
  
  /// Compresses an image from bytes with the specified parameters
  /// - Parameters:
  ///   - imageBytes: Raw bytes of the image
  ///   - quality: Quality of the compressed image (0-100)
  ///   - format: Output format (jpg, png, webp) (optional)
  ///   - completion: Callback with the compressed image data or error
  private func compressImageFromBytes(
    imageBytes: Data,
    quality: Int,
    format: String?,
    completion: @escaping (Data?, Error?) -> Void
  ) {
    // Use a background queue for image processing
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        print("Processing image bytes of size: \(imageBytes.count)")
        
        // Load the image from bytes
        guard let image = UIImage(data: imageBytes) else {
          throw NSError(domain: "com.moonnative", code: 600, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from bytes"])
        }
        
        print("Successfully created UIImage from bytes with size: \(image.size)")
        
        // Use the original image without resizing
        let processedImage = image
        
        // Determine output format
        let outputFormat: String
        if let format = format?.lowercased() {
          outputFormat = format
        } else {
          // Default to jpg for bytes since we don't have a file extension
          outputFormat = "jpg"
        }
        
        // Convert quality from 0-100 scale to 0.0-1.0 scale
        let compressionQuality = Float(quality) / 100.0
        
        // Compress the image based on format and return the data directly
        var compressedData: Data?
        
        switch outputFormat {
        case "png":
          compressedData = processedImage.pngData()
          
        case "webp":
          // iOS doesn't natively support WebP, so we'll use JPEG instead
          print("WebP format not natively supported on iOS, using JPEG instead")
          compressedData = processedImage.jpegData(compressionQuality: CGFloat(compressionQuality))
          
        case "jpg", "jpeg", _:
          compressedData = processedImage.jpegData(compressionQuality: CGFloat(compressionQuality))
        }
        
        guard let finalData = compressedData else {
          throw NSError(domain: "com.moonnative", code: 602, userInfo: [NSLocalizedDescriptionKey: "Failed to create compressed image data"])
        }
        
        // Return the compressed data on the main thread
        DispatchQueue.main.async {
          completion(finalData, nil)
        }
      } catch {
        print("Error processing image bytes: \(error.localizedDescription)")
        // Return the error on the main thread
        DispatchQueue.main.async {
          completion(nil, error)
        }
      }
    }
  }

}
