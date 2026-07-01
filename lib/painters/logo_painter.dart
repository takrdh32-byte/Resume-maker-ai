import 'package:flutter/material.dart';

class LogoPainter extends CustomPainter {
  const LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // 1. लाल ग्रेडिएंट बैकग्राउंड
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.8,
      colors: [
        const Color(0xFFE53935).withOpacity(1),
        const Color(0xFFB71C1C).withOpacity(1),
      ],
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    // 2. सफ़ेद बाहरी रिंग
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius - 6, ringPaint);

    // 3. सफ़ेद तीर (रिकवरी प्रतीक)
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final arrowRect = Rect.fromCircle(center: center, radius: radius - 18);
    canvas.drawArc(arrowRect, 2.3, 4.0, false, arrowPaint);

    // तीर का सिरा
    final arrowHeadPath = Path();
    final tipPoint = Offset(center.dx - 8, center.dy - radius + 20);
    arrowHeadPath.moveTo(tipPoint.dx, tipPoint.dy);
    arrowHeadPath.lineTo(tipPoint.dx - 12, tipPoint.dy + 18);
    arrowHeadPath.lineTo(tipPoint.dx + 10, tipPoint.dy + 10);
    arrowHeadPath.close();
    canvas.drawPath(arrowHeadPath, Paint()..color = Colors.white);

    // 4. सफ़ेद "R" अक्षर
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