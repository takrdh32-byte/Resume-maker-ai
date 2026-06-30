import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../recoverx_bridge.dart';
import '../services/folder_scanner.dart';
import '../services/plan_manager.dart';
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
  late int _maxPhotos;

  @override
  void initState() {
    super.initState();
    PlanManager.checkExpiry();
    _maxPhotos = PlanManager.photoLimit;
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
          isUnlocked: PlanManager.isPro || _found.isEmpty,
        ));
        _statusText = '${_found.length} photos mili...';
      });
      if (_found.length >= _maxPhotos) _stopScan();
    });
  }

  Future<void> _startRealScan() async {
    // अगर प्रो नहीं है और फ्री यूज़ भी हो चुका है, तो वापस भेजो
    if (!PlanManager.isPro && await PlanManager.hasUsedFree()) {
      if (!mounted) return;
      _stopScan();
      return;
    }

    try {
      final outputDir = await _getOutputDir();
      final started = await RecoverXBridge.startScanSession(outputDir: outputDir);
      if (!started) throw Exception("Session start failed");

      // पहले से रिकवर हो चुकी फ़ाइलों के पथ लोड करो
      final prefs = await SharedPreferences.getInstance();
      final savedPaths = prefs.getStringList('recovered_paths') ?? [];
      final excludeSet = savedPaths.toSet();

      // नई फ़ाइलों को छोड़कर बाकी स्कैन करो
      final files = await FolderScanner.collectFiles(excludePaths: excludeSet);
      if (files.isEmpty || _stopped) {
        await RecoverXBridge.endScanSession();
        _showResultsIfMounted();
        return;
      }

      for (final file in files) {
        if (_stopped) break;
        await RecoverXBridge.scanFileInSession(sourcePath: file.path);
        if (_found.length >= _maxPhotos) break;
      }

      // अभी जो नई फ़ाइलें मिली हैं, उनके पथ सेव करो
      final newPaths = _found.map((p) => p.path).toList();
      savedPaths.addAll(newPaths);
      await prefs.setStringList('recovered_paths', savedPaths);

      // फ्री फोटो दिखाने के बाद मार्क करो (अगर फ्री प्लान हो)
      if (!PlanManager.isPro) {
        await PlanManager.markUsedFree();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Scan fail hua: $e';
        _scanFailed = true;
      });
      return;
    } finally {
      await RecoverXBridge.endScanSession();
    }
    if (!_stopped) _showResultsIfMounted();
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
    if (!await outDir.exists()) await outDir.create(recursive: true);
    return outDir.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF6C63FF)),
                ),
                const SizedBox(height: 24),
                Text(
                  _statusText,
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Phone ko hilao mat, scan chal raha hai',
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4)),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _stopScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Stop Scan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ] else if (_stopped) ...[
                const Icon(Icons.check_circle_outline, size: 56, color: Color(0xFF6C63FF)),
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
                      MaterialPageRoute(builder: (_) => ResultsScreen(photos: _found)),
                    );
                  },
                  child: const Text('Dekho'),
                ),
              ] else ...[
                const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
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