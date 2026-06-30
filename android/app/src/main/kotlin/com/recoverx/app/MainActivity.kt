package com.recoverx.app

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.Executors
import android.app.AlertDialog

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.recoverx.app/native"
    private val EVENT_CHANNEL = "com.recoverx.app/scan_progress"

    private var progressSink: EventChannel.EventSink? = null
    private val scanExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        init {
            System.loadLibrary("recoverx_native")
        }
    }

    external fun getEngineVersion(): String
    external fun scanFile(sourcePath: String, outputDir: String, ramTier: Int, listener: CarvedFileListener?): Int
    external fun scanPartition(devicePath: String, outputDir: String, totalSize: Long, ramTier: Int, listener: CarvedFileListener?): Int

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Thread.setDefaultUncaughtExceptionHandler { thread, ex ->
            val msg = ex.message ?: "Unknown error"
            mainHandler.post {
                AlertDialog.Builder(this@MainActivity)
                    .setTitle("App Crash")
                    .setMessage("Error: $msg")
                    .setPositiveButton("OK", null)
                    .show()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }
                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            })

        val fileListener = object : CarvedFileListener {
            override fun onFileFound(path: String, sizeBytes: Long) {
                mainHandler.post {
                    progressSink?.success(mapOf("path" to path, "size" to sizeBytes))
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getEngineVersion" -> {
                        try { result.success(getEngineVersion()) }
                        catch (e: Exception) { result.error("NATIVE_ERROR", e.message, null) }
                    }
                    "scanFile" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val outputDir = call.argument<String>("outputDir")
                        if (sourcePath == null || outputDir == null) {
                            result.error("INVALID_ARGS", "sourcePath/outputDir missing", null)
                            return@setMethodCallHandler
                        }
                        File(outputDir).mkdirs()
                        val ramTier = DeviceMemoryHelper.detectRamTier(applicationContext)
                        scanExecutor.execute {
                            try {
                                val count = scanFile(sourcePath, outputDir, ramTier, fileListener)
                                mainHandler.post {
                                    if (count == -2) result.error("FILE_TOO_LARGE", "File exceeds 100MB, use scanPartition instead", null)
                                    else result.success(count)
                                }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
                            }
                        }
                    }
                    "scanPartition" -> {
                        val devicePath = call.argument<String>("devicePath")
                        val outputDir = call.argument<String>("outputDir")
                        val totalSize = call.argument<Number>("totalSize")?.toLong()
                        if (devicePath == null || outputDir == null || totalSize == null) {
                            result.error("INVALID_ARGS", "devicePath/outputDir/totalSize missing", null)
                            return@setMethodCallHandler
                        }
                        File(outputDir).mkdirs()
                        val ramTier = DeviceMemoryHelper.detectRamTier(applicationContext)
                        scanExecutor.execute {
                            try {
                                val count = scanPartition(devicePath, outputDir, totalSize, ramTier, fileListener)
                                mainHandler.post {
                                    if (count == -3) result.error("SIZE_OVERFLOW", "Partition too large for this device's architecture", null)
                                    else result.success(count)
                                }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
                            }
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