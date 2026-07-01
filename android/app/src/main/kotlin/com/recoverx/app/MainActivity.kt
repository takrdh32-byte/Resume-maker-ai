package com.recoverx.app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.recoverx.app/native"   // वही चैनल जो Dart उपयोग करता है
    private val EVENT_CHANNEL = "com.recoverx.app/scan_progress"

    private var eventSink: EventChannel.EventSink? = null
    private val scanExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        init { System.loadLibrary("recoverx_native") }
    }

    // ---------- JNI prototypes ----------
    external fun getEngineVersion(): String
    external fun initCarver(outputDir: String, ramTier: Int)
    external fun releaseCarver()
    external fun scanFileWithCarver(sourcePath: String, listener: CarvedFileListener?): Int

    // ---------- CarvedFileListener को EventChannel पर भेजना ----------
    private val fileListener = object : CarvedFileListener {
        override fun onFileFound(path: String, sizeBytes: Long) {
            mainHandler.post {
                eventSink?.success(mapOf(
                    "type" to "result",
                    "path" to path,
                    "size" to sizeBytes
                ))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Event channel for real-time results
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getEngineVersion" -> {
                        try { result.success(getEngineVersion()) }
                        catch (e: Exception) { result.error("NATIVE_ERROR", e.message, null) }
                    }

                    "startScanSession" -> {
                        val outputDir = call.argument<String>("outputDir") ?: ""
                        if (outputDir.isEmpty()) {
                            result.error("INVALID_ARGS", "outputDir missing", null)
                            return@setMethodCallHandler
                        }
                        java.io.File(outputDir).mkdirs()
                        val ramTier = 2 // हाई RAM (तुम DeviceMemoryHelper भी लगा सकते हो)
                        scanExecutor.execute {
                            try {
                                initCarver(outputDir, ramTier)
                                mainHandler.post { result.success(true) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
                            }
                        }
                    }

                    "scanFileInSession" -> {
                        val sourcePath = call.argument<String>("sourcePath") ?: ""
                        if (sourcePath.isEmpty()) {
                            result.error("INVALID_ARGS", "sourcePath missing", null)
                            return@setMethodCallHandler
                        }
                        scanExecutor.execute {
                            try {
                                val count = scanFileWithCarver(sourcePath, fileListener)
                                mainHandler.post {
                                    if (count == -2) result.error("FILE_TOO_LARGE", "File exceeds 100MB", null)
                                    else result.success(count)
                                }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
                            }
                        }
                    }

                    "endScanSession" -> {
                        scanExecutor.execute {
                            releaseCarver()
                            mainHandler.post { result.success(true) }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        scanExecutor.shutdown()
        super.onDestroy()
    }
}