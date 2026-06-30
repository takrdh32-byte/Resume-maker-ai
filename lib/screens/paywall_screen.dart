import 'package:flutter/material.dart';

class PaywallScreen extends StatelessWidget {
  final VoidCallback onUnlocked;
  const PaywallScreen({super.key, required this.onUnlocked});

  void _purchase(BuildContext context, String plan) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Flow'),
        content: Text('$plan ke liye Google Play Billing yahan connect hogi (agla module).'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              onUnlocked();
            },
            child: const Text('Test Unlock (Dev Only)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.lock_open_rounded, size: 64, color: Color(0xFF58A6FF)),
            const SizedBox(height: 16),
            const Text(
              'Sabhi Recovered Photos Unlock Karo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 32),
            _PlanCard(
              title: 'Weekly Pass',
              price: '₹49',
              subtitle: '7 din ke liye full access',
              onTap: () => _purchase(context, 'Weekly Pass (₹49)'),
            ),
            const SizedBox(height: 16),
            _PlanCard(
              title: 'Monthly Pro',
              price: '₹199',
              subtitle: '30 din ke liye full access + video recovery',
              highlighted: true,
              onTap: () => _purchase(context, 'Monthly Pro (₹199)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFF238636) : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: highlighted ? const Color(0xFF3FB950) : Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
            Text(price, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}