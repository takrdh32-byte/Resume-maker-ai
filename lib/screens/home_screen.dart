import 'package:flutter/material.dart';
import '../permission_helper.dart';
import '../services/plan_manager.dart';
import '../painters/logo_painter.dart';
import 'scanning_screen.dart';
import 'paywall_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _permissionGranted = false;
  bool _checkingPermission = true;
  bool _freeUsed = false;
  bool _isPro = false;

  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAtStart();
    _loadUserState();

    // लोगो को लगातार धीरे-धीरे घुमाने के लिए
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),  // 10 सेकंड में एक चक्कर
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserState() async {
    await PlanManager.loadFromStorage();
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
              // Upgrade बटन
              Align(
                alignment: Alignment.topRight,
                child: TextButton.icon(
                  onPressed: _openPaywall,
                  icon: const Icon(Icons.stars, color: Color(0xFFE53935)),
                  label: Text(
                    _isPro ? 'Pro' : 'Upgrade ₹199',
                    style: const TextStyle(color: Color(0xFFE53935)),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935).withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const Spacer(),

              // ---------- घूमता हुआ लोगो ----------
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)       // परिप्रेक्ष्य (perspective)
                      ..rotateY(_rotationController.value * 3.14159 * 2), // Y-अक्ष पर घुमाएँ
                    child: child,
                  );
                },
                child: const CustomPaint(
                  size: Size(100, 100),
                  painter: LogoPainter(),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'RecoverX',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Recover deleted photos & videos instantly\nNo internet, no root required',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white60),
              ),
              const SizedBox(height: 24),

              if (_checkingPermission)
                const CircularProgressIndicator(color: Color(0xFFE53935))
              else ...[
                if (!_isPro && _freeUsed)
                  _buildUpgradeButton()
                else
                  _buildStartButton(),
                const SizedBox(height: 12),
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
          backgroundColor: const Color(0xFFE53935),
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
          backgroundColor: const Color(0xFFE53935),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Unlock Full Access — ₹199/month', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}