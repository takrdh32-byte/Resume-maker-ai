import 'dart:async';
import 'dart:io';
import 'dart:isolate';

class CandidateFile {
  final String path;
  final int sizeBytes;
  final String sourceFolder;

  CandidateFile({
    required this.path,
    required this.sizeBytes,
    required this.sourceFolder,
  });
}

class FolderScanner {
  static const List<String> primaryCacheFolders = [
    '/storage/emulated/0/DCIM/.thumbnails',
    '/storage/emulated/0/Pictures/.thumbnails',
    '/storage/emulated/0/.thumbnails',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/.thumbs',
    '/storage/emulated/0/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/Pictures/.thumbnails/deleted',
    '/storage/emulated/0/DCIM/.deleted',
  ];

  static const List<String> secondaryCacheFolders = [
    '/storage/emulated/0/Android/data/com.instagram.android/cache',
    '/storage/emulated/0/Android/data/com.facebook.katana/cache',
    '/storage/emulated/0/Android/data/com.facebook.orca/cache',
    '/storage/emulated/0/Android/data/com.snapchat.android/cache',
    '/storage/emulated/0/Android/data/com.whatsapp/cache',
    '/storage/emulated/0/Android/data/org.telegram.messenger/cache',
    '/storage/emulated/0/Android/data/com.google.android.apps.photos/cache',
    '/storage/emulated/0/Android/data/com.android.chrome/cache',
    '/storage/emulated/0/Android/data/com.twitter.android/cache',
    '/storage/emulated/0/Pictures/Screenshots/.thumbnails',
    '/storage/emulated/0/DCIM/Camera/.thumbnails',
    '/storage/emulated/0/Movies/.thumbnails',
  ];

  static const List<String> publicFallbackFolders = [
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Movies',
  ];

  static const int _fallbackMaxBytes = 512 * 1024;
  static const int _cacheMaxBytes = 30 * 1024 * 1024;

  static const Set<String> _mediaExtensions = {
    '.jpg', '.jpeg', '.png', '.mp4', '.mov', '.3gp', '.heic', '.webp'
  };

  static const List<List<int>> _magicPrefixes = [
    [0xFF, 0xD8, 0xFF],          // JPEG
    [0x89, 0x50, 0x4E, 0x47],    // PNG
  ];

  Future<List<CandidateFile>> collectFiles({
    void Function(String stage, int foldersScanned, int totalFolders)?
        onStageProgress,
  }) async {
    var results = await _scanFoldersParallel(
      primaryCacheFolders,
      maxBytes: _cacheMaxBytes,
      stageLabel: 'primary_cache',
      onStageProgress: onStageProgress,
    );

    results.addAll(await _scanFoldersParallel(
      secondaryCacheFolders,
      maxBytes: _cacheMaxBytes,
      stageLabel: 'secondary_cache',
      onStageProgress: onStageProgress,
    ));

    if (results.isEmpty) {
      results.addAll(await _scanFoldersParallel(
        publicFallbackFolders,
        maxBytes: _fallbackMaxBytes,
        stageLabel: 'public_fallback',
        onStageProgress: onStageProgress,
      ));
    }

    results.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
    return results;
  }

  Future<List<CandidateFile>> _scanFoldersParallel(
    List<String> folders, {
    required int maxBytes,
    required String stageLabel,
    void Function(String, int, int)? onStageProgress,
  }) async {
    final List<CandidateFile> all = [];
    int done = 0;

    final futures = folders.map((folder) async {
      final list = await Isolate.run(
        () => _scanSingleFolder(folder, maxBytes),
      );
      done++;
      onStageProgress?.call(stageLabel, done, folders.length);
      return list;
    });

    final perFolder = await Future.wait(futures);
    for (final list in perFolder) {
      all.addAll(list);
    }
    return all;
  }

  static List<CandidateFile> _scanSingleFolder(String folderPath, int maxBytes) {
    final dir = Directory(folderPath);
    final List<CandidateFile> out = [];
    if (!dir.existsSync()) return out;

    try {
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;

        final stat = entity.statSync();
        if (stat.size == 0 || stat.size > maxBytes) continue;

        if (!_looksLikeMedia(entity)) continue;

        out.add(CandidateFile(
          path: entity.path,
          sizeBytes: stat.size,
          sourceFolder: folderPath,
        ));
      }
    } catch (_) {}
    return out;
  }

  static bool _looksLikeMedia(File file) {
    final lower = file.path.toLowerCase();
    final hasKnownExt = _mediaExtensions.any((ext) => lower.endsWith(ext));
    if (hasKnownExt) return true;

    try {
      final raf = file.openSync();
      final header = raf.readSync(12);
      raf.closeSync();
      if (header.length < 4) return false;

      for (final magic in _magicPrefixes) {
        if (header.length >= magic.length) {
          var match = true;
          for (var i = 0; i < magic.length; i++) {
            if (header[i] != magic[i]) { match = false; break; }
          }
          if (match) return true;
        }
      }
      if (header.length >= 8 &&
          header[4] == 0x66 && header[5] == 0x74 &&
          header[6] == 0x79 && header[7] == 0x70) {
        return true;
      }
    } catch (_) {}
    return false;
  }
}