#ifndef RECOVERX_XXHASH64_H
#define RECOVERX_XXHASH64_H

#include <cstdint>
#include <cstring>

namespace XXHash64 {
    constexpr uint64_t PRIME1 = 0x9E3779B185EBCA87ULL;
    constexpr uint64_t PRIME2 = 0xC2B2AE3D27D4EB4FULL;
    constexpr uint64_t PRIME3 = 0x165667B19E3779F9ULL;
    constexpr uint64_t PRIME4 = 0x85EBCA77C2B2AE63ULL;
    constexpr uint64_t PRIME5 = 0x27D4EB2F165667C5ULL;

    inline uint64_t rotl64(uint64_t x, int r) {
        return (x << r) | (x >> (64 - r));
    }

    inline uint64_t round(uint64_t acc, uint64_t input) {
        acc += input * PRIME2;
        acc = rotl64(acc, 31);
        acc *= PRIME1;
        return acc;
    }

    inline uint64_t hash(const uint8_t* data, size_t len, uint64_t seed = 0) {
        const uint8_t* p = data;
        const uint8_t* end = data + len;
        uint64_t h64;

        if (len >= 32) {
            const uint8_t* limit = end - 32;
            uint64_t v1 = seed + PRIME1 + PRIME2;
            uint64_t v2 = seed + PRIME2;
            uint64_t v3 = seed;
            uint64_t v4 = seed - PRIME1;

            do {
                uint64_t k1, k2, k3, k4;
                memcpy(&k1, p, 8);      p += 8;
                memcpy(&k2, p, 8);      p += 8;
                memcpy(&k3, p, 8);      p += 8;
                memcpy(&k4, p, 8);      p += 8;

                v1 = round(v1, k1);
                v2 = round(v2, k2);
                v3 = round(v3, k3);
                v4 = round(v4, k4);
            } while (p <= limit);

            h64 = rotl64(v1, 1) + rotl64(v2, 7) + rotl64(v3, 12) + rotl64(v4, 18);

            v1 = round(0, v1); h64 ^= v1; h64 = h64 * PRIME1 + PRIME4;
            v2 = round(0, v2); h64 ^= v2; h64 = h64 * PRIME1 + PRIME4;
            v3 = round(0, v3); h64 ^= v3; h64 = h64 * PRIME1 + PRIME4;
            v4 = round(0, v4); h64 ^= v4; h64 = h64 * PRIME1 + PRIME4;
        } else {
            h64 = seed + PRIME5;
        }

        h64 += static_cast<uint64_t>(len);

        while (p + 8 <= end) {
            uint64_t k1;
            memcpy(&k1, p, 8);
            k1 *= PRIME2; k1 = rotl64(k1, 31); k1 *= PRIME1;
            h64 ^= k1;
            h64 = rotl64(h64, 27) * PRIME1 + PRIME4;
            p += 8;
        }

        if (p + 4 <= end) {
            uint32_t k1;
            memcpy(&k1, p, 4);
            h64 ^= static_cast<uint64_t>(k1) * PRIME1;
            h64 = rotl64(h64, 23) * PRIME2 + PRIME3;
            p += 4;
        }

        while (p < end) {
            h64 ^= static_cast<uint64_t>(*p) * PRIME5;
            h64 = rotl64(h64, 11) * PRIME1;
            p++;
        }

        h64 ^= h64 >> 33;
        h64 *= PRIME2;
        h64 ^= h64 >> 29;
        h64 *= PRIME3;
        h64 ^= h64 >> 32;

        return h64;
    }
}

#endif