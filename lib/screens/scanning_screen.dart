// 📄 lib/screens/scanning_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../recoverx_bridge.dart';
import '../services/folder_scanner.dart';
import '../models/recovered_photo.dart';
import 'results_screen.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  final List<RecoveredPhoto> _found = [];
  String _statusText = 'Scan shuru ho raha hai...';
  bool _scanFailed = false;
  bool _stopped = false;
  static const int _maxPhotos = 200; // 200 फोटो के बाद ऑटो-स्टॉप

  @override
  void initState() {
    super.initState();
    _listenToProgress();
    _startRealScan();
  }

  void _listenToProgress() {
    RecoverXBridge.scanProgressStream.listen((event) {
      if (!mounted || _stopped) return;
      final path = event['path'] as String?;
      final size = event['size'] as int?;
      if (path == null || size == null) return;

      setState(() {
        _found.add(RecoveredPhoto(
          path: path,
          sizeBytes: size,
          isUnlocked: _found.isEmpty,
        ));
        _statusText = '${_found.length} photos mili...';
      });

      // लिमिट पार होते ही स्कैन बंद करो
      if (_found.length >= _maxPhotos) {
        _stopScan();
      }
    });
  }

  Future<void> _startRealScan() async {
    try {
      final outputDir = await _getOutputDir();
      final files = await FolderScanner.collectFiles();
      if (files.isEmpty || _stopped) {
        _showResultsIfMounted();
        return;
      }

      for (final file in files) {
        if (_stopped) break;
        await RecoverXBridge.scanFile(
          sourcePath: file.path,
          outputDir: outputDir,
        );
        if (_found.length >= _maxPhotos) break; // लिमिट के बाद लूप तोड़ो
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Scan fail hua: $e';
        _scanFailed = true;
      });
      return;
    }
    if (!_stopped) {
      _showResultsIfMounted();
    }
  }

  void _showResultsIfMounted() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultsScreen(photos: _found)),
    );
  }

  void _stopScan() {
    if (_stopped) return;
    _stopped = true;
    _showResultsIfMounted();
  }

  Future<String> _getOutputDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${appDir.path}/recovered');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_scanFailed && !_stopped) ...[
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                      strokeWidth: 4, color: Color(0xFF58A6FF)),
                ),
                const SizedBox(height: 24),
                Text(
                  _statusText,
                  style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Phone ko hilao mat, scan chal raha hai',
                  style: TextStyle(fontSize: 13, color: Colors.white38),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _stopScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Stop Scan',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                ),
              ] else if (_stopped) ...[
                const Icon(Icons.check_circle_outline,
                    size: 56, color: Color(0xFF58A6FF)),
                const SizedBox(height: 16),
                Text(
                  'Scan ruk gaya. ${_found.length} photos mili.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ResultsScreen(photos: _found)),
                    );
                  },
                  child: const Text('Dekho'),
                ),
              ] else ...[
                const Icon(Icons.error_outline,
                    size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(_statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Wapas Jao'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}