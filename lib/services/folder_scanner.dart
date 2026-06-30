// 📄 lib/services/folder_scanner.dart
import 'dart:io';

class FolderScanner {
  // ज़्यादातर फ़ोटो/वीडियो वाले पब्लिक फोल्डर
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

  // 100MB से बड़ी फ़ाइलें skip करेंगे (क्योंकि scanFile की सीमा 100MB है)
  static const int _maxFileSize = 100 * 1024 * 1024; // 100MB

  // सभी फ़ोल्डरों को रीकर्सिवली घूमकर छोटी फ़ाइलों की लिस्ट बनाएँ
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

  // रीकर्सिव फंक्शन — सिर्फ़ मान्य JPEG फ़ाइलें (और जिनका साइज़ 100MB से कम) इकट्ठा करता है
  static Future<void> _scanRecursive(Directory dir, List<File> collector,
      {int depth = 0}) async {
    if (depth > 10) return; // बहुत गहराई में मत जाओ
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          // फ़ाइल का साइज़ चेक करो — बड़ी फ़ाइलों को स्किप करो
          final length = await entity.length();
          if (length > 0 && length <= _maxFileSize) {
            collector.add(entity);
          }
        } else if (entity is Directory) {
          await _scanRecursive(entity, collector, depth: depth + 1);
        }
      }
    } catch (_) {
      // परमिशन न होने पर छोड़ दो
    }
  }
}