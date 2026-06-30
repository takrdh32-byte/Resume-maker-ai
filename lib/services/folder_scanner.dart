import 'dart:io';

class FolderScanner {
  static const List<String> _scanFolders = [
    '/storage/emulated/0/DCIM/.thumbnails',
    '/storage/emulated/0/Pictures/.thumbnails',
    '/storage/emulated/0/Android/data/com.whatsapp/cache',
    '/storage/emulated/0/Android/data/com.google.android.apps.photos/cache',
    '/storage/emulated/0/Android/data/com.android.providers.media/cache',
    '/storage/emulated/0/Android/data/com.facebook.katana/cache',
    '/storage/emulated/0/Android/data/com.instagram.android/cache',
    '/storage/emulated/0/Android/data/com.snapchat.android/cache',
  ];

  static const int _maxFileSize = 100 * 1024 * 1024;

  static Future<List<File>> collectFiles() async {
    final List<File> allFiles = [];
    for (final folderPath in _scanFolders) {
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        await _scanRecursive(dir, allFiles);
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
    } catch (_) {}
  }
}