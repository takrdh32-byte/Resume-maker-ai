#include "media_carver.h"
#include "neon_scanner.h"
#include "xxhash64.h"

#include <fstream>
#include <algorithm>
#include <thread>
#include <chrono>
#include <cstring>

namespace recoverx {

// ============================================================================
// MemoryPool
// ============================================================================
MemoryPool::MemoryPool(size_t bufferSize, size_t poolCount)
    : bufferSize_(bufferSize) {
    owned_.reserve(poolCount);
    free_.reserve(poolCount);
    for (size_t i = 0; i < poolCount; ++i) {
        auto buf = std::make_unique<uint8_t[]>(bufferSize_);
        free_.push_back(buf.get());
        owned_.push_back(std::move(buf));
    }
}

MemoryPool::~MemoryPool() = default;

uint8_t* MemoryPool::acquire() {
    for (int attempt = 0; attempt < 200; ++attempt) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (!free_.empty()) {
                uint8_t* buf = free_.back();
                free_.pop_back();
                return buf;
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(5));
    }
    auto buf = std::make_unique<uint8_t[]>(bufferSize_);
    uint8_t* raw = buf.get();
    std::lock_guard<std::mutex> lock(mutex_);
    owned_.push_back(std::move(buf));
    return raw;
}

void MemoryPool::release(uint8_t* buffer) {
    std::lock_guard<std::mutex> lock(mutex_);
    free_.push_back(buffer);
}

// ============================================================================
// HashRegistry
// ============================================================================
bool HashRegistry::insertIfNew(uint64_t hash) {
    std::lock_guard<std::mutex> lock(mutex_);
    return seen_.insert(hash).second;
}

size_t HashRegistry::size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return seen_.size();
}

// ============================================================================
// Signature constants
// ============================================================================
static const uint8_t kJpegHeaderVariants[][4] = {
    {0xFF, 0xD8, 0xFF, 0xE0},
    {0xFF, 0xD8, 0xFF, 0xE1},
    {0xFF, 0xD8, 0xFF, 0xDB},
    {0xFF, 0xD8, 0xFF, 0xC0},
    {0xFF, 0xD8, 0xFF, 0xC2},
};
static const uint8_t kJpegFooter[2] = {0xFF, 0xD9};

static const uint8_t kPngHeader[8] = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
static const uint8_t kPngFooterTag[4] = {'I', 'E', 'N', 'D'};

static const uint8_t kFtypTag[4] = {'f', 't', 'y', 'p'};
static const uint8_t kMoovTag[4] = {'m', 'o', 'o', 'v'};

// ============================================================================
// MediaCarver
// ============================================================================
MediaCarver::MediaCarver(size_t maxFileSizeBytes)
    : maxFileSizeBytes_(maxFileSizeBytes),
      pool_(8 * 1024 * 1024, std::max(2u, std::thread::hardware_concurrency())) {}

MediaCarver::~MediaCarver() = default;

void MediaCarver::enableType(MediaType type, bool enabled) {
    switch (type) {
        case MediaType::JPEG: jpegEnabled_ = enabled; break;
        case MediaType::PNG:  pngEnabled_  = enabled; break;
        case MediaType::MP4:  mp4Enabled_  = enabled; break;
        default: break;
    }
}

CarveError MediaCarver::scanFile(const std::string& path,
                                  const CarveResultCallback& onResult) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        return CarveError::PERMISSION_DENIED;
    }
    std::streamsize size = file.tellg();
    if (size <= 0) return CarveError::IO_ERROR;
    if (static_cast<size_t>(size) > maxFileSizeBytes_) {
        return CarveError::FILE_TOO_LARGE;
    }
    file.seekg(0, std::ios::beg);

    uint8_t* buffer = pool_.acquire();
    size_t toRead = std::min(static_cast<size_t>(size), pool_.bufferSize());
    if (!file.read(reinterpret_cast<char*>(buffer), toRead)) {
        pool_.release(buffer);
        return CarveError::IO_ERROR;
    }

    CarveError err = carveBuffer(buffer, toRead, 0, onResult);
    pool_.release(buffer);
    return err;
}

