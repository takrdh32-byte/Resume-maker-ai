package com.recoverx.app

interface CarvedFileListener {
    fun onFileFound(path: String, sizeBytes: Long)
}