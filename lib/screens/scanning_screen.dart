import 'package:flutter/material.dart';
import '../mocks/mock_recoverx_bridge.dart'; // Mock Bridge
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

  @override
  void initState() {
    super.initState();
    _listenToProgress();
    _startMockScan();
  }

  void _listenToProgress() {
    MockRecoverXBridge.scanProgressStream.listen((event) {
      if (!mounted) return;
      final path = event['path'] as String?;
      final size = event['size'] as int?;
      if (path == null || size == null) return;

      setState(() {
        _found.add(RecoveredPhoto(
          path: path,
          sizeBytes: size,
          isUnlocked: _found.isEmpty, // पहली फोटो फ्री
        ));
        _statusText = '${_found.length} photos mili...';
      });
    });
  }

  Future<void> _startMockScan() async {
    try {
      // सिर्फ इवेंट स्ट्रीम चालू करने के लिए scanAll() कॉल करो
      await MockRecoverXBridge.scanAll();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultsScreen(photos: _found)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Scan fail hua: $e';
        _scanFailed = true;
      });
    }
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
              if (!_scanFailed) ...[
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