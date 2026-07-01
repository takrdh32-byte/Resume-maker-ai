import 'dart:io';

class FolderScanner {
  // पहली प्राथमिकता: छुपे हुए थंबनेल कैश
  static const List<String> _primaryFolders = [
    '/storage/emulated/0/DCIM/.thumbnails',
    '/storage/emulated/0/Pictures/.thumbnails',
  ];

  // फ़ॉलबैक: पब्लिक फ़ोल्डर जहाँ छोटे थंबनेल/अवशेष हो सकते हैं
  static const List<String> _fallbackFolders = [
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/Download',
  ];

  static const int _maxFileSize = 100 * 1024 * 1024; // 100MB
  static const int _smallFileSize = 500 * 1024;      // 500KB (सिर्फ़ छोटी फ़ाइलें)

  static Future<List<File>> collectFiles({Set<String>? excludePaths}) async {
    // पहले प्राइमरी फ़ोल्डर स्कैन करो (सभी साइज़)
    final List<File> allFiles = [];
    for (final folderPath in _primaryFolders) {
      try {
        final dir = Directory(folderPath);
        if (await dir.exists()) {
          await _scanRecursive(dir, allFiles, excludePaths: excludePaths, sizeLimit: _maxFileSize);
        }
      } catch (_) {}
    }

    // अगर कुछ न मिला, तो फ़ॉलबैक फ़ोल्डर से सिर्फ़ छोटी फ़ाइलें लो
    if (allFiles.isEmpty) {
      for (final folderPath in _fallbackFolders) {
        try {
          final dir = Directory(folderPath);
          if (await dir.exists()) {
            await _scanRecursive(dir, allFiles, excludePaths: excludePaths, sizeLimit: _smallFileSize);
          }
        } catch (_) {}
      }
    }

    return allFiles;
  }

  static Future<void> _scanRecursive(Directory dir, List<File> collector,
      {int depth = 0, Set<String>? excludePaths, required int sizeLimit}) async {
    if (depth > 10) return;
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          if (excludePaths != null && excludePaths.contains(entity.path)) continue;
          final length = await entity.length();
          if (length > 0 && length <= sizeLimit) {
            collector.add(entity);
          }
        } else if (entity is Directory) {
          await _scanRecursive(entity, collector, depth: depth + 1, excludePaths: excludePaths, sizeLimit: sizeLimit);
        }
      }
    } catch (_) {}
  }
}