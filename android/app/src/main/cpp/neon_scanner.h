#ifndef RECOVERX_NEON_SCANNER_H
#define RECOVERX_NEON_SCANNER_H

#include <cstdint>
#include <cstddef>

namespace neon {

// Searches `data[searchFrom..length)` for the first occurrence of `pattern`
// (patternLen bytes, 2 to 8 bytes supported). Returns the absolute index of
// the match, or -1 if not found.
//
// On ARM (with NEON), this is accelerated via SIMD comparison of the first
// byte across 16-byte lanes, followed by scalar verification of the full
// pattern at each candidate. On non-ARM builds (x86 host tests, etc.) a
// scalar fallback is used automatically.
int64_t findPattern(const uint8_t* data, size_t length, size_t searchFrom,
                     const uint8_t* pattern, size_t patternLen);

}  // namespace neon

#endif  // RECOVERX_NEON_SCANNER_H