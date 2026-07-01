#include "neon_scanner.h"
#include <cstring>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    #include <arm_neon.h>
    #define RECOVERX_HAS_NEON 1
#else
    #define RECOVERX_HAS_NEON 0
#endif

namespace neon {

int64_t findPattern(const uint8_t* data, size_t length, size_t searchFrom,
                     const uint8_t* pattern, size_t patternLen) {
    if (data == nullptr || pattern == nullptr) return -1;
    if (patternLen < 2 || patternLen > 16) return -1;  // हम 2–16 बाइट सपोर्ट करते हैं
    if (searchFrom + patternLen > length) return -1;

#if RECOVERX_HAS_NEON
    // NEON-त्वरित खोज: पहले बाइट को 16 लेन में चेक करो
    const uint8_t firstByte = pattern[0];
    const size_t limit = length - patternLen;

    size_t i = searchFrom;
    while (i + 16 + patternLen <= length && i <= limit) {
        uint8x16_t chunk = vld1q_u8(&data[i]);
        uint8x16_t cmp = vceqq_u8(chunk, vdupq_n_u8(firstByte));

        // मास्क से 16 लेन का परिणाम निकालो
        uint8_t maskBytes[16];
        vst1q_u8(maskBytes, cmp);

        for (int lane = 0; lane < 16; ++lane) {
            if (maskBytes[lane] != 0) {
                size_t candidate = i + lane;
                if (candidate > limit) continue;
                // पूरे पैटर्न का स्केलर वेरिफिकेशन
                bool match = true;
                for (size_t k = 0; k < patternLen; ++k) {
                    if (data[candidate + k] != pattern[k]) {
                        match = false;
                        break;
                    }
                }
                if (match) return static_cast<int64_t>(candidate);
            }
        }
        i += 16;
    }

    // बचे हुए बाइट्स के लिए स्केलर फ़ॉलबैक
    for (; i <= limit; ++i) {
        if (memcmp(&data[i], pattern, patternLen) == 0) {
            return static_cast<int64_t>(i);
        }
    }
    return -1;
#else
    // स्केलर इम्प्लीमेंटेशन (x86, एमुलेटर, आदि)
    for (size_t i = searchFrom; i + patternLen <= length; ++i) {
        if (memcmp(&data[i], pattern, patternLen) == 0) {
            return static_cast<int64_t>(i);
        }
    }
    return -1;
#endif
}

}  // namespace neon