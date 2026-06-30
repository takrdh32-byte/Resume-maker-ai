import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recovered_photo.dart';

class FullScreenPreview extends StatelessWidget {
  final RecoveredPhoto photo;
  const FullScreenPreview({super.key, required this.photo});

  Future<void> _saveToGallery(BuildContext context) async {
    final file = File(photo.path);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File not found')));
      return;
    }
    try {
      final picturesDir = Directory('/storage/emulated/0/Pictures/RecoverX');
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }
      final destPath = '${picturesDir.path}/recovered_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await file.copy(destPath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${picturesDir.path}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(photo.path), fit: BoxFit.contain),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _saveToGallery(context),
              icon: const Icon(Icons.download),
              label: const Text('Save to Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}