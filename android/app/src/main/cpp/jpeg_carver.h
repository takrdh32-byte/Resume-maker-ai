#ifndef RECOVERX_JPEG_CARVER_H
#define RECOVERX_JPEG_CARVER_H

#include <string>
#include <vector>
#include <unordered_set>
#include <cstdint>
#include <cstdio>
#include <functional>
#include "neon_scanner.h"

struct CarvedFile {
    std::string outputPath;
    size_t startOffset;
    size_t endOffset;
    size_t fileSize;
};

using CarvedFileCallback = std::function<void(const CarvedFile&)>;

enum class StreamChunkTier {
    LOW_RAM,
    MID_RAM,
    HIGH_RAM
};

class JpegCarver {
public:
    explicit JpegCarver(const std::string& outputDir,
                         StreamChunkTier tier = StreamChunkTier::HIGH_RAM);

    std::vector<CarvedFile> scanFile(const std::string& sourcePath,
                                      CarvedFileCallback onFound = nullptr);

    std::vector<CarvedFile> scanStream(FILE* stream, size_t totalSize,
                                        CarvedFileCallback onFound = nullptr);

    int recoveredCount() const { return fileCounter_; }

private:
    std::string outputDir_;
    std::unordered_set<uint64_t> recoveredHashes_;
    int fileCounter_ = 0;
    size_t streamChunkSize_;

    uint64_t computeHash(const uint8_t* data, size_t length);
    bool isDuplicate(uint64_t hash);
    bool saveFragment(const uint8_t* data, size_t length, std::string& outPathOut);

    std::vector<CarvedFile> carveBuffer(const uint8_t* data, size_t bufferSize,
                                         CarvedFileCallback onFound,
                                         size_t globalOffset = 0);
};

#endif // RECOVERX_JPEG_CARVER_H