import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/billing_service.dart';

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
      // सीधा HomeScreen, कोई SplashScreen नहीं
      home: const HomeScreen(),
    );
  }
}