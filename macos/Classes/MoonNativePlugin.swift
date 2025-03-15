import Cocoa
import FlutterMacOS
import Foundation
import AVFoundation
import CoreImage
import CoreGraphics

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
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)),
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
          throw NSError(domain: "com.moonnative", code: 600, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
        }
        
        // Create NSImage from CGImage
        let originalImage = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        
        // Process the image
        self.processAndSaveImage(image: originalImage, quality: quality, format: format, sourcePathExtension: URL(fileURLWithPath: imagePath).pathExtension.lowercased(), completion: completion)
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
        guard let imageSource = CGImageSourceCreateWithData(imageBytes as CFData, nil) else {
          throw NSError(domain: "com.moonnative", code: 600, userInfo: [NSLocalizedDescriptionKey: "Failed to create image source from bytes"])
        }
        
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
          throw NSError(domain: "com.moonnative", code: 601, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from bytes"])
        }
        
        // Create NSImage from CGImage
        let originalImage = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        print("Successfully created NSImage from bytes with size: \(originalImage.size)")
        
        // Determine output format
        let outputFormat: String
        if let format = format?.lowercased() {
          outputFormat = format
        } else {
          // Default to jpg for bytes
          outputFormat = "jpg"
        }
        
        // Convert quality from 0-100 scale to 0.0-1.0 scale
        let compressionQuality = Float(quality) / 100.0
        
        // Convert NSImage to CGImage
        guard let cgImageRepresentation = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
          throw NSError(domain: "com.moonnative", code: 601, userInfo: [NSLocalizedDescriptionKey: "Failed to convert NSImage to CGImage"])
        }
        
        // Create a bitmap representation
        let bitmapRep = NSBitmapImageRep(cgImage: cgImageRepresentation)
        
        // Compress the image based on format
        var compressedData: Data?
        switch outputFormat {
        case "png":
          compressedData = bitmapRep.representation(using: .png, properties: [:])
        case "webp":
          // macOS doesn't natively support WebP, so we'll use JPEG instead
          print("WebP format not natively supported on macOS, using JPEG instead")
          compressedData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: compressionQuality)])
        case "jpg", "jpeg", _:
          compressedData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: compressionQuality)])
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
  
  /// Processes and saves an image with the specified parameters
  /// - Parameters:
  ///   - image: The NSImage to process
  ///   - quality: Quality of the compressed image (0-100)
  ///   - format: Output format (jpg, png, webp) (optional)
  ///   - sourcePathExtension: The file extension of the source image
  ///   - completion: Callback with the output path or error
  private func processAndSaveImage(
    image: NSImage,
    quality: Int,
    format: String?,
    sourcePathExtension: String,
    completion: @escaping (String?, Error?) -> Void
  ) {
    do {
      // Use the original image without resizing
      let processedImage = image
      
      // Determine output format
      let outputFormat: String
      if let format = format?.lowercased() {
        outputFormat = format
      } else {
        // Use source extension or default to jpg
        outputFormat = (sourcePathExtension == "png" || sourcePathExtension == "webp") ? sourcePathExtension : "jpg"
      }
      
      // Create a temporary file path for the output
      let outputFileName = "compressed_\(UUID().uuidString).\(outputFormat)"
      let outputPath = NSTemporaryDirectory() + outputFileName
      let outputURL = URL(fileURLWithPath: outputPath)
      
      // Convert quality from 0-100 scale to 0.0-1.0 scale
      let compressionQuality = Float(quality) / 100.0
      
      // Convert NSImage to CGImage
      guard let cgImageRepresentation = processedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "com.moonnative", code: 601, userInfo: [NSLocalizedDescriptionKey: "Failed to convert NSImage to CGImage"])
      }
      
      // Compress and save the image based on format
      switch outputFormat {
      case "png":
        // Create a bitmap representation
        let bitmapRep = NSBitmapImageRep(cgImage: cgImageRepresentation)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
          throw NSError(domain: "com.moonnative", code: 602, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
        }
        try pngData.write(to: outputURL)
        
      case "webp":
        // macOS doesn't natively support WebP, so we'll use JPEG instead
        // and inform the user
        print("WebP format not natively supported on macOS, using JPEG instead")
        let bitmapRep = NSBitmapImageRep(cgImage: cgImageRepresentation)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: compressionQuality)]) else {
          throw NSError(domain: "com.moonnative", code: 603, userInfo: [NSLocalizedDescriptionKey: "Failed to create JPEG data"])
        }
        try jpegData.write(to: outputURL)
        
      case "jpg", "jpeg", _:
        let bitmapRep = NSBitmapImageRep(cgImage: cgImageRepresentation)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: compressionQuality)]) else {
          throw NSError(domain: "com.moonnative", code: 603, userInfo: [NSLocalizedDescriptionKey: "Failed to create JPEG data"])
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
  
  /// Resizes an image to fit within the specified dimensions while maintaining aspect ratio
  /// - Parameters:
  ///   - image: The input NSImage
  ///   - maxWidth: Maximum width constraint
  ///   - maxHeight: Maximum height constraint
  /// - Returns: The resized NSImage
  private func resizeImage(_ image: NSImage, maxWidth: Int, maxHeight: Int) -> NSImage {
    let originalSize = image.size
    
    // Calculate the scaling factors
    let widthRatio = CGFloat(maxWidth) / originalSize.width
    let heightRatio = CGFloat(maxHeight) / originalSize.height
    
    // Use the smaller ratio to ensure the image fits within the constraints
    let scaleFactor = min(widthRatio, heightRatio)
    
    // Only scale down, not up
    if scaleFactor >= 1.0 {
      return image
    }
    
    // Calculate new size
    let newWidth = originalSize.width * scaleFactor
    let newHeight = originalSize.height * scaleFactor
    let newSize = NSSize(width: newWidth, height: newHeight)
    
    // Create a new image with the calculated size
    let resizedImage = NSImage(size: newSize)
    
    resizedImage.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1.0)
    resizedImage.unlockFocus()
    
    return resizedImage
  }
}
