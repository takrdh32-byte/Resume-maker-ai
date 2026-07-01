import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../recoverx_bridge.dart';
import '../services/plan_manager.dart';
import '../models/recovered_photo.dart';
import 'results_screen.dart';

class DeepScanScreen extends StatefulWidget {
  const DeepScanScreen({super.key});

  @override
  State<DeepScanScreen> createState() => _DeepScanScreenState();
}

class _DeepScanScreenState extends State<DeepScanScreen> {
  final List<RecoveredPhoto> _found = [];
  String _statusText = 'Select a folder to scan deeply';
  bool _scanning = false;
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
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
        _statusText = '${_found.length} photos found...';
      });
      if (_found.length >= PlanManager.photoLimit) {
        _stopScan();
      }
    });
  }

  Future<void> _pickAndScan() async {
    String? selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir == null) return;

    setState(() {
      _scanning = true;
      _stopped = false;
      _statusText = 'Scanning started...';
    });

    final outputDir = await _getOutputDir();
    final started = await RecoverXBridge.startScanSession(outputDir: outputDir);
    if (!started) {
      setState(() => _statusText = 'Failed to start scan engine');
      _scanning = false;
      return;
    }

    int processed = 0;
    final dir = Directory(selectedDir);
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (_stopped) break;
        if (entity is File) {
          processed++;
          setState(() => _statusText = 'Scanning... $processed files checked');
          await RecoverXBridge.scanFileInSession(sourcePath: entity.path);
        }
      }
    }

    await RecoverXBridge.endScanSession();

    if (_found.isEmpty) {
      final outDir = Directory(outputDir);
      if (await outDir.exists()) {
        final files = outDir.listSync().whereType<File>();
        for (var f in files) {
          _found.add(RecoveredPhoto(path: f.path, sizeBytes: await f.length(), isUnlocked: false));
        }
      }
    }

    setState(() {
      _scanning = false;
      _statusText = _found.isEmpty
          ? 'No recoverable photos found in this folder.'
          : 'Scan complete. ${_found.length} photos found.';
    });

    if (mounted && _found.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResultsScreen(photos: _found)));
    }
  }

  void _stopScan() {
    _stopped = true;
  }

  Future<String> _getOutputDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${appDir.path}/deep_recovered');
    if (!await outDir.exists()) await outDir.create(recursive: true);
    return outDir.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Deep Scan', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_scanning) ...[
                const CircularProgressIndicator(color: Color(0xFFE53935)),
                const SizedBox(height: 16),
                Text(_statusText, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _stopScan,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text('Stop Scan'),
                ),
              ] else ...[
                const Icon(Icons.folder_open, size: 72, color: Color(0xFFE53935)),
                const SizedBox(height: 16),
                const Text('Deep Scan any folder for hidden/deleted photos',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 16)),
                const SizedBox(height: 8),
                Text(_statusText, style: const TextStyle(color: Colors.white38)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _pickAndScan,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Select Folder & Start Deep Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}