import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/recovered_photo.dart';
import '../services/plan_manager.dart';
import 'paywall_screen.dart';
import 'full_screen_preview.dart';

class ResultsScreen extends StatefulWidget {
  final List<RecoveredPhoto> photos;
  const ResultsScreen({super.key, required this.photos});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isPro = PlanManager.isPro;

  void _onLockedPhotoTap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PaywallScreen(
      onUnlocked: () {
        setState(() {
          _isPro = PlanManager.isPro;
        });
      },
    )));
  }

  void _onPhotoTap(RecoveredPhoto photo) {
    if (!_isPro && !photo.isUnlocked) {
      _onLockedPhotoTap();
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenPreview(photo: photo)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('${widget.photos.length} Photos Found', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: widget.photos.isEmpty
          ? const Center(child: Text('No photos recovered', style: TextStyle(color: Colors.white60)))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
              itemCount: widget.photos.length,
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                final unlocked = _isPro || photo.isUnlocked;
                return GestureDetector(
                  onTap: () => _onPhotoTap(photo),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(photo.path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800, child: const Icon(Icons.broken_image, color: Colors.white24))),
                      if (!unlocked)
                        ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(color: Colors.black.withOpacity(0.35), child: const Center(child: Icon(Icons.lock_rounded, color: Colors.white, size: 28))))),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: _isPro ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _onLockedPhotoTap,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Unlock All Photos — ₹199/month', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}