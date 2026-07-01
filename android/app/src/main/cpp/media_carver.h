#ifndef RECOVERX_MEDIA_CARVER_H
#define RECOVERX_MEDIA_CARVER_H

#include <cstdint>
#include <cstddef>
#include <string>
#include <vector>
#include <unordered_set>
#include <mutex>
#include <memory>
#include <atomic>
#include <functional>

namespace recoverx {

// ---------------------------------------------------------------------------
// Supported media types
// ---------------------------------------------------------------------------
enum class MediaType : uint8_t {
    JPEG = 0,
    PNG  = 1,
    MP4  = 2,
    UNKNOWN = 255
};

// A single carved-out result, ready to be handed back to Dart/Kotlin.
struct CarvedFile {
    MediaType   type;
    std::vector<uint8_t> data;
    uint64_t    hash;       // xxhash64 of data, used for de-dup
    size_t      offsetInSource;
};

// Callback invoked every time a file is successfully carved.
using CarveResultCallback = std::function<void(const CarvedFile&)>;

// Callback invoked periodically to report progress back to Flutter.
struct ScanProgress {
    uint64_t filesScanned;
    uint64_t bytesProcessed;
    uint64_t totalBytesEstimate;
    uint64_t filesRecovered;
    double   etaSeconds;
};
using ProgressCallback = std::function<void(const ScanProgress&)>;

// Error codes surfaced across the JNI boundary.
enum class CarveError : int32_t {
    NONE = 0,
    PERMISSION_DENIED = 1,
    FILE_TOO_LARGE = 2,
    UNSUPPORTED_FORMAT = 3,
    IO_ERROR = 4,
    OUT_OF_MEMORY = 5,
    CANCELLED = 6
};

// ---------------------------------------------------------------------------
// Fixed-size, thread-safe memory pool so repeated scans don't thrash the
// allocator on low-RAM devices. Buffers are checked out and returned.
// ---------------------------------------------------------------------------
class MemoryPool {
public:
    explicit MemoryPool(size_t bufferSize = 8 * 1024 * 1024, size_t poolCount = 4);
    ~MemoryPool();

    // Blocks (briefly) if all buffers are checked out.
    uint8_t* acquire();
    void release(uint8_t* buffer);
    size_t bufferSize() const { return bufferSize_; }

private:
    size_t bufferSize_;
    std::mutex mutex_;
    std::vector<uint8_t*> free_;
    std::vector<std::unique_ptr<uint8_t[]>> owned_;
};

// ---------------------------------------------------------------------------
// Thread-safe de-dup set, shared across worker threads within one session.
// ---------------------------------------------------------------------------
class HashRegistry {
public:
    bool insertIfNew(uint64_t hash);
    size_t size() const;

private:
    mutable std::mutex mutex_;
    std::unordered_set<uint64_t> seen_;
};

// ---------------------------------------------------------------------------
// MediaCarver: the core engine. One instance == one scan session.
// Supports carving from an in-memory buffer (carveBuffer) or a whole file
// (scanFile). Multiple threads may call carveBuffer concurrently as long as
// each thread uses its own scratch buffer from the shared MemoryPool.
// ---------------------------------------------------------------------------
class MediaCarver {
public:
    explicit MediaCarver(size_t maxFileSizeBytes = 64 * 1024 * 1024);
    ~MediaCarver();

    // Pluggable signature registration (JPEG/PNG/MP4 registered by default).
    void enableType(MediaType type, bool enabled);

    // Scan one whole file from disk. Thread-safe.
    CarveError scanFile(const std::string& path,
                         const CarveResultCallback& onResult);

    // Scan an already-loaded buffer (e.g. mmap'd SAF stream chunk).
    CarveError carveBuffer(const uint8_t* data, size_t length,
                            size_t globalOffset,
                            const CarveResultCallback& onResult);

    // Cooperative cancellation - safe to call from any thread.
    void requestStop() { stopRequested_.store(true); }
    bool isStopRequested() const { return stopRequested_.load(); }
    void reset() { stopRequested_.store(false); }

    HashRegistry& hashRegistry() { return hashes_; }
    MemoryPool& memoryPool() { return pool_; }

private:
    bool jpegEnabled_ = true;
    bool pngEnabled_  = true;
    bool mp4Enabled_  = true;

    size_t maxFileSizeBytes_;
    std::atomic<bool> stopRequested_{false};
    HashRegistry hashes_;
    MemoryPool pool_;

    // Format-specific extraction helpers (implemented in .cpp)
    size_t extractJpeg(const uint8_t* data, size_t length, size_t start,
                        const CarveResultCallback& onResult, size_t globalOffset);
    size_t extractPng(const uint8_t* data, size_t length, size_t start,
                       const CarveResultCallback& onResult, size_t globalOffset);
    size_t extractMp4(const uint8_t* data, size_t length, size_t start,
                       const CarveResultCallback& onResult, size_t globalOffset);
};

// ---------------------------------------------------------------------------
// Multi-threaded session wrapper used by native-lib.cpp. Splits a list of
// file paths across a small thread pool, sized to the device's core count.
// ---------------------------------------------------------------------------
class CarveSession {
public:
    CarveSession(size_t maxFileSizeBytes, unsigned threadCount = 0);

    // Adds paths, small files first (caller should pre-sort, but this also
    // stable-sorts by size as a safety net).
    void setFiles(std::vector<std::string> paths);

    void run(const CarveResultCallback& onResult,
             const ProgressCallback& onProgress);

    void stop();

private:
    MediaCarver carver_;
    std::vector<std::string> files_;
    unsigned threadCount_;
};

}  // namespace recoverx

#endif  // RECOVERX_MEDIA_CARVER_H
