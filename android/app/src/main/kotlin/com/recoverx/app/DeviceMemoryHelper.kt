package com.recoverx.app
import android.app.ActivityManager
import android.content.Context
object DeviceMemoryHelper {
    fun detectRamTier(context: Context): Int {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        am.getMemoryInfo(memInfo)
        val totalGB = memInfo.totalMem / (1024 * 1024 * 1024)
        return when {
            totalGB <= 2 -> 0
            totalGB <= 4 -> 1
            else -> 2
        }
    }
}