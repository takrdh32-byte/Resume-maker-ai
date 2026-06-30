// 📄 lib/services/folder_scanner.dart
import 'dart:io';

class FolderScanner {
  // ये वो सभी पब्लिक फोल्डर हैं जहाँ आमतौर पर फ़ोटो/वीडियो रहते हैं
  static const List<String> _scanFolders = [
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/WhatsApp/Media',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media',
    '/storage/emulated/0/Telegram/Telegram Images',
    '/storage/emulated/0/Snapchat',
    '/storage/emulated/0/Movies',
  ];

  // हर फोल्डर को रीकर्सिवली घूमता है और सभी फ़ाइलों की लिस्ट बनाता है
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

  // फोल्डर के अंदर घुसकर सभी फ़ाइलें इकट्ठा करता है (10 लेवल तक)
  static Future<void> _scanRecursive(Directory dir, List<File> collector,
      {int depth = 0}) async {
    if (depth > 10) return; // बहुत गहराई में मत जाओ
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          collector.add(entity);
        } else if (entity is Directory) {
          await _scanRecursive(entity, collector, depth: depth + 1);
        }
      }
    } catch (_) {
      // परमिशन न होने पर छोड़ दो
    }
  }
}