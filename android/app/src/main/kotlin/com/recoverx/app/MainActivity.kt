package com.recoverx.app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "recoverx/native"
    private val EVENT_CHANNEL = "recoverx/native_events"

    private var eventSink: EventChannel.EventSink? = null
    private val scanExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        init { System.loadLibrary("recoverx_native") }
    }

    // ---------- JNI prototypes ----------
    external fun getEngineVersion(): String
    external fun startScanSession(maxFileSizeMb: Int, threadCount: Int): Int
    external fun scanFileInSession(sessionId: Int, path: String, listener: NativeListener?): Int
    external fun runDeepScan(sessionId: Int, folderPath: String, maxResults: Int, listener: NativeListener?)
    external fun stopScanSession(sessionId: Int)
    external fun releaseCarver(sessionId: Int)

    // ---------- NativeListener that emits events to Flutter ----------
    private inner class FlutterNativeListener : NativeListener {
        override fun onResult(thumbBytes: ByteArray, mediaType: String, sizeBytes: Long) {
            mainHandler.post {
                eventSink?.success(mapOf(
                    "type" to "result",
                    "bytes" to thumbBytes,
                    "mediaType" to mediaType,
                    "sizeBytes" to sizeBytes
                ))
            }
        }

        override fun onProgress(filesScanned: Long, bytesProcessed: Long,
                                totalEstimate: Long, filesRecovered: Long, etaSeconds: Double) {
            mainHandler.post {
                eventSink?.success(mapOf(
                    "type" to "progress",
                    "filesScanned" to filesScanned,
                    "bytesProcessed" to bytesProcessed,
                    "totalBytesEstimate" to totalEstimate,
                    "filesRecovered" to filesRecovered,
                    "etaSeconds" to etaSeconds
                ))
            }
        }

        override fun onError(code: String, message: String) {
            mainHandler.post {
                eventSink?.success(mapOf(
                    "type" to "error",
                    "code" to code,
                    "message" to message
                ))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Event channel setup
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        val listener = FlutterNativeListener()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getEngineVersion" -> {
                        try { result.success(getEngineVersion()) }
                        catch (e: Exception) { result.error("NATIVE_ERROR", e.message, null) }
                    }

                    "startScanSession" -> {
                        val maxFileSizeMb = call.argument<Int>("maxFileSizeMb") ?: 30
                        val threadCount = call.argument<Int>("threadCount") ?: 0
                        scanExecutor.execute {
                            try {
                                val sessionId = startScanSession(maxFileSizeMb, threadCount)
                                mainHandler.post { result.success(sessionId) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
                            }
                        }
                    }

                    "scanFileInSession" -> {
                        val sessionId = call.argument<Int>("sessionId") ?: -1
                        val path = call.argument<String>("path") ?: ""
                        scanExecutor.execute {
                            try {
                                val count = scanFileInSession(sessionId, path, listener)
                                mainHandler.post { result.success(count) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
                            }
                        }
                    }

                    "runDeepScan" -> {
                        val sessionId = call.argument<Int>("sessionId") ?: -1
                        val folderPath = call.argument<String>("folderPath") ?: ""
                        val maxResults = call.argument<Int>("maxResults") ?: 200
                        scanExecutor.execute {
                            try {
                                runDeepScan(sessionId, folderPath, maxResults, listener)
                                mainHandler.post { result.success(null) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
                            }
                        }
                    }

                    "stopScanSession" -> {
                        val sessionId = call.argument<Int>("sessionId") ?: -1
                        scanExecutor.execute {
                            stopScanSession(sessionId)
                            mainHandler.post { result.success(null) }
                        }
                    }

                    "releaseCarver" -> {
                        val sessionId = call.argument<Int>("sessionId") ?: -1
                        scanExecutor.execute {
                            releaseCarver(sessionId)
                            mainHandler.post { result.success(null) }
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