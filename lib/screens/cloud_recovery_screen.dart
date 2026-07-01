import 'package:flutter/material.dart';
import '../services/cloud_recovery_service.dart';

class CloudRecoveryScreen extends StatefulWidget {
  const CloudRecoveryScreen({super.key});

  @override
  State<CloudRecoveryScreen> createState() => _CloudRecoveryScreenState();
}

class _CloudRecoveryScreenState extends State<CloudRecoveryScreen> {
  final List<String> _photos = [];
  bool _loading = false;

  Future<void> _startCloudScan() async {
    setState(() => _loading = true);
    // पहले Google Photos से
    final photos = await CloudRecoveryService.getRecoverablePhotos();
    // फिर Gmail से
    final attachments = await CloudRecoveryService.getEmailAttachments();
    setState(() {
      _photos.addAll(photos);
      _photos.addAll(attachments);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Cloud Recovery', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No recoverable photos found in cloud',
                          style: TextStyle(color: Colors.white60)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _startCloudScan,
                        child: const Text('Start Cloud Scan'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _photos.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.image, color: Color(0xFFE53935)),
                    title: Text(_photos[index], style: const TextStyle(color: Colors.white)),
                  ),
                ),
    );
  }
}