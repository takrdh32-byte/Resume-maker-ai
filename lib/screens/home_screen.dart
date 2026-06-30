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
  bool _freeUsed = false;
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAtStart();
    _loadUserState();
  }

  Future<void> _loadUserState() async {
    await PlanManager.loadFromStorage(); // पहले प्लान लोड करो
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
    // फ्री फोटो देख ली हो और प्रो नहीं तो पेमेंट
    if (!_isPro && _freeUsed) {
      _openPaywall();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanningScreen()),
    ).then((_) => _loadUserState());
  }

  void _openPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaywallScreen(
        onUnlocked: () {
          setState(() {
            _isPro = true;
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
          content: const Text('RecoverX needs storage access. Grant it in Settings.'),
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
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton.icon(
                  onPressed: _openPaywall,
                  icon: const Icon(Icons.stars, color: Color(0xFF6C63FF)),
                  label: Text(
                    _isPro ? 'Pro' : 'Upgrade ₹199',
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
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    const Color(0xFF6C63FF).withOpacity(0.2),
                    const Color(0xFF6C63FF).withOpacity(0.05)
                  ]),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
                ),
                child: const Icon(Icons.restore_page_rounded, size: 48, color: Color(0xFF6C63FF)),
              ),
              const SizedBox(height: 24),
              const Text('RecoverX', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text(
                'Recover deleted photos & videos instantly\nNo internet, no root required',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white60),
              ),
              const SizedBox(height: 24),
              if (_checkingPermission)
                const CircularProgressIndicator(color: Color(0xFF6C63FF))
              else ...[
                if (!_isPro && _freeUsed)
                  _buildUpgradeButton()
                else
                  _buildStartButton(),
                const SizedBox(height: 12),
                // डिस्क्लेमर
                const Text(
                  'Disclaimer: Recovery depends on device cache. Not all deleted files may be recoverable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
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
        child: const Text('Start Recovery', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
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
        child: const Text('Unlock Full Access — ₹199/month', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}