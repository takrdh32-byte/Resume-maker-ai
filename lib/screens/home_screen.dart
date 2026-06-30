import 'package:flutter/material.dart';
import '../permission_helper.dart';
import '../services/plan_manager.dart';
import 'scanning_screen.dart';
import 'paywall_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _permissionGranted = false;
  bool _checkingPermission = true;
  bool _freeUsed = false;        // क्या यूज़र ने फ्री फोटो देख ली?
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAtStart();
    _loadUserState();
  }

  Future<void> _loadUserState() async {
    final used = await PlanManager.hasUsedFree();
    if (!mounted) return;
    setState(() {
      _freeUsed = used;
      _isPro = PlanManager.isPro;
    });
  }

  Future<void> _requestPermissionsAtStart() async {
    final granted = await PermissionHelper.requestStoragePermissions();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _checkingPermission = false;
    });
  }

  void _onStartRecoveryPressed() {
    if (!_permissionGranted) {
      _showPermissionDenied();
      return;
    }

    // अगर यूज़र प्रो नहीं है और पहले ही फ्री फोटो देख चुका है, तो सीधे पेमेंट स्क्रीन
    if (!_isPro && _freeUsed) {
      _openPaywall();
      return;
    }

    // फ्री यूज़र (पहली बार) या प्रो यूज़र के लिए स्कैन स्क्रीन
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanningScreen()),
    ).then((_) {
      // स्कैन से वापस आने पर स्टेटस रिफ्रेश करो
      _loadUserState();
    });
  }

  void _openPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaywallScreen(
        onUnlocked: () {
          setState(() {
            _isPro = PlanManager.isPro;
          });
        },
      )),
    );
  }

  void _showPermissionDenied() async {
    final permanentlyDenied = await PermissionHelper.isPermanentlyDenied();
    if (!mounted) return;
    if (permanentlyDenied) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission Needed'),
          content: const Text('RecoverX needs storage access. Please grant it in Settings.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () {
              Navigator.pop(ctx);
              PermissionHelper.openSettings();
            }, child: const Text('Open Settings')),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required')),
      );
    }
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
              // Upgrade button top-right
              Align(
                alignment: Alignment.topRight,
                child: TextButton.icon(
                  onPressed: _openPaywall,
                  icon: const Icon(Icons.stars, color: Color(0xFF6C63FF)),
                  label: Text(
                    _isPro ? 'Pro' : 'Upgrade',
                    style: const TextStyle(color: Color(0xFF6C63FF)),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withOpacity(0.2),
                      const Color(0xFF6C63FF).withOpacity(0.05),
                    ],
                  ),
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
              if (_checkingPermission)
                const CircularProgressIndicator(color: Color(0xFF6C63FF))
              else
                Column(
                  children: [
                    // अगर प्रो नहीं है और फ्री खत्म हो गया है, तो स्टार्ट बटन के बजाय अपग्रेड बटन
                    if (!_isPro && _freeUsed)
                      _buildUpgradeButton()
                    else
                      _buildStartButton(),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                '100% offline — koi data server par nahi jaata',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3)),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _permissionGranted ? _onStartRecoveryPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Start Recovery',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildUpgradeButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _openPaywall,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Unlock Full Access',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }
}