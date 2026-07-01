package com.recoverx.app

interface NativeListener {
    fun onResult(thumbBytes: ByteArray, mediaType: String, sizeBytes: Long)
    fun onProgress(filesScanned: Long, bytesProcessed: Long, totalEstimate: Long, filesRecovered: Long, etaSeconds: Double)
    fun onError(code: String, message: String)
}