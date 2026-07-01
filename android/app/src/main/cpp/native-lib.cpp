#include <jni.h>
#include <string>
#include <vector>
#include <cstdio>
#include <climits>
#include <fstream>
#include <android/log.h>
#include "media_carver.h"

#define LOG_TAG "RecoverXNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using namespace recoverx;

// ----- ग्लोबल सेशन ऑब्जेक्ट (पुरानी तरह) -----
static std::unique_ptr<MediaCarver> g_carver;
static std::string g_outputDir;

// ----- JNI हेल्पर (कॉलबैक के लिए) -----
static void invokeJavaCallback(JNIEnv* env, jobject listenerObj, const std::string& path, jlong sizeBytes) {
    if (listenerObj == nullptr) return;
    jclass listenerClass = env->GetObjectClass(listenerObj);
    jmethodID onFileFound = env->GetMethodID(listenerClass, "onFileFound", "(Ljava/lang/String;J)V");
    if (onFileFound == nullptr) {
        env->ExceptionClear();
        env->DeleteLocalRef(listenerClass);
        return;
    }
    jstring jPath = env->NewStringUTF(path.c_str());
    env->CallVoidMethod(listenerObj, onFileFound, jPath, sizeBytes);
    env->DeleteLocalRef(jPath);
    env->DeleteLocalRef(listenerClass);
}

// ----- CarvedFile को डिस्क पर सेव करने वाला हेल्पर -----
static std::string saveCarvedFile(const CarvedFile& cf) {
    static int counter = 0;
    counter++;
    std::string ext;
    switch (cf.type) {
        case MediaType::JPEG: ext = ".jpg"; break;
        case MediaType::PNG:  ext = ".png"; break;
        case MediaType::MP4:  ext = ".mp4"; break;
        default: ext = ".bin"; break;
    }
    std::string path = g_outputDir + "/recovered_" + std::to_string(counter) + ext;
    std::ofstream out(path, std::ios::binary);
    if (out.is_open()) {
        out.write(reinterpret_cast<const char*>(cf.data.data()), cf.data.size());
        out.close();
        return path;
    }
    return "";
}

// ----- पुराने JNI एंट्री पॉइंट्स (Kotlin कोड को छूने की ज़रूरत नहीं) -----
extern "C" JNIEXPORT jstring JNICALL
Java_com_recoverx_app_MainActivity_getEngineVersion(JNIEnv* env, jobject) {
    return env->NewStringUTF("RecoverX Engine v3.0 (media_carver, NEON-MP4)");
}

extern "C" JNIEXPORT void JNICALL
Java_com_recoverx_app_MainActivity_initCarver(JNIEnv* env, jobject, jstring outputDir, jint /*ramTier*/) {
    const char* dir = env->GetStringUTFChars(outputDir, nullptr);
    if (dir == nullptr) return;
    g_outputDir = dir;
    // 100MB प्रति फ़ाइल की सीमा (पुरानी लिमिट के अनुसार)
    g_carver.reset(new MediaCarver(100LL * 1024 * 1024));
    env->ReleaseStringUTFChars(outputDir, dir);
    LOGI("initCarver: outputDir = %s, engine ready", g_outputDir.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_com_recoverx_app_MainActivity_releaseCarver(JNIEnv*, jobject) {
    g_carver.reset();
    g_outputDir.clear();
    LOGI("releaseCarver: engine released");
}

extern "C" JNIEXPORT jint JNICALL
Java_com_recoverx_app_MainActivity_scanFileWithCarver(
        JNIEnv* env, jobject, jstring sourcePath, jobject listener) {

    if (!g_carver) {
        LOGE("scanFileWithCarver: carver not initialized");
        return -1;
    }

    const char* path = env->GetStringUTFChars(sourcePath, nullptr);
    if (path == nullptr) return -1;

    // 100MB लिमिट चेक (पुरानी तरह)
    FILE* fp = fopen(path, "rb");
    if (!fp) { env->ReleaseStringUTFChars(sourcePath, path); return -1; }
    fseek(fp, 0, SEEK_END);
    long sz = ftell(fp);
    fclose(fp);
    if (sz < 0) { env->ReleaseStringUTFChars(sourcePath, path); return -1; }
    if (sz > 100LL * 1024 * 1024) {
        env->ReleaseStringUTFChars(sourcePath, path);
        return -2; // FILE_TOO_LARGE (पुराना कोड)
    }

    // ग्लोबल रेफरेंस ताकि कॉलबैक सेफ रहे
    jobject globalListener = (listener != nullptr) ? env->NewGlobalRef(listener) : nullptr;
    int filesFound = 0;

    CarveError err = g_carver->scanFile(path,
        [&](const CarvedFile& cf) {
            filesFound++;
            // CarvedFile को डिस्क पर सेव करो और पाथ लो
            std::string savedPath = saveCarvedFile(cf);
            if (!savedPath.empty() && globalListener) {
                invokeJavaCallback(env, globalListener, savedPath, static_cast<jlong>(cf.data.size()));
            }
        });

    if (globalListener) env->DeleteGlobalRef(globalListener);
    env->ReleaseStringUTFChars(sourcePath, path);

    if (err != CarveError::NONE) {
        LOGE("scanFileWithCarver: error code %d", static_cast<int>(err));
        return -1;
    }
    return static_cast<jint>(filesFound);
}