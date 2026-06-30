import 'package:flutter/material.dart';
import '../permission_helper.dart';
import 'scanning_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _permissionGranted = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAtStart();
  }

  Future<void> _requestPermissionsAtStart() async {
    final granted = await PermissionHelper.requestStoragePermissions();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _checkingPermission = false;
    });
  }

  Future<void> _onStartRecoveryPressed() async {
    if (!_permissionGranted) {
      final permanentlyDenied = await PermissionHelper.isPermanentlyDenied();
      if (permanentlyDenied) {
        _showSettingsDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required')),
        );
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanningScreen()),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Needed'),
        content: const Text('RecoverX needs storage access to find deleted photos. Please grant it in Settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PermissionHelper.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [const Color(0xFF6C63FF).withOpacity(0.2), const Color(0xFF6C63FF).withOpacity(0.05)]),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.restore_page_rounded, size: 48, color: Color(0xFF6C63FF)),
              ),
              const SizedBox(height: 24),
              const Text(
                'RecoverX',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Deleted photos aur videos turant wapas paao\nBina internet, bina root',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
              ),
              const SizedBox(height: 48),
              _checkingPermission
                  ? const CircularProgressIndicator(color: Color(0xFF6C63FF))
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _permissionGranted ? _onStartRecoveryPressed : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Start Recovery', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
              const SizedBox(height: 16),
              Text('100% offline — koi data server par nahi jaata',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
            ],
          ),
        ),
      ),
    );
  }
}