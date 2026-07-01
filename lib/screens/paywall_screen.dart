import 'package:flutter/material.dart';
import '../services/plan_manager.dart';

class PaywallScreen extends StatelessWidget {
  final VoidCallback onUnlocked;
  const PaywallScreen({super.key, required this.onUnlocked});

  // इस फ़ंक्शन में असली पेमेंट की जगह सीधे प्लान सेट कर रहे हैं
  void _purchaseMonthly(BuildContext context) {
    // प्लान को मंथली प्रो में बदलो और 30 दिन की वैधता सेट करो
    PlanManager.setMonthlyPlan();
    // पेमेंट स्क्रीन बंद करो
    Navigator.pop(context);
    // कॉलबैक से होम स्क्रीन को बताओ कि अनलॉक हो गया
    onUnlocked();
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
            const Text(
              'Recover unlimited deleted photos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'No ads, full privacy, offline recovery',
              style: TextStyle(fontSize: 14, color: Colors.white60),
            ),
            const SizedBox(height: 32),
            // सिर्फ एक मंथली प्लान का कार्ड
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
                            Text('Auto-renew every month (mock)', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          ],
                        ),
                      ),
                      const Text('₹199', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Test Mode: Tap to unlock instantly',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}