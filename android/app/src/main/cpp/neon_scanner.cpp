bool findPattern(const uint8_t* buffer, size_t bufferSize, size_t startFrom,
                 const uint8_t* pattern, size_t patternLen, size_t& foundPos) {
    if (bufferSize < patternLen || startFrom + patternLen > bufferSize) return false;

    if (patternLen == 4) {
        return findHeader4(buffer, bufferSize, startFrom, pattern, foundPos);
    }

    // For other lengths (2, 8, etc.), use scalar search.
    // (We avoid findFooter2 to keep its existing semantics intact.)
    for (size_t i = startFrom; i + patternLen <= bufferSize; ++i) {
        if (memcmp(&buffer[i], pattern, patternLen) == 0) {
            foundPos = i;
            return true;
        }
    }
    return false;
}