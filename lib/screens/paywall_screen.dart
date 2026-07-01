import 'package:flutter/material.dart';
import '../services/billing_service.dart';

class PaywallScreen extends StatelessWidget {
  final VoidCallback onUnlocked;
  const PaywallScreen({super.key, required this.onUnlocked});

  Future<void> _purchaseMonthly(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecting to Play Store...')));
    try {
      final success = await BillingService.buyMonthlySubscription();
      if (context.mounted) {
        if (success) {
          Navigator.pop(context);
          onUnlocked();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase failed or cancelled')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Unlock Full Access', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.lock_open_rounded, size: 64, color: Color(0xFFE53935)),
            const SizedBox(height: 16),
            const Text('Recover unlimited deleted photos', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('No ads, full privacy, offline recovery', style: TextStyle(fontSize: 14, color: Colors.white60)),
            const SizedBox(height: 32),
            Card(
              color: const Color(0xFF238636),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () => _purchaseMonthly(context),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Monthly Pro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                            SizedBox(height: 4),
                            Text('Unlimited scans, 200 photos per scan', style: TextStyle(fontSize: 13, color: Colors.white70)),
                            Text('Auto-renew every month', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          ],
                        ),
                      ),
                      const Text('₹199', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}