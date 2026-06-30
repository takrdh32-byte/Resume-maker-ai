import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/recovered_photo.dart';
import 'paywall_screen.dart';

class ResultsScreen extends StatefulWidget {
  final List<RecoveredPhoto> photos;
  const ResultsScreen({super.key, required this.photos});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isPro = false;

  void _onLockedPhotoTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaywallScreen(
        onUnlocked: () {
          setState(() => _isPro = true);
        },
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        title: Text('${photos.length} Photos Mili', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: photos.isEmpty
          ? const Center(child: Text('Koi photo recover nahi hui', style: TextStyle(color: Colors.white60)))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                final unlocked = _isPro || photo.isUnlocked;
                return GestureDetector(
                  onTap: unlocked ? null : _onLockedPhotoTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(photo.path), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.broken_image, color: Colors.white24),
                        ),
                      ),
                      if (!unlocked)
                        ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              color: Colors.black.withOpacity(0.35),
                              child: const Center(
                                child: Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: _isPro
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _onLockedPhotoTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Sabhi Photos Unlock Karo — ₹49',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}