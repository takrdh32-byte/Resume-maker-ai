import 'dart:io';

class FolderScanner {
  static const List<String> _scanFolders = [
    '/storage/emulated/0/DCIM/.thumbnails',
    '/storage/emulated/0/Pictures/.thumbnails',
    '/storage/emulated/0/Download/.thumbnails',
    '/storage/emulated/0/Movies/.thumbnails',
  ];

  static const int _maxFileSize = 100 * 1024 * 1024; // 100MB

  // नया: पहले से रिकवर हो चुकी फ़ाइलों के पथ (excludePaths) के साथ कॉल करो
  static Future<List<File>> collectFiles({Set<String>? excludePaths}) async {
    final List<File> allFiles = [];
    for (final folderPath in _scanFolders) {
      try {
        final dir = Directory(folderPath);
        if (await dir.exists()) {
          await _scanRecursive(dir, allFiles, excludePaths: excludePaths);
        }
      } catch (_) {}
    }
    return allFiles;
  }

  static Future<void> _scanRecursive(Directory dir, List<File> collector,
      {int depth = 0, Set<String>? excludePaths}) async {
    if (depth > 10) return;
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          // अगर यह फ़ाइल पहले ही रिकवर हो चुकी है, तो स्किप करो
          if (excludePaths != null && excludePaths.contains(entity.path)) {
            continue;
          }
          final length = await entity.length();
          if (length > 0 && length <= _maxFileSize) {
            collector.add(entity);
          }
        } else if (entity is Directory) {
          await _scanRecursive(entity, collector, depth: depth + 1, excludePaths: excludePaths);
        }
      }
    } catch (_) {}
  }
}