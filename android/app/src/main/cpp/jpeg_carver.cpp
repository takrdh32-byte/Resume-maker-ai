#include "jpeg_carver.h"
#include "xxhash64.h"
#include <fstream>
#include <cstring>
#include <cstdio>
#include <algorithm>
#include <climits>
#include <android/log.h>

#define LOG_TAG "JpegCarver"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// JPEG headers
static const uint8_t HEADER_E0[4] = {0xFF, 0xD8, 0xFF, 0xE0};
static const uint8_t HEADER_E1[4] = {0xFF, 0xD8, 0xFF, 0xE1};
static const uint8_t HEADER_DB[4] = {0xFF, 0xD8, 0xFF, 0xDB};
static const uint8_t HEADER_C0[4] = {0xFF, 0xD8, 0xFF, 0xC0};
static const uint8_t HEADER_C2[4] = {0xFF, 0xD8, 0xFF, 0xC2};
static const uint8_t FOOTER_JPEG[2] = {0xFF, 0xD9};

// PNG header and IEND chunk (simplified footer)
static const uint8_t HEADER_PNG[4] = {0x89, 0x50, 0x4E, 0x47}; // .PNG
static const uint8_t FOOTER_PNG[8] = {0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82}; // IEND

constexpr size_t MAX_JPEG_SIZE = 10 * 1024 * 1024;
constexpr size_t MAX_PNG_SIZE  = 20 * 1024 * 1024;
constexpr size_t MIN_JPEG_SIZE = 200;
constexpr size_t MIN_PNG_SIZE  = 128;

static size_t chunkSizeForTier(StreamChunkTier tier) {
    switch (tier) {
        case StreamChunkTier::LOW_RAM:  return 16 * 1024 * 1024;
        case StreamChunkTier::MID_RAM:  return 32 * 1024 * 1024;
        case StreamChunkTier::HIGH_RAM:
        default:                        return 64 * 1024 * 1024;
    }
}

JpegCarver::JpegCarver(const std::string& outputDir, StreamChunkTier tier)
    : outputDir_(outputDir), streamChunkSize_(chunkSizeForTier(tier)) {
    LOGI("JpegCarver init: streamChunkSize=%zu bytes (tier=%d)",
         streamChunkSize_, static_cast<int>(tier));
}

uint64_t JpegCarver::computeHash(const uint8_t* data, size_t length) {
    return XXHash64::hash(data, length);
}

bool JpegCarver::isDuplicate(uint64_t hash) {
    return recoveredHashes_.find(hash) != recoveredHashes_.end();
}

bool JpegCarver::saveFragment(const uint8_t* data, size_t length, std::string& outPathOut, bool isJPEG) {
    fileCounter_++;
    outPathOut = outputDir_ + "/recovered_" + std::to_string(fileCounter_) + (isJPEG ? ".jpg" : ".png");

    std::ofstream outFile(outPathOut, std::ios::binary);
    if (!outFile.is_open()) {
        LOGE("saveFragment: failed to open %s", outPathOut.c_str());
        fileCounter_--;
        return false;
    }

    outFile.write(reinterpret_cast<const char*>(data), static_cast<std::streamsize>(length));
    bool writeOk = outFile.good();
    outFile.close();

    if (!writeOk) {
        LOGE("saveFragment: write failed for %s, cleaning up", outPathOut.c_str());
        std::remove(outPathOut.c_str());
        fileCounter_--;
        outPathOut.clear();
        return false;
    }
    return true;
}

// Find earliest header (JPEG or PNG) and set isJPEG accordingly
static bool findEarliestHeader(const uint8_t* buffer, size_t bufferSize, size_t from,
                               size_t& headerPos, bool& isJPEG) {
    size_t bestPos = SIZE_MAX;
    size_t pos;
    bool typeJPEG = true;

    auto check = [&](const uint8_t* pattern, bool jpeg) {
        if (NeonScanner::findHeader4(buffer, bufferSize, from, pattern, pos)) {
            if (pos < bestPos) { bestPos = pos; typeJPEG = jpeg; }
        }
    };

    check(HEADER_E0, true);
    check(HEADER_E1, true);
    check(HEADER_DB, true);
    check(HEADER_C0, true);
    check(HEADER_C2, true);
    check(HEADER_PNG, false);   // PNG header

    if (bestPos == SIZE_MAX) return false;
    headerPos = bestPos;
    isJPEG = typeJPEG;
    return true;
}

// Find footer based on image type
static bool findFooter(const uint8_t* buffer, size_t bufferSize, size_t startFrom,
                       bool isJPEG, size_t& footerPos) {
    if (isJPEG) {
        return NeonScanner::findFooter2(buffer, bufferSize, startFrom, FOOTER_JPEG, footerPos);
    } else {
        // PNG IEND chunk search (simplified)
        size_t pos;
        if (NeonScanner::findHeader4(buffer, bufferSize, startFrom, FOOTER_PNG, pos)) {
            footerPos = pos + 12; // IEND chunk total length
            return true;
        }
        // scalar fallback
        for (size_t i = startFrom; i + 8 <= bufferSize; i++) {
            if (memcmp(&buffer[i], FOOTER_PNG, 8) == 0) {
                footerPos = i + 12;
                return true;
            }
        }
        return false;
    }
}

