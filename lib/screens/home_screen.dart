import 'package:flutter/material.dart';
import '../permission_helper.dart';
import 'scanning_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checkingPermission = false;

  Future<void> _onStartRecoveryPressed() async {
    setState(() => _checkingPermission = true);

    final granted = await PermissionHelper.requestStoragePermissions();

    if (!mounted) return;
    setState(() => _checkingPermission = false);

    if (!granted) {
      final permanentlyDenied = await PermissionHelper.isPermanentlyDenied();
      if (!mounted) return;

      if (permanentlyDenied) {
        _showSettingsDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan ke liye storage permission zaroori hai')),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanningScreen()),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Chahiye'),
        content: const Text(
          'RecoverX ko deleted photos dhoondhne ke liye storage access chahiye. '
          'Settings me ja kar permission ON karo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PermissionHelper.openSettings();
            },
            child: const Text('Settings Kholo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restore_page_rounded, size: 96, color: Color(0xFF58A6FF)),
              const SizedBox(height: 24),
              const Text(
                'RecoverX',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Deleted photos aur videos turant wapas paao\nBina internet, bina root',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white60),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _checkingPermission ? null : _onStartRecoveryPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _checkingPermission
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Start Recovery',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '100% offline — koi data server par nahi jaata',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}