CarveError MediaCarver::carveBuffer(const uint8_t* data, size_t length,
                                     size_t globalOffset,
                                     const CarveResultCallback& onResult) {
    if (isStopRequested()) return CarveError::CANCELLED;
    if (data == nullptr || length == 0) return CarveError::IO_ERROR;

    size_t cursor = 0;
    while (cursor < length) {
        if (isStopRequested()) return CarveError::CANCELLED;

        size_t advanced = 0;
        if (jpegEnabled_) {
            advanced = extractJpeg(data, length, cursor, onResult, globalOffset);
            if (advanced) { cursor += advanced; continue; }
        }
        if (pngEnabled_) {
            advanced = extractPng(data, length, cursor, onResult, globalOffset);
            if (advanced) { cursor += advanced; continue; }
        }
        if (mp4Enabled_) {
            advanced = extractMp4(data, length, cursor, onResult, globalOffset);
            if (advanced) { cursor += advanced; continue; }
        }
        cursor++;
    }
    return CarveError::NONE;
}

size_t MediaCarver::extractJpeg(const uint8_t* data, size_t length, size_t start,
                                 const CarveResultCallback& onResult, size_t globalOffset) {
    for (const auto& hdr : kJpegHeaderVariants) {
        int64_t pos = neon::findPattern(data, length, start, hdr, 4);
        if (pos != static_cast<int64_t>(start)) continue;   // header must be exactly at cursor

        int64_t footerPos = neon::findPattern(data, length, start + 4, kJpegFooter, 2);
        if (footerPos < 0) return 0;

        size_t end = static_cast<size_t>(footerPos) + 2;
        size_t fileLen = end - start;

        CarvedFile cf;
        cf.type = MediaType::JPEG;
        cf.data.assign(data + start, data + end);
        cf.hash = XXHash64::hash(cf.data.data(), cf.data.size(), 0);
        cf.offsetInSource = globalOffset + start;

        if (hashRegistry().insertIfNew(cf.hash)) {
            onResult(cf);
        }
        return fileLen;
    }
    return 0;
}

size_t MediaCarver::extractPng(const uint8_t* data, size_t length, size_t start,
                                const CarveResultCallback& onResult, size_t globalOffset) {
    int64_t pos = neon::findPattern(data, length, start, kPngHeader, 8);
    if (pos != static_cast<int64_t>(start)) return 0;

    int64_t iendPos = neon::findPattern(data, length, start + 8, kPngFooterTag, 4);
    if (iendPos < 0) return 0;

    size_t end = static_cast<size_t>(iendPos) + 4 + 4;   // IEND chunk total length
    if (end > length) return 0;

    CarvedFile cf;
    cf.type = MediaType::PNG;
    cf.data.assign(data + start, data + end);
    cf.hash = XXHash64::hash(cf.data.data(), cf.data.size(), 0);
    cf.offsetInSource = globalOffset + start;

    if (hashRegistry().insertIfNew(cf.hash)) {
        onResult(cf);
    }
    return end - start;
}

size_t MediaCarver::extractMp4(const uint8_t* data, size_t length, size_t start,
                                const CarveResultCallback& onResult, size_t globalOffset) {
    // ftyp box: [4-byte size][ 'f' 't' 'y' 'p' ][4-byte brand]
    int64_t tagPos = neon::findPattern(data, length, start + 4, kFtypTag, 4);
    if (tagPos != static_cast<int64_t>(start + 4)) return 0;
    if (start < 4) return 0;

    uint32_t boxSize = (static_cast<uint32_t>(data[start]) << 24) |
                        (static_cast<uint32_t>(data[start + 1]) << 16) |
                        (static_cast<uint32_t>(data[start + 2]) << 8) |
                         static_cast<uint32_t>(data[start + 3]);
    if (boxSize == 0 || boxSize > length - start) {
        return 0;
    }

    size_t searchFrom = start + boxSize;
    size_t end = start + boxSize;
    if (searchFrom < length) {
        int64_t moovPos = neon::findPattern(data, length, searchFrom, kMoovTag, 4);
        if (moovPos >= 0) {
            size_t extended = std::min(length, static_cast<size_t>(moovPos) + 4096);
            end = std::max(end, extended);
        }
    }

    CarvedFile cf;
    cf.type = MediaType::MP4;
    cf.data.assign(data + start, data + end);
    cf.hash = XXHash64::hash(cf.data.data(), cf.data.size(), 0);
    cf.offsetInSource = globalOffset + start;

    if (hashRegistry().insertIfNew(cf.hash)) {
        onResult(cf);
    }
    return end - start;
}

