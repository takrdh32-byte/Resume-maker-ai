#include <jni.h>
#include <string>
#include <vector>
#include <cstdio>
#include <climits>
#include <android/log.h>
#include "jpeg_carver.h"

#define LOG_TAG "RecoverXNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

constexpr jlong MAX_SCANFILE_SIZE = 100LL * 1024 * 1024; // 100MB

static StreamChunkTier tierFromInt(jint tier) {
    switch (tier) {
        case 0: return StreamChunkTier::LOW_RAM;
        case 1: return StreamChunkTier::MID_RAM;
        default: return StreamChunkTier::HIGH_RAM;
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_recoverx_app_MainActivity_getEngineVersion(JNIEnv* env, jobject) {
    std::string version = "RecoverX-Engine v0.5.0";
    return env->NewStringUTF(version.c_str());
}

static void invokeJavaCallback(JNIEnv* env, jobject listenerObj, const CarvedFile& cf) {
    if (listenerObj == nullptr) return;

    jclass listenerClass = env->GetObjectClass(listenerObj);
    if (listenerClass == nullptr) {
        LOGE("invokeJavaCallback: listener class not found");
        return;
    }

    jmethodID onFileFound = env->GetMethodID(listenerClass, "onFileFound", "(Ljava/lang/String;J)V");
    if (onFileFound == nullptr) {
        LOGE("invokeJavaCallback: onFileFound(String, long) method not found on listener");
        env->ExceptionClear();
        env->DeleteLocalRef(listenerClass);
        return;
    }

    jstring jPath = env->NewStringUTF(cf.outputPath.c_str());
    env->CallVoidMethod(listenerObj, onFileFound, jPath, static_cast<jlong>(cf.fileSize));

    if (env->ExceptionCheck()) {
        LOGE("invokeJavaCallback: exception occurred while calling onFileFound");
        env->ExceptionClear();
    }

    env->DeleteLocalRef(jPath);
    env->DeleteLocalRef(listenerClass);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_recoverx_app_MainActivity_scanFile(
        JNIEnv* env, jobject /* this */,
        jstring sourcePath, jstring outputDir, jint ramTier, jobject listener) {

    const char* cSourcePath = env->GetStringUTFChars(sourcePath, nullptr);
    const char* cOutputDir = env->GetStringUTFChars(outputDir, nullptr);

    if (cSourcePath == nullptr || cOutputDir == nullptr) {
        LOGE("scanFile: failed to read JNI strings (out of memory?)");
        if (cSourcePath) env->ReleaseStringUTFChars(sourcePath, cSourcePath);
        if (cOutputDir) env->ReleaseStringUTFChars(outputDir, cOutputDir);
        return -1;
    }

    FILE* checkFp = fopen(cSourcePath, "rb");
    if (checkFp == nullptr) {
        LOGE("scanFile: cannot open %s", cSourcePath);
        env->ReleaseStringUTFChars(sourcePath, cSourcePath);
        env->ReleaseStringUTFChars(outputDir, cOutputDir);
        return -1;
    }
    fseek(checkFp, 0, SEEK_END);
    long fileSize = ftell(checkFp);
    fclose(checkFp);

    if (fileSize < 0) {
        LOGE("scanFile: ftell failed for %s", cSourcePath);
        env->ReleaseStringUTFChars(sourcePath, cSourcePath);
        env->ReleaseStringUTFChars(outputDir, cOutputDir);
        return -1;
    }

    if (fileSize > MAX_SCANFILE_SIZE) {
        LOGE("scanFile: %s is %ld bytes — exceeds 100MB limit, use scanPartition/scanStream instead",
             cSourcePath, fileSize);
        env->ReleaseStringUTFChars(sourcePath, cSourcePath);
        env->ReleaseStringUTFChars(outputDir, cOutputDir);
        return -2;
    }

    LOGI("scanFile: starting scan of %s (%ld bytes) -> %s", cSourcePath, fileSize, cOutputDir);

    jobject globalListener = (listener != nullptr) ? env->NewGlobalRef(listener) : nullptr;

    JpegCarver carver(cOutputDir, tierFromInt(ramTier));

    CarvedFileCallback callback = nullptr;
    if (globalListener != nullptr) {
        callback = [env, globalListener](const CarvedFile& cf) {
            invokeJavaCallback(env, globalListener, cf);
        };
    }

    std::vector<CarvedFile> results = carver.scanFile(cSourcePath, callback);

    if (globalListener != nullptr) {
        env->DeleteGlobalRef(globalListener);
    }

    env->ReleaseStringUTFChars(sourcePath, cSourcePath);
    env->ReleaseStringUTFChars(outputDir, cOutputDir);

    LOGI("scanFile: complete, %zu files recovered", results.size());
    return static_cast<jint>(results.size());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_recoverx_app_MainActivity_scanPartition(
        JNIEnv* env, jobject /* this */,
        jstring devicePath, jstring outputDir, jlong totalSize, jint ramTier, jobject listener) {

    const char* cDevicePath = env->GetStringUTFChars(devicePath, nullptr);
    const char* cOutputDir = env->GetStringUTFChars(outputDir, nullptr);

    if (cDevicePath == nullptr || cOutputDir == nullptr) {
        LOGE("scanPartition: failed to read JNI strings");
        if (cDevicePath) env->ReleaseStringUTFChars(devicePath, cDevicePath);
        if (cOutputDir) env->ReleaseStringUTFChars(outputDir, cOutputDir);
        return -1;
    }

    if (totalSize <= 0) {
        LOGE("scanPartition: invalid totalSize=%lld", (long long)totalSize);
        env->ReleaseStringUTFChars(devicePath, cDevicePath);
        env->ReleaseStringUTFChars(outputDir, cOutputDir);
        return -1;
    }

    if (static_cast<unsigned long long>(totalSize) > static_cast<unsigned long long>(SIZE_MAX)) {
        LOGE("scanPartition: totalSize=%lld exceeds SIZE_MAX on this platform (32-bit device?)",
             (long long)totalSize);
        env->ReleaseStringUTFChars(devicePath, cDevicePath);
        env->ReleaseStringUTFChars(outputDir, cOutputDir);
        return -3;
    }

    LOGI("scanPartition: opening %s (size=%lld bytes)", cDevicePath, (long long)totalSize);

    FILE* fp = fopen(cDevicePath, "rb");
    if (fp == nullptr) {
        LOGE("scanPartition: cannot open %s — root permission missing or device path wrong", cDevicePath);
        env->ReleaseStringUTFChars(devicePath, cDevicePath);
        env->ReleaseStringUTFChars(outputDir, cOutputDir);
        return -1;
    }

    jobject globalListener = (listener != nullptr) ? env->NewGlobalRef(listener) : nullptr;

    JpegCarver carver(cOutputDir, tierFromInt(ramTier));

    CarvedFileCallback callback = nullptr;
    if (globalListener != nullptr) {
        callback = [env, globalListener](const CarvedFile& cf) {
            invokeJavaCallback(env, globalListener, cf);
        };
    }

    std::vector<CarvedFile> results = carver.scanStream(fp, static_cast<size_t>(totalSize), callback);

    fclose(fp);

    if (globalListener != nullptr) {
        env->DeleteGlobalRef(globalListener);
    }

    env->ReleaseStringUTFChars(devicePath, cDevicePath);
    env->ReleaseStringUTFChars(outputDir, cOutputDir);

    LOGI("scanPartition: complete, %zu files recovered", results.size());
    return static_cast<jint>(results.size());
}