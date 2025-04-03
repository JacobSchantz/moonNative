import Foundation
import AVFoundation
import Flutter

/// Class to manage background video compression tasks
class VideoCompressionManager {
    static let shared = VideoCompressionManager()
    
    private var compressionTasks: [String: VideoCompressionTask] = [:]
    private var eventSink: FlutterEventSink?
    
    private init() {}
    
    /// Register the event channel for sending compression updates
    func registerEventChannel(registrar: FlutterPluginRegistrar) {
        let eventChannel = FlutterEventChannel(
            name: "moon_native/compression_events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(VideoCompressionStreamHandler())
    }
    
    /// Set the event sink for sending updates
    func setEventSink(_ sink: FlutterEventSink?) {
        self.eventSink = sink
    }
    
    /// Enqueue a video compression task
    @discardableResult
    func enqueueCompression(
        videoPath: String,
        quality: Int,
        resolution: String?,
        bitrate: Int?
    ) -> Bool {
        let compressionId = UUID().uuidString
        
        // Create a new compression task
        let task = VideoCompressionTask(
            id: compressionId,
            videoPath: videoPath,
            quality: quality,
            resolution: resolution,
            bitrate: bitrate,
            onProgress: { [weak self] progress in
                self?.sendCompressionUpdate(
                    id: compressionId,
                    status: "processing",
                    progress: progress
                )
            },
            onComplete: { [weak self] outputPath in
                self?.sendCompressionUpdate(
                    id: compressionId,
                    status: "completed",
                    progress: 1.0,
                    outputPath: outputPath
                )
                self?.compressionTasks.removeValue(forKey: compressionId)
            },
            onError: { [weak self] error in
                self?.sendCompressionUpdate(
                    id: compressionId,
                    status: "error",
                    progress: 0.0,
                    error: error.localizedDescription
                )
                self?.compressionTasks.removeValue(forKey: compressionId)
            }
        )
        
        // Store the task
        compressionTasks[compressionId] = task
        
        // Start the task
        task.start()
        
        return true
    }
    
    /// Cancel a specific compression task
    @discardableResult
    func cancelCompression(compressionId: String) -> Bool {
        guard let task = compressionTasks[compressionId] else {
            return false
        }
        
        task.cancel()
        
        // Send cancellation update
        sendCompressionUpdate(
            id: compressionId,
            status: "cancelled",
            progress: 0.0
        )
        
        // Remove the task
        compressionTasks.removeValue(forKey: compressionId)
        
        return true
    }
    
    /// Send compression update through the event channel
    private func sendCompressionUpdate(
        id: String,
        status: String,
        progress: Double,
        outputPath: String? = nil,
        error: String? = nil
    ) {
        guard let eventSink = self.eventSink else {
            print("VideoCompressionManager: No event sink available to send updates")
            return
        }
        
        var update: [String: Any] = [
            "compressionId": id,
            "status": status,
            "progress": progress
        ]
        
        if let outputPath = outputPath {
            update["outputPath"] = outputPath
        }
        
        if let error = error {
            update["error"] = error
        }
        
        print("VideoCompressionManager: Sending update - ID: \(id), Status: \(status), Progress: \(progress)")
        
        DispatchQueue.main.async {
            eventSink(update)
        }
    }
}

/// Handler for the video compression event channel
class VideoCompressionStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("VideoCompressionStreamHandler: onListen called, setting event sink")
        VideoCompressionManager.shared.setEventSink(events)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("VideoCompressionStreamHandler: onCancel called, clearing event sink")
        VideoCompressionManager.shared.setEventSink(nil)
        return nil
    }
}

/// Class representing a single video compression task
class VideoCompressionTask {
    let id: String
    let videoPath: String
    let quality: Int
    let resolution: String?
    let bitrate: Int?
    
    private var exportSession: AVAssetExportSession?
    private var progressTimer: Timer?
    private var isCancelled = false
    
    private let onProgress: (Double) -> Void
    private let onComplete: (String) -> Void
    private let onError: (Error) -> Void
    
    init(
        id: String,
        videoPath: String,
        quality: Int,
        resolution: String?,
        bitrate: Int?,
        onProgress: @escaping (Double) -> Void,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.id = id
        self.videoPath = videoPath
        self.quality = quality
        self.resolution = resolution
        self.bitrate = bitrate
        self.onProgress = onProgress
        self.onComplete = onComplete
        self.onError = onError
    }
    