// ============================================================================
// CarveSession — multithreaded orchestration
// ============================================================================
CarveSession::CarveSession(size_t maxFileSizeBytes, unsigned threadCount)
    : carver_(maxFileSizeBytes) {
    threadCount_ = threadCount ? threadCount
                                : std::max(2u, std::thread::hardware_concurrency() / 2);
}

void CarveSession::setFiles(std::vector<std::string> paths) {
    files_ = std::move(paths);
    std::stable_sort(files_.begin(), files_.end(),
        [](const std::string& a, const std::string& b) {
            std::ifstream fa(a, std::ios::binary | std::ios::ate);
            std::ifstream fb(b, std::ios::binary | std::ios::ate);
            auto sa = fa.is_open() ? static_cast<int64_t>(fa.tellg()) : -1;
            auto sb = fb.is_open() ? static_cast<int64_t>(fb.tellg()) : -1;
            if (sa < 0 || sb < 0) return false;
            return sa < sb;
        });
}

void CarveSession::run(const CarveResultCallback& onResult,
                        const ProgressCallback& onProgress) {
    carver_.reset();
    std::atomic<size_t> nextIndex{0};
    std::atomic<uint64_t> filesScanned{0};
    std::atomic<uint64_t> bytesProcessed{0};
    std::atomic<uint64_t> filesRecovered{0};

    uint64_t totalEstimate = 0;
    for (auto& p : files_) {
        std::ifstream f(p, std::ios::binary | std::ios::ate);
        if (f.is_open()) totalEstimate += static_cast<uint64_t>(f.tellg());
    }

    std::mutex resultMutex;
    auto workerResult = [&](const CarvedFile& cf) {
        filesRecovered.fetch_add(1);
        std::lock_guard<std::mutex> lock(resultMutex);
        onResult(cf);
    };

    auto worker = [&]() {
        while (true) {
            if (carver_.isStopRequested()) return;
            size_t idx = nextIndex.fetch_add(1);
            if (idx >= files_.size()) return;

            const std::string& path = files_[idx];
            std::ifstream f(path, std::ios::binary | std::ios::ate);
            uint64_t sz = f.is_open() ? static_cast<uint64_t>(f.tellg()) : 0;

            carver_.scanFile(path, workerResult);

            filesScanned.fetch_add(1);
            bytesProcessed.fetch_add(sz);
        }
    };

    auto start = std::chrono::steady_clock::now();
    std::vector<std::thread> pool;
    for (unsigned i = 0; i < threadCount_; ++i) pool.emplace_back(worker);

    while (std::any_of(pool.begin(), pool.end(), [](std::thread& t) { return t.joinable(); })) {
        bool allDone = filesScanned.load() >= files_.size() || carver_.isStopRequested();

        auto now = std::chrono::steady_clock::now();
        double elapsed = std::chrono::duration<double>(now - start).count();
        double rate = bytesProcessed.load() / std::max(0.001, elapsed);
        double remainingBytes = totalEstimate > bytesProcessed.load()
            ? static_cast<double>(totalEstimate - bytesProcessed.load()) : 0.0;
        double eta = rate > 0 ? remainingBytes / rate : 0.0;

        onProgress(ScanProgress{
            filesScanned.load(), bytesProcessed.load(),
            totalEstimate, filesRecovered.load(), eta
        });

        if (allDone) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }

    for (auto& t : pool) if (t.joinable()) t.join();

    onProgress(ScanProgress{
        filesScanned.load(), bytesProcessed.load(),
        totalEstimate, filesRecovered.load(), 0.0
    });
}

void CarveSession::stop() {
    carver_.requestStop();
}

}  // namespace recoverx