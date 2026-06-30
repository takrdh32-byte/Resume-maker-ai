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
        primaryColor: const Color(0xFFE53935),       // लाल
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
      backgroundColor: const Color(0xFF0A0E14),          // गहरा डार्क बैकग्राउंड
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // लोगो (CustomPainter से बना)
            const CustomPaint(
              size: Size(120, 120),
              painter: LogoPainter(),
            ),
            const SizedBox(height: 24),
            // "RecoverX" टेक्स्ट
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

// ---------- लोगो पेंटर (लाल ग्रेडिएंट, सफ़ेद "R" और तीर) ----------
class LogoPainter extends CustomPainter {
  const LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;                     // थोड़ी पैडिंग

    // ----- 1. लाल ग्रेडिएंट बैकग्राउंड -----
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.8,
      colors: [
        const Color(0xFFE53935).withOpacity(1),            // चमकदार लाल
        const Color(0xFFB71C1C).withOpacity(1),            // गहरा लाल
      ],
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);

    // ----- 2. सफ़ेद बाहरी रिंग -----
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius - 6, ringPaint);

    // ----- 3. सफ़ेद तीर (रिकवरी प्रतीक) -----
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // तीर का आर्क
    final arrowRect = Rect.fromCircle(center: center, radius: radius - 18);
    canvas.drawArc(
      arrowRect,
      2.3,                // शुरुआत का एंगल (रेडियन)
      4.0,                // घुमाव का एंगल (लगभग 230°)
      false,
      arrowPaint,
    );

    // तीर का सिरा (त्रिकोण)
    final arrowHeadPath = Path();
    final tipPoint = Offset(center.dx - 8, center.dy - radius + 20);
    arrowHeadPath.moveTo(tipPoint.dx, tipPoint.dy);
    arrowHeadPath.lineTo(tipPoint.dx - 12, tipPoint.dy + 18);
    arrowHeadPath.lineTo(tipPoint.dx + 10, tipPoint.dy + 10);
    arrowHeadPath.close();
    canvas.drawPath(arrowHeadPath, Paint()..color = Colors.white);

    // ----- 4. बीच में सफ़ेद "R" अक्षर -----
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'R',
        style: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}