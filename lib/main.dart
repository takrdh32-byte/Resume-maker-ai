import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/billing_service.dart';
import 'painters/logo_painter.dart';   // <-- यहाँ से लाएँगे

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BillingService.initialize();
  runApp(const RecoverXApp());
}

class RecoverXApp extends StatelessWidget {
  const RecoverXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RecoverX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E14),
        primaryColor: const Color(0xFFE53935),
        cardColor: const Color(0xFF1A1F2E),
        dialogBackgroundColor: const Color(0xFF1A1F2E),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 4,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ---------- स्प्लैश स्क्रीन (2 सेकंड) ----------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CustomPaint(
              size: Size(120, 120),
              painter: LogoPainter(),
            ),
            const SizedBox(height: 24),
            const Text(
              'RecoverX',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}