package com.example.moon_native

import androidx.annotation.NonNull
import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaCodec
import android.net.Uri
import android.util.Log
import android.os.Build

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.util.UUID

/** MoonNativePlugin */
class MoonNativePlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context : Context

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "moon_native")
    context = flutterPluginBinding.applicationContext
    channel.setMethodCallHandler(this)
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
      else -> {
        result.notImplemented()
      }
    }
  }
  
  private fun trimVideo(videoPath: String, startTime: Double, endTime: Double, result: Result) {
    Thread(Runnable {
      var inputFileDescriptor: Int? = null
      var extractor: MediaExtractor? = null
      var muxer: MediaMuxer? = null

      try {
        // Create a unique output file in app's cache directory
        val outputDir = context.cacheDir
        val outputFileName = "trimmed_${UUID.randomUUID().toString()}.mp4"
        val outputFile = File(outputDir, outputFileName)
        val outputPath = outputFile.absolutePath

        Log.d("MoonNative", "Trimming video from $startTime to $endTime seconds")
        Log.d("MoonNative", "Input: $videoPath, Output: $outputPath")

        // Convert seconds to microseconds
        val startTimeUs = (startTime * 1000000).toLong()
        val endTimeUs = (endTime * 1000000).toLong()

        // Set up the extractor to read from the source file
        extractor = MediaExtractor()
        extractor.setDataSource(videoPath)

        // Set up media muxer for the output file
        muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        // Map to track the indices between extractor and muxer
        val trackIndex = HashMap<Int, Int>()

        // Get total number of tracks (video, audio, etc.) in input
        val trackCount = extractor.trackCount

        // Process each track in the video file
        for (i in 0 until trackCount) {
          // Get the track's format
          val format = extractor.getTrackFormat(i)
          val mime = format.getString(MediaFormat.KEY_MIME)

          // We need mime to continue
          if (mime == null) continue

          // Add the track to the muxer
          extractor.selectTrack(i)
          val muxerTrackIndex = muxer.addTrack(format)
          trackIndex[i] = muxerTrackIndex

          // Seek to desired starting position
          extractor.seekTo(startTimeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        }

        // Start the muxer
        muxer.start()

        // Allocate buffer for reading samples
        val bufferSize = 1024 * 1024 // 1MB buffer
        val buffer = ByteBuffer.allocate(bufferSize)
        val bufferInfo = MediaCodec.BufferInfo()

        // Process frames from each track
        for (inputTrack in 0 until trackCount) {
          if (!trackIndex.containsKey(inputTrack)) continue

          // Reset position to start point for this track
          extractor.selectTrack(inputTrack)
          extractor.seekTo(startTimeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

          // Copy samples from extractor to muxer
          while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)

            // End of file or beyond our end time
            if (sampleSize < 0 || extractor.sampleTime > endTimeUs) {
              extractor.unselectTrack(inputTrack)
              break
            }

            // Adjust buffer info for the current sample
            bufferInfo.size = sampleSize
            bufferInfo.offset = 0
            bufferInfo.presentationTimeUs = extractor.sampleTime - startTimeUs
            bufferInfo.flags = extractor.sampleFlags

            // Write the sample to the output
            val outputTrack = trackIndex[inputTrack]!!
            muxer.writeSampleData(outputTrack, buffer, bufferInfo)

            // Advance to next frame
            extractor.advance()
          }
        }

        // Release resources
        muxer.stop()
        muxer.release()
        muxer = null
        extractor.release()
        extractor = null

        Log.d("MoonNative", "Video trimming completed successfully")
        android.os.Handler(android.os.Looper.getMainLooper()).post {
          result.success(outputPath)
        }
      } catch (e: Exception) {
        Log.e("MoonNative", "Error trimming video: ${e.message}")
        e.printStackTrace()
        android.os.Handler(android.os.Looper.getMainLooper()).post {
          result.error("TRIM_ERROR", "Error trimming video: ${e.message}", null)
        }
      } finally {
        try {
          extractor?.release()
          muxer?.release()
        } catch (e: Exception) {
          Log.e("MoonNative", "Error closing resources: ${e.message}")
        }
      }
    }).start()
  }

  private fun rotateVideo(videoPath: String, quarterTurns: Int, result: Result) {
    Thread(Runnable {
      var extractor: MediaExtractor? = null
      var muxer: MediaMuxer? = null

      try {
        // Create a unique output file in app's cache directory
        val outputDir = context.cacheDir
        val outputFileName = "rotated_${UUID.randomUUID().toString()}.mp4"
        val outputFile = File(outputDir, outputFileName)
        val outputPath = outputFile.absolutePath

        Log.d("MoonNative", "Rotating video by $quarterTurns quarter turns")
        Log.d("MoonNative", "Input: $videoPath, Output: $outputPath")

        // Set up the extractor to read from the source file
        extractor = MediaExtractor()
        extractor.setDataSource(videoPath)

        // Retrieve video metadata to get width, height, etc.
        val retriever = MediaMetadataRetriever()
        retriever.setDataSource(videoPath)
        
        // Rotation needs to be applied to the video track
        val trackIndex = findVideoTrack(extractor)
        if (trackIndex < 0) {
          android.os.Handler(android.os.Looper.getMainLooper()).post {
            result.error("NO_VIDEO_TRACK", "No video track found in the input file", null)
          }
          return@Runnable
        }
        
        // Get the format of the track and extract info
        val format = extractor.getTrackFormat(trackIndex)
        val width = format.getInteger(MediaFormat.KEY_WIDTH)
        val height = format.getInteger(MediaFormat.KEY_HEIGHT)
        
        // Calculate rotation angle based on quarter turns
        // Android uses a counter-clockwise convention for rotation
        // 1 = 90° clockwise = 270° counter-clockwise in Android rotation
        // 2 = 180° = 180° in Android rotation
        // 3 = 270° clockwise = 90° counter-clockwise in Android rotation
        // -1 = 90° counter-clockwise = 90° counter-clockwise in Android rotation
        val rotationAngle = when (quarterTurns) {
          1 -> 270  // 90° clockwise becomes 270° counter-clockwise
          2 -> 180  // 180° is the same in both directions
          3 -> 90   // 270° clockwise becomes 90° counter-clockwise
          -1 -> 90  // 90° counter-clockwise is the same
          -2 -> 180 // 180° is the same in both directions
          -3 -> 270 // 270° counter-clockwise is the same as 270° counter-clockwise
          else -> 0 // No rotation for invalid values
        }
        
        // Create muxer with the specified rotation
        muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        muxer.setOrientationHint(rotationAngle)
        
        // Process all tracks (audio and video)
        val trackCount = extractor.trackCount
        val indexMap = HashMap<Int, Int>()
        
        for (i in 0 until trackCount) {
          val trackFormat = extractor.getTrackFormat(i)
          val mime = trackFormat.getString(MediaFormat.KEY_MIME)
          if (mime == null) continue
          
          val muxerTrackIndex = muxer.addTrack(trackFormat)
          indexMap[i] = muxerTrackIndex
        }
        
        // Start the muxer
        muxer.start()
        
        // Allocate buffer for reading samples
        val bufferSize = 1024 * 1024 // 1MB buffer
        val buffer = ByteBuffer.allocate(bufferSize)
        val bufferInfo = MediaCodec.BufferInfo()
        
        // Copy all samples from extractor to muxer
        for (trackID in 0 until trackCount) {
          if (!indexMap.containsKey(trackID)) continue
          
          extractor.selectTrack(trackID)
          
          while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) {
              extractor.unselectTrack(trackID)
              break
            }
            
            bufferInfo.size = sampleSize
            bufferInfo.offset = 0
            bufferInfo.presentationTimeUs = extractor.sampleTime
            bufferInfo.flags = extractor.sampleFlags
            
            val muxerTrackIndex = indexMap[trackID]!!
            muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
            
            extractor.advance()
          }
        }
        
        // Release resources
        muxer.stop()
        muxer.release()
        muxer = null
        extractor.release()
        extractor = null
        retriever.release()
        
        Log.d("MoonNative", "Video rotation completed successfully")
        android.os.Handler(android.os.Looper.getMainLooper()).post {
          result.success(outputPath)
        }
        
      } catch (e: Exception) {
        Log.e("MoonNative", "Error rotating video: ${e.message}")
        e.printStackTrace()
        android.os.Handler(android.os.Looper.getMainLooper()).post {
          result.error("ROTATION_ERROR", "Error rotating video: ${e.message}", null)
        }
      } finally {
        try {
          extractor?.release()
          muxer?.release()
        } catch (e: Exception) {
          Log.e("MoonNative", "Error closing resources: ${e.message}")
        }
      }
    }).start()
  }

  // Helper function to find the video track index
  private fun findVideoTrack(extractor: MediaExtractor): Int {
    for (i in 0 until extractor.trackCount) {
      val format = extractor.getTrackFormat(i)
      val mime = format.getString(MediaFormat.KEY_MIME)
      if (mime?.startsWith("video/") == true) {
        return i
      }
    }
    return -1
  }
  
  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
