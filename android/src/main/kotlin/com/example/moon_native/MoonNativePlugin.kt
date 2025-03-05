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

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
