import 'dart:async';
import 'dart:math';

class MockRecoverXBridge {
  static final _progressController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get scanProgressStream =>
      _progressController.stream;

  static Future<String> getEngineVersion() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'RecoverX-Engine v0.5.0 (Mock)';
  }

  static Future<int> scanFile({
    required String sourcePath,
    required String outputDir,
  }) async {
    _progressController.add({
      'path': '/storage/emulated/0/RecoverX/recovered_1.jpg',
      'size': 1024 * 512,
    });
    return 1;
  }

  static Future<List<Map<String, dynamic>>> scanAll() async {
    final mockFiles = <Map<String, dynamic>>[];
    final random = Random();
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      final mockPath =
          '/storage/emulated/0/RecoverX/mock_photo_${i + 1}.jpg';
      final mockSize = 1024 * (512 + random.nextInt(1024));
      mockFiles.add({'path': mockPath, 'size': mockSize});
      _progressController.add({'path': mockPath, 'size': mockSize});
    }
    return mockFiles;
  }

  static void dispose() {
    _progressController.close();
  }
}