import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandLogoPainter(),
      ),
    );
  }
}

class _BrandLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Background rounded rect
    final bgPaint = Paint()..color = const Color(0xFF1B1438);
    final bgRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 120, 120),
      const Radius.circular(28),
    );
    canvas.drawRRect(bgRRect, bgPaint);

    // 2. Full shield (left half / base)
    final shieldPaint = Paint()..color = const Color(0xFFA898FF);
    final shieldPath = Path();
    shieldPath.moveTo(60, 17);
    shieldPath.lineTo(96, 30);
    shieldPath.lineTo(96, 57);
    shieldPath.cubicTo(96, 80, 81, 96, 60, 104);
    shieldPath.cubicTo(39, 96, 24, 80, 24, 57);
    shieldPath.lineTo(24, 30);
    shieldPath.close();
    canvas.drawPath(shieldPath, shieldPaint);

    // 3. Right shield half
    final rightShieldPaint = Paint()..color = const Color(0xFFBCB0FF);
    final rightShieldPath = Path();
    rightShieldPath.moveTo(60, 17);
    rightShieldPath.lineTo(96, 30);
    rightShieldPath.lineTo(96, 57);
    rightShieldPath.cubicTo(96, 80, 81, 96, 60, 104);
    rightShieldPath.close();
    canvas.drawPath(rightShieldPath, rightShieldPaint);

    // 4. Pulse line rising
    final pulsePaint = Paint()
      ..color = const Color(0xFF1B1438)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pulsePath = Path();
    pulsePath.moveTo(33, 62);
    pulsePath.lineTo(45, 62);
    pulsePath.lineTo(51, 50);
    pulsePath.lineTo(59, 74);
    pulsePath.lineTo(86, 43);
    canvas.drawPath(pulsePath, pulsePaint);

    // 5. Green status dot
    final dotPaint = Paint()..color = const Color(0xFF55D394);
    final dotBorderPaint = Paint()
      ..color = const Color(0xFF1B1438)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const center = Offset(91, 27);
    canvas.drawCircle(center, 7, dotPaint);
    canvas.drawCircle(center, 7, dotBorderPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
