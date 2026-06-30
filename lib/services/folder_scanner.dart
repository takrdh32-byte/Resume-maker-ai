import 'dart:io';

class FolderScanner {
  // केवल वे फ़ोल्डर जो Android 11+ पर सुरक्षित रूप से एक्सेस किए जा सकते हैं
  static const List<String> _scanFolders = [
    '/storage/emulated/0/DCIM/.thumbnails',
    '/storage/emulated/0/Pictures/.thumbnails',
    '/storage/emulated/0/Download/.thumbnails',
    '/storage/emulated/0/Movies/.thumbnails',
    // यदि ऐप के पास MANAGE_EXTERNAL_STORAGE परमिशन है तो नीचे वाले भी जोड़ सकते हो,
    // लेकिन अभी सुरक्षित रहने के लिए सिर्फ पब्लिक .thumbnails रखते हैं।
  ];

  static const int _maxFileSize = 100 * 1024 * 1024; // 100MB

  static Future<List<File>> collectFiles() async {
    final List<File> allFiles = [];
    for (final folderPath in _scanFolders) {
      try {
        final dir = Directory(folderPath);
        if (await dir.exists()) {
          await _scanRecursive(dir, allFiles);
        }
      } catch (_) {
        // यह फोल्डर एक्सेस नहीं कर सकते – छोड़ो और आगे बढ़ो
      }
    }
    return allFiles;
  }

  static Future<void> _scanRecursive(Directory dir, List<File> collector,
      {int depth = 0}) async {
    if (depth > 10) return;
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          final length = await entity.length();
          if (length > 0 && length <= _maxFileSize) {
            collector.add(entity);
          }
        } else if (entity is Directory) {
          await _scanRecursive(entity, collector, depth: depth + 1);
        }
      }
    } catch (_) {
      // एक्सेस न हो पाने पर छोड़ दो
    }
  }
}