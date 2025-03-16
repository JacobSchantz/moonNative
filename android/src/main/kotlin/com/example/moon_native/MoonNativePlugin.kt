package com.example.moon_native

import androidx.annotation.NonNull
import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaCodec
import android.media.ToneGenerator
import android.media.AudioManager
import android.net.Uri
import android.util.Log
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.util.UUID
import kotlinx.coroutines.*

/** MoonNativePlugin */
class MoonNativePlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context : Context

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "moon_native")
    context = flutterPluginBinding.applicationContext
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "trimVideo" -> {
        val videoPath = call.argument<String>("videoPath")
        val startTime = call.argument<Double>("startTime")
        val endTime = call.argument<Double>("endTime")
        
        if (videoPath == null || startTime == null || endTime == null) {
          result.error("INVALID_ARGS", "Video path, start time, and end time are required", null)
          return
        }
        
        trimVideo(videoPath, startTime, endTime, result)
      }
      "rotateVideo" -> {
        val videoPath = call.argument<String>("videoPath")
        val quarterTurns = call.argument<Int>("quarterTurns")
        
        if (videoPath == null || quarterTurns == null) {
          result.error("INVALID_ARGS", "Video path and quarter turns are required", null)
          return
        }
        
        rotateVideo(videoPath, quarterTurns, result)
      }
      "playBeep" -> {
        val frequency = call.argument<Int>("frequency") ?: 1000
        val durationMs = call.argument<Int>("durationMs") ?: 200
        val volume = call.argument<Double>("volume") ?: 1.0
        
        playBeep(frequency, durationMs, volume.toFloat(), result)
      }
      // Handle both method names for image compression from path
      "compressImage", "compressImageFromPath" -> {
        val imagePath = call.argument<String>("imagePath")
        val imageBytes = call.argument<ByteArray>("imageBytes")
        val quality = call.argument<Int>("quality")
        val format = call.argument<String>("format")
        
        if (quality == null) {
          result.error("INVALID_ARGS", "Quality is required", null)
          return
        }
        
        if (imagePath == null && imageBytes == null) {
          result.error("INVALID_ARGS", "Invalid arguments for image compression", null)
          return
        }
        
        try {
          if (imagePath != null) {
            compressImage(imagePath, quality, format, result)
          } else if (imageBytes != null) {
            // Check if bytes are empty
            if (imageBytes.isEmpty()) {
              result.error("INVALID_ARGS", "Image bytes cannot be empty", null)
              return
            }
            compressImageFromBytes(imageBytes, quality, format, result)
          }
        } catch (e: Exception) {
          Log.e("MoonNative", "Error in compressImage: ${e.message}")
          e.printStackTrace()
          result.error("COMPRESSION_ERROR", "Error compressing image: ${e.message}", null)
        }
      }
      
      // Handle bytes-specific compression method
      "compressImageFromBytes" -> {
        val imageBytes = call.argument<ByteArray>("imageBytes")
        val quality = call.argument<Int>("quality")
        val format = call.argument<String>("format")
        
        if (quality == null || imageBytes == null) {
          result.error("INVALID_ARGS", "Quality and imageBytes are required", null)
          return
        }
        
        // Check if bytes are empty
        if (imageBytes.isEmpty()) {
          result.error("INVALID_ARGS", "Image bytes cannot be empty", null)
          return
        }
        
        try {
          compressImageFromBytes(imageBytes, quality, format, result)
        } catch (e: Exception) {
          Log.e("MoonNative", "Error in compressImageFromBytes: ${e.message}")
          e.printStackTrace()
          result.error("COMPRESSION_ERROR", "Error compressing image: ${e.message}", null)
        }
      }
      else -> {
        result.notImplemented()
      }
    }
  }
  
  private fun trimVideo(videoPath: String, startTime: Double, endTime: Double, result: Result) {
    CoroutineScope(Dispatchers.IO).launch {
      try {
        // Log operation start
        Log.d("MoonNative", "Starting video trim from $startTime to $endTime seconds")
        Log.d("MoonNative", "Input: $videoPath")
        
        // Create output file with unique name
        val outputDir = context.cacheDir
        val outputFileName = "trimmed_${UUID.randomUUID()}.mp4"
        val outputFile = File(outputDir, outputFileName)
        val outputPath = outputFile.absolutePath
        Log.d("MoonNative", "Output: $outputPath")
        
        // Convert time to microseconds
        val startTimeUs = (startTime * 1_000_000).toLong()
        val endTimeUs = (endTime * 1_000_000).toLong()
        
        // Use MediaMetadataRetriever to get video information
        val retriever = MediaMetadataRetriever().apply {
          setDataSource(videoPath)
        }
        
        // Get original rotation to preserve it
        val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
        
        // Get video duration to validate trim points
        val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
        val durationUs = durationMs * 1000
        
        // Validate trim points
        if (startTimeUs < 0 || endTimeUs > durationUs || startTimeUs >= endTimeUs) {
          throw IllegalArgumentException("Invalid trim points: start=$startTimeUs, end=$endTimeUs, duration=$durationUs")
        }
        
        // Setup MediaExtractor
        val extractor = MediaExtractor().apply {
          setDataSource(videoPath)
        }
        
        // Setup MediaMuxer with appropriate format
        // Android 15 supports more output formats, but MP4 is still the most compatible
        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4).apply {
          setOrientationHint(rotation)
        }
        
        // Track mapping between extractor and muxer
        val trackMap = HashMap<Int, Int>()
        
        // First pass: setup all tracks
        for (trackIndex in 0 until extractor.trackCount) {
          // Get track format
          val format = extractor.getTrackFormat(trackIndex)
          val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
          
          // Add track to muxer and store mapping
          val muxerTrackIndex = muxer.addTrack(format)
          trackMap[trackIndex] = muxerTrackIndex
          
          Log.d("MoonNative", "Added track: $mime")
        }
        
        // Start muxer
        muxer.start()
        
        // Allocate a reasonably sized buffer
        val bufferSize = 1024 * 1024 // 1MB
        val buffer = ByteBuffer.allocateDirect(bufferSize) // Direct buffer for better performance
        val bufferInfo = MediaCodec.BufferInfo()
        
        // Second pass: process each track
        for (trackIndex in 0 until extractor.trackCount) {
          if (!trackMap.containsKey(trackIndex)) continue
          
          // Select this track
          extractor.selectTrack(trackIndex)
          
          // Determine if this is a video track
          val format = extractor.getTrackFormat(trackIndex)
          val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
          val isVideoTrack = mime.startsWith("video/")
          
          // Choose appropriate seek mode based on track type
          val seekMode = if (isVideoTrack) {
            MediaExtractor.SEEK_TO_PREVIOUS_SYNC
          } else {
            MediaExtractor.SEEK_TO_CLOSEST_SYNC
          }
          
          // Seek to start position
          extractor.seekTo(startTimeUs, seekMode)
          
          // Variables for processing
          var firstSampleTimeUs = -1L
          var sawKeyframe = !isVideoTrack // Only need keyframe for video tracks
          
          // Process frames until we reach the end time
          var continueProcessing = true
          while (continueProcessing) {
            // Check if we should yield to other coroutines occasionally
            yield()
            
            // Clear buffer for reuse
            buffer.clear()
            
            // Read a sample
            val sampleSize = extractor.readSampleData(buffer, 0)
            val sampleTimeUs = extractor.sampleTime
            val sampleFlags = extractor.sampleFlags
            
            // Check if we're done with this track
            if (sampleSize < 0 || sampleTimeUs > endTimeUs) {
              extractor.unselectTrack(trackIndex)
              continueProcessing = false
              continue
            }
            
            // For video tracks, ensure we start with a keyframe
            if (isVideoTrack && !sawKeyframe) {
              if ((sampleFlags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0) {
                sawKeyframe = true
                Log.d("MoonNative", "Found keyframe at ${sampleTimeUs / 1_000_000.0}s")
              } else {
                // Skip non-keyframes at the beginning
                extractor.advance()
                continue
              }
            }
            
            // Set first sample time if not set
            if (firstSampleTimeUs < 0) {
              firstSampleTimeUs = sampleTimeUs
            }
            
            // Prepare buffer info
            bufferInfo.apply {
              size = sampleSize
              offset = 0
              flags = sampleFlags
              presentationTimeUs = sampleTimeUs - firstSampleTimeUs
            }
            
            // Write sample to muxer
            muxer.writeSampleData(trackMap[trackIndex]!!, buffer, bufferInfo)
            
            // Move to next sample
            extractor.advance()
          }
        }
        
        // Cleanup resources
        muxer.stop()
        muxer.release()
        extractor.release()
        retriever.release()
        
        Log.d("MoonNative", "Video trimming completed successfully")
        
        // Return result on main thread
        withContext(Dispatchers.Main) {
          result.success(outputPath)
        }
      } catch (e: Exception) {
        Log.e("MoonNative", "Error trimming video", e)
        
        // Return error on main thread
        withContext(Dispatchers.Main) {
          result.error("TRIM_ERROR", "Error trimming video: ${e.message}", null)
        }
      }
    }
  }

  private fun rotateVideo(videoPath: String, quarterTurns: Int, result: Result) {
    CoroutineScope(Dispatchers.IO).launch {
      try {
        // Log operation start
        Log.d("MoonNative", "Starting video rotation by $quarterTurns quarter turns")
        Log.d("MoonNative", "Input: $videoPath")
        
        // Create output file with unique name
        val outputDir = context.cacheDir
        val outputFileName = "rotated_${UUID.randomUUID()}.mp4"
        val outputFile = File(outputDir, outputFileName)
        val outputPath = outputFile.absolutePath
        Log.d("MoonNative", "Output: $outputPath")
        
        // Use MediaMetadataRetriever to get video information
        val retriever = MediaMetadataRetriever().apply {
          setDataSource(videoPath)
        }
        
        // Calculate final rotation
        val originalRotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
        val rotationDegrees = quarterTurns * 90
        val finalRotation = (originalRotation + rotationDegrees) % 360
        Log.d("MoonNative", "Original rotation: $originalRotation, Adding: $rotationDegrees, Final: $finalRotation")
        
        // Setup MediaExtractor
        val extractor = MediaExtractor().apply {
          setDataSource(videoPath)
        }
        
        // Setup MediaMuxer with appropriate format
        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4).apply {
          setOrientationHint(finalRotation)
        }
        
        // Track mapping between extractor and muxer
        val trackMap = HashMap<Int, Int>()
        
        // First pass: setup all tracks
        for (trackIndex in 0 until extractor.trackCount) {
          // Get track format
          val format = extractor.getTrackFormat(trackIndex)
          val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
          
          // Add track to muxer and store mapping
          val muxerTrackIndex = muxer.addTrack(format)
          trackMap[trackIndex] = muxerTrackIndex
          
          Log.d("MoonNative", "Added track: $mime")
        }
        
        // Start muxer
        muxer.start()
        
        // Allocate a reasonably sized buffer
        val bufferSize = 1024 * 1024 // 1MB
        val buffer = ByteBuffer.allocateDirect(bufferSize) // Direct buffer for better performance
        val bufferInfo = MediaCodec.BufferInfo()
        
        // Second pass: process each track
        for (trackIndex in 0 until extractor.trackCount) {
          if (!trackMap.containsKey(trackIndex)) continue
          
          // Select this track
          extractor.selectTrack(trackIndex)
          
          // Process frames
          var continueProcessing = true
          while (continueProcessing) {
            // Check if we should yield to other coroutines occasionally
            yield()
            
            // Clear buffer for reuse
            buffer.clear()
            
            // Read a sample
            val sampleSize = extractor.readSampleData(buffer, 0)
            
            // Check if we're done with this track
            if (sampleSize < 0) {
              extractor.unselectTrack(trackIndex)
              continueProcessing = false
              continue
            }
            
            // Prepare buffer info
            bufferInfo.apply {
              size = sampleSize
              offset = 0
              flags = extractor.sampleFlags
              presentationTimeUs = extractor.sampleTime
            }
            
            // Write sample to muxer
            muxer.writeSampleData(trackMap[trackIndex]!!, buffer, bufferInfo)
            
            // Move to next sample
            extractor.advance()
          }
        }
        
        // Cleanup resources
        muxer.stop()
        muxer.release()
        extractor.release()
        retriever.release()
        
        Log.d("MoonNative", "Video rotation completed successfully")
        
        // Return result on main thread
        withContext(Dispatchers.Main) {
          result.success(outputPath)
        }
      } catch (e: Exception) {
        Log.e("MoonNative", "Error rotating video", e)
        
        // Return error on main thread
        withContext(Dispatchers.Main) {
          result.error("ROTATION_ERROR", "Error rotating video: ${e.message}", null)
        }
      }
    }
  }

  private fun playBeep(frequency: Int, durationMs: Int, volume: Float, result: Result) {
    try {
      val toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, (volume * 100).toInt())
      toneGenerator.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, durationMs)
      
      // Schedule tone stop and release
      Handler(Looper.getMainLooper()).postDelayed({
        toneGenerator.stopTone()
        toneGenerator.release()
        result.success(true)
      }, durationMs.toLong())
    } catch (e: Exception) {
      Log.e("MoonNative", "Error playing beep: ${e.message}")
      e.printStackTrace()
      result.error("BEEP_ERROR", "Error playing beep: ${e.message}", null)
    }
  }

  private fun compressImage(imagePath: String, quality: Int, format: String?, result: Result) {
    try {
      // Load bitmap from file
      val originalBitmap = BitmapFactory.decodeFile(imagePath)
      if (originalBitmap == null) {
        result.error("INVALID_IMAGE", "Could not decode image from path", null)
        return
      }
      
      // Compress to bytes
      val outputStream = ByteArrayOutputStream()
      val compressFormat = when (format?.lowercase()) {
        "png" -> Bitmap.CompressFormat.PNG
        "webp" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Bitmap.CompressFormat.WEBP_LOSSY else Bitmap.CompressFormat.WEBP
        else -> Bitmap.CompressFormat.JPEG
      }
      
      originalBitmap.compress(compressFormat, quality, outputStream)
      val compressedBytes = outputStream.toByteArray()
      
      // Clean up
      outputStream.close()
      originalBitmap.recycle()
      
      result.success(compressedBytes)
    } catch (e: Exception) {
      Log.e("MoonNative", "Error compressing image: ${e.message}")
      e.printStackTrace()
      result.error("COMPRESSION_ERROR", "Error compressing image: ${e.message}", null)
    }
  }

  private fun compressImageFromBytes(imageBytes: ByteArray, quality: Int, format: String?, result: Result) {
    try {
      // Load bitmap from bytes
      val originalBitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
      if (originalBitmap == null) {
        result.error("INVALID_IMAGE", "Could not decode image from bytes", null)
        return
      }
      
      // Compress to bytes
      val outputStream = ByteArrayOutputStream()
      val compressFormat = when (format?.lowercase()) {
        "png" -> Bitmap.CompressFormat.PNG
        "webp" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Bitmap.CompressFormat.WEBP_LOSSY else Bitmap.CompressFormat.WEBP
        else -> Bitmap.CompressFormat.JPEG
      }
      
      originalBitmap.compress(compressFormat, quality, outputStream)
      val compressedBytes = outputStream.toByteArray()
      
      // Clean up
      outputStream.close()
      originalBitmap.recycle()
      
      result.success(compressedBytes)
    } catch (e: Exception) {
      Log.e("MoonNative", "Error compressing image: ${e.message}")
      e.printStackTrace()
      result.error("COMPRESSION_ERROR", "Error compressing image: ${e.message}", null)
    }
  }

  // Helper method to find video track
  private fun findVideoTrack(extractor: MediaExtractor): Int {
    for (i in 0 until extractor.trackCount) {
      val format = extractor.getTrackFormat(i)
      val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
      
      if (mime.startsWith("video/")) {
        return i
      }
    }
    return -1
  }
}
