package com.recoverx.app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.recoverx.app/native"
    private val EVENT_CHANNEL = "com.recoverx.app/scan_progress"

    private var progressSink: EventChannel.EventSink? = null
    private val scanExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        init { System.loadLibrary("recoverx_native") }
    }

    external fun getEngineVersion(): String
    external fun initCarver(outputDir: String, ramTier: Int)
    external fun releaseCarver()
    external fun scanFileWithCarver(sourcePath: String, listener: CarvedFileListener?): Int

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { progressSink = events }
                override fun onCancel(arguments: Any?) { progressSink = null }
            })

        val fileListener = object : CarvedFileListener {
            override fun onFileFound(path: String, sizeBytes: Long) {
                mainHandler.post { progressSink?.success(mapOf("path" to path, "size" to sizeBytes)) }
            }
        }

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
                        File(outputDir).mkdirs()
                        val ramTier = DeviceMemoryHelper.detectRamTier(applicationContext)
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