#ifndef RECOVERX_NEON_SCANNER_H
#define RECOVERX_NEON_SCANNER_H

#include <cstdint>
#include <cstddef>

namespace NeonScanner {

    bool findHeader4(const uint8_t* buffer, size_t bufferSize, size_t startFrom,
                     const uint8_t pattern[4], size_t& foundPos);
    bool findFooter2(const uint8_t* buffer, size_t bufferSize, size_t startFrom,
                     const uint8_t pattern[2], size_t& foundPos);
    bool isNeonEnabled();

    // Generic pattern search — variable length (2 to 16 bytes)
    bool findPattern(const uint8_t* buffer, size_t bufferSize, size_t startFrom,
                     const uint8_t* pattern, size_t patternLen, size_t& foundPos);

}

#endif