std::vector<CarvedFile> JpegCarver::carveBuffer(const uint8_t* data, size_t bufferSize,
                                                 CarvedFileCallback onFound,
                                                 size_t globalOffset) {
    std::vector<CarvedFile> results;
    if (data == nullptr || bufferSize < 4) return results;

    size_t cursor = 0;
    while (cursor < bufferSize) {
        size_t headerPos = 0;
        bool isJPEG = true;
        if (!findEarliestHeader(data, bufferSize, cursor, headerPos, isJPEG)) break;

        size_t footerPos = 0;
        if (!findFooter(data, bufferSize, headerPos + 4, isJPEG, footerPos)) {
            cursor = headerPos + 4;
            continue;
        }

        size_t fragmentLength = footerPos - headerPos;
        size_t maxSize = isJPEG ? MAX_JPEG_SIZE : MAX_PNG_SIZE;
        size_t minSize = isJPEG ? MIN_JPEG_SIZE : MIN_PNG_SIZE;

        if (fragmentLength < minSize || fragmentLength > maxSize) {
            cursor = headerPos + 1;
            continue;
        }

        const uint8_t* fragmentData = &data[headerPos];
        uint64_t hash = computeHash(fragmentData, fragmentLength);

        if (!isDuplicate(hash)) {
            std::string outPath;
            if (saveFragment(fragmentData, fragmentLength, outPath, isJPEG)) {
                recoveredHashes_.insert(hash);

                CarvedFile cf;
                cf.outputPath = outPath;
                cf.startOffset = globalOffset + headerPos;
                cf.endOffset = globalOffset + footerPos;
                cf.fileSize = fragmentLength;
                results.push_back(cf);

                LOGI("Recovered #%d: %s (%zu bytes, offset=%zu, hash=%llx)",
                     fileCounter_, outPath.c_str(), fragmentLength, cf.startOffset,
                     (unsigned long long)hash);

                if (onFound) onFound(cf);
            }
        }

        cursor = footerPos;
    }
    return results;
}

std::vector<CarvedFile> JpegCarver::scanFile(const std::string& sourcePath,
                                              CarvedFileCallback onFound) {
    std::vector<CarvedFile> results;
    std::ifstream inFile(sourcePath, std::ios::binary);
    if (!inFile.is_open()) {
        LOGE("scanFile: cannot open %s", sourcePath.c_str());
        return results;
    }
    std::vector<uint8_t> data((std::istreambuf_iterator<char>(inFile)),
                                std::istreambuf_iterator<char>());
    inFile.close();
    if (data.empty()) {
        LOGE("scanFile: empty source %s", sourcePath.c_str());
        return results;
    }
    LOGI("scanFile: scanning %s (%zu bytes), NEON=%s",
         sourcePath.c_str(), data.size(), NeonScanner::isNeonEnabled() ? "ON" : "OFF");
    return carveBuffer(data.data(), data.size(), onFound, 0);
}

std::vector<CarvedFile> JpegCarver::scanStream(FILE* stream, size_t totalSize,
                                                CarvedFileCallback onFound) {
    std::vector<CarvedFile> allResults;
    if (stream == nullptr || totalSize == 0) return allResults;

    const size_t overlap = MAX_JPEG_SIZE; // use JPEG size for overlap
    std::vector<uint8_t> buffer(streamChunkSize_ + overlap);
    size_t bytesReadTotal = 0, carryOver = 0;

    LOGI("scanStream: starting, totalSize=%zu, chunkSize=%zu, overlap=%zu, NEON=%s",
         totalSize, streamChunkSize_, overlap, NeonScanner::isNeonEnabled() ? "ON" : "OFF");

    while (bytesReadTotal < totalSize) {
        size_t spaceAvailable = buffer.size() - carryOver;
        size_t remaining = totalSize - bytesReadTotal;
        size_t toRead = std::min(spaceAvailable, remaining);

        clearerr(stream);
        size_t actuallyRead = fread(buffer.data() + carryOver, 1, toRead, stream);
        if (actuallyRead == 0) {
            if (feof(stream)) LOGI("scanStream: EOF at %zu/%zu bytes", bytesReadTotal, totalSize);
            else LOGE("scanStream: fread I/O error");
            break;
        }
        if (ferror(stream)) LOGE("scanStream: fread partial error");

        size_t chunkSize = carryOver + actuallyRead;
        bool isLastChunk = (bytesReadTotal + actuallyRead) >= totalSize;
        size_t chunkGlobalStart = bytesReadTotal - carryOver;

        auto chunkResults = carveBuffer(buffer.data(), chunkSize, onFound, chunkGlobalStart);
        allResults.insert(allResults.end(), chunkResults.begin(), chunkResults.end());
        bytesReadTotal += actuallyRead;

        if (isLastChunk) break;
        if (chunkSize > overlap) {
            carryOver = overlap;
            memmove(buffer.data(), buffer.data() + (chunkSize - overlap), overlap);
        } else carryOver = chunkSize;
    }

    LOGI("scanStream complete. Bytes read: %zu/%zu, unique images: %zu",
         bytesReadTotal, totalSize, allResults.size());
    return allResults;
}