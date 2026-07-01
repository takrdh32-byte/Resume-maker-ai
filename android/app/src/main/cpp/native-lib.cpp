#include <jni.h>
#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <atomic>
#include <cstdio>
#include <android/log.h>
#include "media_carver.h"

#define LOG_TAG "RecoverXNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using namespace recoverx;

// ---------- session registry ----------
struct NativeSession {
    std::unique_ptr<MediaCarver> carver;
    std::unique_ptr<CarveSession> session;
    std::string outputDir;
};

static std::mutex g_sessionsMutex;
static std::unordered_map<int32_t, std::shared_ptr<NativeSession>> g_sessions;
static std::atomic<int32_t> g_nextSessionId{1};

static std::shared_ptr<NativeSession> getSession(int32_t id) {
    std::lock_guard<std::mutex> lock(g_sessionsMutex);
    auto it = g_sessions.find(id);
    return (it != g_sessions.end()) ? it->second : nullptr;
}

// ---------- helper to invoke Java listener ----------
static void invokeResult(JNIEnv* env, jobject listener, const CarvedFile& cf) {
    if (listener == nullptr) return;
    jclass cls = env->GetObjectClass(listener);
    jmethodID mid = env->GetMethodID(cls, "onResult", "([BLjava/lang/String;J)V");
    if (mid == nullptr) { env->ExceptionClear(); env->DeleteLocalRef(cls); return; }

    jbyteArray bytes = env->NewByteArray(cf.data.size());
    env->SetByteArrayRegion(bytes, 0, cf.data.size(), (const jbyte*)cf.data.data());

    const char* typeStr = "bin";
    switch (cf.type) {
        case MediaType::JPEG: typeStr = "jpeg"; break;
        case MediaType::PNG:  typeStr = "png"; break;
        case MediaType::MP4:  typeStr = "mp4"; break;
        default: break;
    }
    jstring jType = env->NewStringUTF(typeStr);
    env->CallVoidMethod(listener, mid, bytes, jType, (jlong)cf.data.size());
    env->DeleteLocalRef(bytes);
    env->DeleteLocalRef(jType);
    env->DeleteLocalRef(cls);
}

static void invokeProgress(JNIEnv* env, jobject listener, const ScanProgress& p) {
    if (listener == nullptr) return;
    jclass cls = env->GetObjectClass(listener);
    jmethodID mid = env->GetMethodID(cls, "onProgress", "(JJJJD)V");
    if (mid == nullptr) { env->ExceptionClear(); env->DeleteLocalRef(cls); return; }
    env->CallVoidMethod(listener, mid,
        (jlong)p.filesScanned, (jlong)p.bytesProcessed,
        (jlong)p.totalBytesEstimate, (jlong)p.filesRecovered, p.etaSeconds);
    env->DeleteLocalRef(cls);
}

static void invokeError(JNIEnv* env, jobject listener, const char* code, const char* message) {
    if (listener == nullptr) return;
    jclass cls = env->GetObjectClass(listener);
    jmethodID mid = env->GetMethodID(cls, "onError", "(Ljava/lang/String;Ljava/lang/String;)V");
    if (mid == nullptr) { env->ExceptionClear(); env->DeleteLocalRef(cls); return; }
    jstring jCode = env->NewStringUTF(code);
    jstring jMsg = env->NewStringUTF(message);
    env->CallVoidMethod(listener, mid, jCode, jMsg);
    env->DeleteLocalRef(jCode);
    env->DeleteLocalRef(jMsg);
    env->DeleteLocalRef(cls);
}

// ---------- JNI implementations ----------

extern "C" {

JNIEXPORT jstring JNICALL
Java_com_recoverx_app_MainActivity_getEngineVersion(JNIEnv* env, jobject) {
    return env->NewStringUTF("RecoverX Engine v3.0 (media_carver, NEON-MP4)");
}

JNIEXPORT jint JNICALL
Java_com_recoverx_app_MainActivity_startScanSession(JNIEnv* env, jobject,
                                                      jint maxFileSizeMb, jint threadCount) {
    auto ns = std::make_shared<NativeSession>();
    size_t maxBytes = static_cast<size_t>(maxFileSizeMb) * 1024ULL * 1024ULL;
    ns->carver = std::make_unique<MediaCarver>(maxBytes);
    ns->session = std::make_unique<CarveSession>(maxBytes, static_cast<unsigned>(threadCount));

    int32_t id = g_nextSessionId.fetch_add(1);
    std::lock_guard<std::mutex> lock(g_sessionsMutex);
    g_sessions[id] = ns;
    return id;
}

JNIEXPORT jint JNICALL
Java_com_recoverx_app_MainActivity_scanFileInSession(JNIEnv* env, jobject,
                                                       jint sessionId, jstring jPath,
                                                       jobject listener) {
    auto ns = getSession(sessionId);
    if (!ns || !ns->carver) return -1;

    const char* path = env->GetStringUTFChars(jPath, nullptr);
    int filesFound = 0;

    ns->carver->scanFile(path, [&](const CarvedFile& cf) {
        filesFound++;
        invokeResult(env, listener, cf);
    });

    env->ReleaseStringUTFChars(jPath, path);
    return filesFound;
}

JNIEXPORT void JNICALL
Java_com_recoverx_app_MainActivity_runDeepScan(JNIEnv* env, jobject,
                                                jint sessionId, jstring jFolderPath,
                                                jint maxResults, jobject listener) {
    auto ns = getSession(sessionId);
    if (!ns || !ns->session) return;

    const char* folderPath = env->GetStringUTFChars(jFolderPath, nullptr);

    // walk folder
    std::vector<std::string> paths;
    // (simplified: you already have FolderScanner in Dart, but keep for native deep scan if needed)
    // Here we rely on Dart side already sending files via scanFileInSession.
    // For deep scan, we can just set the folder as output dir and let Dart walk.
    // So we do nothing here — Dart will call scanFileInSession for each file.

    env->ReleaseStringUTFChars(jFolderPath, folderPath);
}

JNIEXPORT void JNICALL
Java_com_recoverx_app_MainActivity_stopScanSession(JNIEnv*, jobject, jint sessionId) {
    auto ns = getSession(sessionId);
    if (ns && ns->session) ns->session->stop();
    if (ns && ns->carver) ns->carver->requestStop();
}

JNIEXPORT void JNICALL
Java_com_recoverx_app_MainActivity_releaseCarver(JNIEnv*, jobject, jint sessionId) {
    std::lock_guard<std::mutex> lock(g_sessionsMutex);
    g_sessions.erase(sessionId);
}

} // extern "C"