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

static JpegCarver* g_pCarver = nullptr;

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

extern "C" JNIEXPORT void JNICALL
Java_com_recoverx_app_MainActivity_initCarver(JNIEnv* env, jobject,
                                                jstring outputDir, jint ramTier) {
    const char* cOutputDir = env->GetStringUTFChars(outputDir, nullptr);
    if (cOutputDir == nullptr) return;

    delete g_pCarver;
    g_pCarver = new JpegCarver(cOutputDir, tierFromInt(ramTier));

    env->ReleaseStringUTFChars(outputDir, cOutputDir);
}

extern "C" JNIEXPORT void JNICALL
Java_com_recoverx_app_MainActivity_releaseCarver(JNIEnv* env, jobject) {
    delete g_pCarver;
    g_pCarver = nullptr;
}

static void invokeJavaCallback(JNIEnv* env, jobject listenerObj, const CarvedFile& cf) {
    if (listenerObj == nullptr) return;
    jclass listenerClass = env->GetObjectClass(listenerObj);
    if (listenerClass == nullptr) return;
    jmethodID onFileFound = env->GetMethodID(listenerClass, "onFileFound", "(Ljava/lang/String;J)V");
    if (onFileFound == nullptr) {
        env->ExceptionClear();
        env->DeleteLocalRef(listenerClass);
        return;
    }
    jstring jPath = env->NewStringUTF(cf.outputPath.c_str());
    env->CallVoidMethod(listenerObj, onFileFound, jPath, static_cast<jlong>(cf.fileSize));
    if (env->ExceptionCheck()) env->ExceptionClear();
    env->DeleteLocalRef(jPath);
    env->DeleteLocalRef(listenerClass);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_recoverx_app_MainActivity_scanFileWithCarver(
        JNIEnv* env, jobject, jstring sourcePath, jobject listener) {

    if (g_pCarver == nullptr) {
        LOGE("scanFileWithCarver: carver not initialized");
        return -1;
    }

    const char* cSourcePath = env->GetStringUTFChars(sourcePath, nullptr);
    if (cSourcePath == nullptr) return -1;

    // 100MB limit check
    FILE* checkFp = fopen(cSourcePath, "rb");
    if (checkFp == nullptr) {
        LOGE("scanFileWithCarver: cannot open %s", cSourcePath);
        env->ReleaseStringUTFChars(sourcePath, cSourcePath);
        return -1;
    }
    fseek(checkFp, 0, SEEK_END);
    long fileSize = ftell(checkFp);
    fclose(checkFp);

    if (fileSize < 0) {
        env->ReleaseStringUTFChars(sourcePath, cSourcePath);
        return -1;
    }
    constexpr jlong MAX_SIZE = 100LL * 1024 * 1024;
    if (fileSize > MAX_SIZE) {
        env->ReleaseStringUTFChars(sourcePath, cSourcePath);
        return -2;
    }

    jobject globalListener = (listener != nullptr) ? env->NewGlobalRef(listener) : nullptr;
    CarvedFileCallback callback = nullptr;
    if (globalListener != nullptr) {
        callback = [env, globalListener](const CarvedFile& cf) {
            invokeJavaCallback(env, globalListener, cf);
        };
    }

    auto results = g_pCarver->scanFile(cSourcePath, callback);

    if (globalListener != nullptr) {
        env->DeleteGlobalRef(globalListener);
    }
    env->ReleaseStringUTFChars(sourcePath, cSourcePath);

    return static_cast<jint>(results.size());
}