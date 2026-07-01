#include <jni.h>
#include <string>
#include <vector>
#include <cstdio>
#include <climits>
#include <android/log.h>
#include "media_carver.h"

#define LOG_TAG "RecoverXNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using namespace recoverx;

// ----- ग्लोबल सेशन ऑब्जेक्ट -----
static std::unique_ptr<MediaCarver> g_carver;
static std::unique_ptr<CarveSession> g_session;
static StreamChunkTier tierFromInt(jint tier) { /* वही पुराना लॉजिक */ }

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

// ----- पुराने JNI एंट्री पॉइंट्स (मौजूदा Kotlin कोड के साथ) -----
extern "C" JNIEXPORT jstring JNICALL
Java_com_recoverx_app_MainActivity_getEngineVersion(JNIEnv* env, jobject) {
    return env->NewStringUTF("RecoverX Engine v3.0 (media_carver, NEON-MP4)");
}

extern "C" JNIEXPORT void JNICALL
Java_com_recoverx_app_MainActivity_initCarver(JNIEnv* env, jobject, jstring outputDir, jint ramTier) {
    const char* dir = env->GetStringUTFChars(outputDir, nullptr);
    if (dir == nullptr) return;
    g_carver.reset(new MediaCarver(100LL * 1024 * 1024));   // max 100MB per file
    // आउटपुट डायरेक्टरी सेव करनी हो तो कर लें, लेकिन MediaCarver खुद फ़ाइल नहीं लिखता
    env->ReleaseStringUTFChars(outputDir, dir);
}

extern "C" JNIEXPORT void JNICALL
Java_com_recoverx_app_MainActivity_releaseCarver(JNIEnv*, jobject) {
    g_carver.reset();
    g_session.reset();
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

    // फ़ाइल साइज़ चेक (100MB लिमिट)
    FILE* fp = fopen(path, "rb");
    if (!fp) { env->ReleaseStringUTFChars(sourcePath, path); return -1; }
    fseek(fp, 0, SEEK_END);
    long sz = ftell(fp);
    fclose(fp);
    if (sz < 0 || sz > 100LL * 1024 * 1024) {
        env->ReleaseStringUTFChars(sourcePath, path);
        return (sz < 0) ? -1 : -2;
    }

    // ग्लोबल रेफरेंस लें ताकि कॉलबैक सेफ रहे
    jobject globalListener = (listener != nullptr) ? env->NewGlobalRef(listener) : nullptr;
    int filesFound = 0;

    CarveError err = g_carver->scanFile(path,
        [&](const CarvedFile& cf) {
            filesFound++;
            if (globalListener) {
                invokeJavaCallback(env, globalListener, cf.outputPath.c_str(), cf.data.size());
            }
        });

    if (globalListener) env->DeleteGlobalRef(globalListener);
    env->ReleaseStringUTFChars(sourcePath, path);

    return static_cast<jint>(err == CarveError::NONE ? filesFound : -1);
}