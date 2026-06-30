#include "neon_scanner.h"
#include <cstring>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    #include <arm_neon.h>
    #define RECOVERX_HAS_NEON 1
#else
    #define RECOVERX_HAS_NEON 0
#endif

namespace NeonScanner {

bool isNeonEnabled() { return RECOVERX_HAS_NEON; }

static bool findHeader4Scalar(const uint8_t* buffer, size_t bufferSize, size_t startFrom,
                               const uint8_t pattern[4], size_t& foundPos) {
    if (startFrom + 4 > bufferSize) return false;
    for (size_t i = startFrom; i + 4 <= bufferSize; i++) {
        if (memcmp(&buffer[i], pattern, 4) == 0) { foundPos = i; return true; }
    }
    return false;
}

static bool findFooter2Scalar(const uint8_t* buffer, size_t bufferSize, size_t startFrom,
                               const uint8_t pattern[2], size_t& foundPos) {
    if (startFrom + 2 > bufferSize) return false;
    for (size_t i = startFrom; i + 2 <= bufferSize; i++) {
        if (buffer[i] == pattern[0] && buffer[i + 1] == pattern[1]) { foundPos = i + 2; return true; }
    }
    return false;
}

#if RECOVERX_HAS_NEON
bool findHeader4(const uint8_t* buffer, size_t bufferSize, size_t startFrom,
                  const uint8_t pattern[4], size_t& foundPos) {
    if (bufferSize < 4 || startFrom + 4 > bufferSize) return false;
    size_t i = startFrom, limit = bufferSize - 4;
    uint8x16_t firstByteVec = vdupq_n_u8(pattern[0]);

    while (i + 16 + 3 <= bufferSize && i <= limit) {
        uint8x16_t chunk = vld1q_u8(&buffer[i]);
        uint8x16_t cmp = vceqq_u8(chunk, firstByteVec);
        uint8_t maskBytes[16];
        vst1q_u8(maskBytes, cmp);
        for (int lane = 0; lane < 16; lane++) {
            if (maskBytes[lane] != 0) {
                size_t candidate = i + lane;
                if (candidate > limit) continue;
                if (buffer[candidate + 1] == pattern[1] &&
                    buffer[candidate + 2] == pattern[2] &&
                    buffer[candidate + 3] == pattern[3]) {
                    foundPos = candidate;
                    return true;
                }
            }
        }
        i += 16;
    }
    return findHeader4Scalar(buffer, bufferSize, i, pattern, foundPos);
}

bool findFooter2(const uint8_t* buffer, size_t bufferSize, size_t startFrom,
                  const uint8_t pattern[2], size_t& foundPos) {
    if (bufferSize < 2 || startFrom + 2 > bufferSize) return false;
    size_t i = startFrom, limit = bufferSize - 2;
    uint8x16_t firstByteVec = vdupq_n_u8(pattern[0]);
    while (i + 16 + 1 <= bufferSize && i <= limit) {
        uint8x16_t chunk = vld1q_u8(&buffer[i]);
        uint8x16_t cmp = vceqq_u8(chunk, firstByteVec);
        uint8_t maskBytes[16];
        vst1q_u8(maskBytes, cmp);
        for (int lane = 0; lane < 16; lane++) {
            if (maskBytes[lane] != 0) {
                size_t candidate = i + lane;
                if (candidate > limit) continue;
                if (buffer[candidate + 1] == pattern[1]) { foundPos = candidate + 2; return true; }
            }
        }
        i += 16;
    }
    return findFooter2Scalar(buffer, bufferSize, i, pattern, foundPos);
}
#else
bool findHeader4(...) { return findHeader4Scalar(...); }
bool findFooter2(...) { return findFooter2Scalar(...); }
#endif

} // namespace