    /// Start the compression task
    func start() {
        // Run the compression in a background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.compressVideo()
        }
    }
    
    /// Cancel the compression task
    func cancel() {
        isCancelled = true
        exportSession?.cancelExport()
        stopProgressTimer()
    }
    
    /// Perform the video compression
    private func compressVideo() {
        // Create asset from the input path
        let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
        
        // Generate output path
        let outputPath = generateOutputPath()
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Remove existing file at output path if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: getPresetName()) else {
            let error = NSError(domain: "com.moonnative", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
            self.onError(error)
            return
        }
        
        self.exportSession = exportSession
        
        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Apply custom settings if bitrate or resolution is specified
        if self.bitrate != nil || self.resolution != nil {
            // Apply video composition for custom resolution if needed
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                let naturalSize = getOutputResolution(for: videoTrack.naturalSize)
                
                // Only create video composition if we need to change the resolution
                if naturalSize != videoTrack.naturalSize {
                    let videoComposition = AVMutableVideoComposition()
                    videoComposition.renderSize = naturalSize
                    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                    
                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                    
                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                    
                    // Scale video to fit target resolution
                    let scaleX = naturalSize.width / videoTrack.naturalSize.width
                    let scaleY = naturalSize.height / videoTrack.naturalSize.height
                    let scale = CGAffineTransform(scaleX: scaleX, y: scaleY)
                    layerInstruction.setTransform(scale, at: .zero)
                    
                    instruction.layerInstructions = [layerInstruction]
                    videoComposition.instructions = [instruction]
                    
                    exportSession.videoComposition = videoComposition
                }
            }
            
            // Choose appropriate preset based on quality and resolution
            // We'll use the preset selection logic which already handles quality
            // For bitrate control, we'll rely on the quality preset approximations
            // since we can't directly set the bitrate on AVAssetExportSession
        }
        
        // Start progress timer
        startProgressTimer()
        
        // Export the file
        exportSession.exportAsynchronously { [weak self] in
            guard let self = self else { return }
            
            self.stopProgressTimer()
            
            if self.isCancelled {
                return
            }
            
            switch exportSession.status {
            case .completed:
                self.onComplete(outputPath)
            case .failed:
                if let error = exportSession.error {
                    self.onError(error)
                } else {
                    let error = NSError(domain: "com.moonnative", code: 501, userInfo: [NSLocalizedDescriptionKey: "Export failed with no error"])
                    self.onError(error)
                }
            case .cancelled:
                return // Already handled by cancel()
            default:
                let error = NSError(domain: "com.moonnative", code: 502, userInfo: [NSLocalizedDescriptionKey: "Unknown export error"])
                self.onError(error)
            }
        }
    }
    
    /// Start timer to track and report progress
    private func startProgressTimer() {
        stopProgressTimer()
        print("VideoCompressionTask: Starting progress timer for task ID: \(id)")
        
        DispatchQueue.main.async { [weak self] in
            self?.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                guard let progress = self.exportSession?.progress else {
                    print("VideoCompressionTask: No progress available yet for task ID: \(self.id)")
                    return
                }
                
                print("VideoCompressionTask: Progress update for task ID: \(self.id) - Progress: \(progress)")
                self.onProgress(Double(progress))
            }
        }
    }
    
    /// Stop the progress timer
    private func stopProgressTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.progressTimer?.invalidate()
            self?.progressTimer = nil
        }
    }
    
    /// Generate a unique output path for the compressed video
    private func generateOutputPath() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let outputFilename = "compressed_\(id).mp4"
        return "\(documentsPath)/\(outputFilename)"
    }
    
    /// Get the appropriate preset name based on quality and resolution
    private func getPresetName() -> String {
        // If a specific resolution is requested, use that preset if available
        if let resolution = self.resolution {
            switch resolution {
            case "1080p":
                return AVAssetExportPreset1920x1080
            case "720p":
                return AVAssetExportPreset1280x720
            case "480p":
                return AVAssetExportPreset640x480
            case "360p":
                return AVAssetExportPreset640x480 // iOS doesn't have a 360p preset, use 480p
            default:
                break
            }
        }
        
        // If no resolution specified or not recognized, use quality-based preset
        if quality >= 80 {
            return AVAssetExportPresetHighestQuality
        } else if quality >= 60 {
            return AVAssetExportPresetMediumQuality
        } else {
            return AVAssetExportPresetLowQuality
        }
    }
    
    /// Get the output resolution based on resolution parameter
    private func getOutputResolution(for originalSize: CGSize) -> CGSize {
        guard let resolution = self.resolution else {
            return originalSize
        }
        
        // Parse the resolution string (e.g., "720p", "1080p")
        if resolution == "1080p" {
            return CGSize(width: 1920, height: 1080)
        } else if resolution == "720p" {
            return CGSize(width: 1280, height: 720)
        } else if resolution == "480p" {
            return CGSize(width: 854, height: 480)
        } else if resolution == "360p" {
            return CGSize(width: 640, height: 360)
        }
        
        // Default to original size if resolution not recognized
        return originalSize
    }
}

// Extension to simplify initialization with closures
extension AVMutableVideoComposition {
    func apply(closure: (AVMutableVideoComposition) -> Void) -> AVMutableVideoComposition {
        closure(self)
        return self
    }
}
