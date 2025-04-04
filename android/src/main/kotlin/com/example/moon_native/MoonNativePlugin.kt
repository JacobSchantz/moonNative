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
import android.view.WindowInsets
import android.view.WindowManager
import android.provider.Settings
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
  
  // Define our own constant for navigation mode setting
  private companion object {
    const val NAVIGATION_MODE = "navigation_mode"
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "moon_native")
    context = flutterPluginBinding.applicationContext
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "trimVideo" -> {
        val videoPath = call.argument<String>("videoPath")
        val startTime = call.argument<Double>("startTime")
        val endTime = call.argument<Double>("endTime")
        
        if (videoPath == null || startTime == null || endTime == null) {
          result.error("INVALID_ARGS", "Missing required arguments", null)
          return
        }
        
        trimVideo(videoPath, startTime, endTime, result)
      }
      "rotateVideo" -> {
        val videoPath = call.argument<String>("videoPath")
        val quarterTurns = call.argument<Int>("quarterTurns")
        
        if (videoPath == null || quarterTurns == null) {
          result.error("INVALID_ARGS", "Missing required arguments", null)
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
      "getNavigationMode" -> {
        getNavigationMode(result)
      }
      "getRingerMode" -> {
        getRingerMode(result)
      }
      "compressImage" -> {
        try {
          val imagePath = call.argument<String>("imagePath")
          val quality = call.argument<Int>("quality") ?: 80
          val format = call.argument<String>("format")
          
          Log.d("MoonNative", "compressImage called with path: $imagePath, quality: $quality, format: $format")
          
          if (imagePath == null) {
            result.error("INVALID_ARGS", "Image path is required", null)
            return
          }
          
          // Verify the file exists
          val inputFile = File(imagePath)
          if (!inputFile.exists()) {
            result.error("INVALID_ARGS", "Image file does not exist: $imagePath", null)
            return
          }
          
          Log.d("MoonNative", "Input file exists: ${inputFile.length()} bytes")
          
          // Create output file
          val outputDir = context.cacheDir
          val outputFormat = format?.lowercase() ?: "jpg"
          val outputFileName = "compressed_${System.currentTimeMillis()}.$outputFormat"
          val outputFile = File(outputDir, outputFileName)
          val outputPath = outputFile.absolutePath
          
          // Determine compression format
          val compressFormat = when (outputFormat) {
            "png" -> Bitmap.CompressFormat.PNG
            "webp" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Bitmap.CompressFormat.WEBP_LOSSY else Bitmap.CompressFormat.WEBP
            else -> Bitmap.CompressFormat.JPEG
          }
          
          // Load and compress in a background thread
          Thread {
            try {
              // Load bitmap
              val bitmap = BitmapFactory.decodeFile(imagePath)
              if (bitmap == null) {
                android.os.Handler(Looper.getMainLooper()).post {
                  result.error("COMPRESSION_ERROR", "Failed to decode image file", null)
                }
                return@Thread
              }
              
              // Compress to file
              FileOutputStream(outputFile).use { out ->
                bitmap.compress(compressFormat, quality, out)
                out.flush()
              }
              
              // Verify output
              if (!outputFile.exists() || outputFile.length() == 0L) {
                android.os.Handler(Looper.getMainLooper()).post {
                  result.error("COMPRESSION_ERROR", "Failed to create output file", null)
                }
                return@Thread
              }
              
              // Clean up
              bitmap.recycle()
              
              // Return the path
              android.os.Handler(Looper.getMainLooper()).post {
                Log.d("MoonNative", "Compression successful, returning path: $outputPath")
                result.success(outputPath)
              }
            } catch (e: Exception) {
              Log.e("MoonNative", "Error in compression thread: ${e.message}")
              e.printStackTrace()
              android.os.Handler(Looper.getMainLooper()).post {
                result.error("COMPRESSION_ERROR", "Error compressing image: ${e.message}", null)
              }
            }
          }.start()
        } catch (e: Exception) {
          Log.e("MoonNative", "Error in compressImage: ${e.message}")
          e.printStackTrace()
          result.error("COMPRESSION_ERROR", "Error compressing image: ${e.message}", null)
        }
      }
      "compressImageFromBytes" -> {
        val imageBytes = call.argument<ByteArray>("imageBytes")
        val quality = call.argument<Int>("quality")
        val format = call.argument<String>("format")
        
        Log.d("MoonNative", "Method call received: ${call.method}")
        Log.d("MoonNative", "Arguments: imageBytes=${imageBytes != null}, quality=$quality, format=$format")
        
        if (imageBytes == null) {
          result.error("INVALID_ARGS", "Image bytes are required", null)
          return
        }
        
        if (quality == null) {
          result.error("INVALID_ARGS", "Quality is required", null)
          return
        }
        
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

  private fun compressImageFromBytes(
    imageBytes: ByteArray,
    quality: Int,
    format: String?,
    result: Result
  ) {
    Thread(Runnable {
      try {
        Log.d("MoonNative", "Processing image bytes of size: ${imageBytes.size}")
        
        // Save bytes to a temporary file for debugging
        try {
          val tempFile = File(context.cacheDir, "temp_image_${System.currentTimeMillis()}.jpg")
          tempFile.outputStream().use { it.write(imageBytes) }
          Log.d("MoonNative", "Saved image bytes to temporary file: ${tempFile.absolutePath}")
        } catch (e: Exception) {
          Log.e("MoonNative", "Failed to save debug file: ${e.message}")
        }
        
        // Set options for decoding the bitmap to ensure proper orientation and format
        val options = BitmapFactory.Options().apply {
          inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        
        // Load the bitmap from bytes
        val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, options)
        if (bitmap == null) {
          throw Exception("Failed to decode image bytes")
        }
        
        Log.d("MoonNative", "Successfully created Bitmap from bytes with size: ${bitmap.width}x${bitmap.height}")
        
        // Compress to bytes
        val outputStream = ByteArrayOutputStream()
        val compressFormat = when (format?.lowercase()) {
          "png" -> Bitmap.CompressFormat.PNG
          "webp" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Bitmap.CompressFormat.WEBP_LOSSY else Bitmap.CompressFormat.WEBP
          else -> Bitmap.CompressFormat.JPEG
        }
        
        bitmap.compress(compressFormat, quality, outputStream)
        val compressedBytes = outputStream.toByteArray()
        
        // Clean up
        outputStream.close()
        bitmap.recycle()
        
        Log.d("MoonNative", "Image compression completed successfully, compressed size: ${compressedBytes.size} bytes")
        android.os.Handler(android.os.Looper.getMainLooper()).post {
          // Return the byte array directly - Flutter will handle it as Uint8List
          result.success(compressedBytes)
        }
      } catch (e: Exception) {
        Log.e("MoonNative", "Error compressing image from bytes: ${e.message}")
        e.printStackTrace()
        android.os.Handler(android.os.Looper.getMainLooper()).post {
          result.error("COMPRESSION_ERROR", "Error compressing image from bytes: ${e.message}", null)
        }
      }
    }).start()
  }

  private fun getNavigationMode(result: Result) {
    try {
      // Different ways to check navigation mode depending on Android version
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        // For Android 10 (API 29) and above, we can check system settings
        val navigationMode = Settings.Secure.getInt(
          context.contentResolver,
          NAVIGATION_MODE,
          0
        )
        
        // Navigation modes:
        // 0 = 3-button navigation (back, home, recents)
        // 1 = 2-button navigation (back gesture, home pill)
        // 2 = Gesture navigation (all gestures)
        
        val isGestureMode = when (navigationMode) {
          0 -> false // 3-button navigation
          1 -> true  // 2-button navigation (has back gesture)
          2 -> true  // Full gesture navigation
          else -> false // Default to false for unknown values
        }
        
        Log.d("MoonNative", "Navigation mode detected: $navigationMode (isGesture: $isGestureMode)")
        result.success(mapOf(
          "isGestureNavigation" to isGestureMode,
          "navigationMode" to navigationMode
        ))
      } else {
        // For older Android versions, we can only guess based on device model or assume button navigation
        // Most devices before Android 10 used button navigation by default
        Log.d("MoonNative", "Device running Android ${Build.VERSION.SDK_INT}, assuming button navigation")
        result.success(mapOf(
          "isGestureNavigation" to false,
          "navigationMode" to 0
        ))
      }
    } catch (e: Exception) {
      Log.e("MoonNative", "Error detecting navigation mode: ${e.message}")
      e.printStackTrace()
      result.error("NAVIGATION_MODE_ERROR", "Error detecting navigation mode: ${e.message}", null)
    }
  }
  
  /**
   * Gets the current ringer mode of the device
   *
   * @param result Flutter result callback
   */
  private fun getRingerMode(result: Result) {
    try {
      // Get the AudioManager from system services
      val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
      val ringerMode = audioManager.ringerMode
      
      // Determine if sound and vibration are enabled based on the ringer mode
      // RINGER_MODE_SILENT = 0: No sound
      // RINGER_MODE_VIBRATE = 1: No sound, only vibration
      // RINGER_MODE_NORMAL = 2: Sound and possibly vibration
      
      val hasSound = ringerMode == AudioManager.RINGER_MODE_NORMAL
      
      // For vibration, we need to check based on ringer mode and vibrate setting
      val hasVibration = when (ringerMode) {
        AudioManager.RINGER_MODE_SILENT -> false
        AudioManager.RINGER_MODE_VIBRATE -> true
        AudioManager.RINGER_MODE_NORMAL -> {
          // In normal mode, check if vibrate while ringing is enabled
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager.isWiredHeadsetOn || Settings.System.getInt(
              context.contentResolver,
              "vibrate_when_ringing",
              0
            ) == 1
          } else {
            // For older Android versions, assume vibration is on in normal mode
            true
          }
        }
        else -> false
      }
      
      Log.d("MoonNative", "Ringer mode detected: $ringerMode (hasSound: $hasSound, hasVibration: $hasVibration)")
      
      result.success(mapOf(
        "ringerMode" to ringerMode,
        "hasSound" to hasSound,
        "hasVibration" to hasVibration
      ))
      
    } catch (e: Exception) {
      Log.e("MoonNative", "Error detecting ringer mode: ${e.message}")
      e.printStackTrace()
      result.error("RINGER_MODE_ERROR", "Error detecting ringer mode: ${e.message}", null)
    }
  }
}