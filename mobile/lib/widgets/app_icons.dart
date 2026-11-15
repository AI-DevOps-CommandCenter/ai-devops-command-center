import 'package:flutter/material.dart';

/// Centralized Lucide/Feather SVG vector icons matching the prototype exactly.
class LucideIcon extends StatelessWidget {
  final LucideIconData icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  const LucideIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? Colors.black;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LucidePainter(
          icon: icon,
          color: effectiveColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

enum LucideIconData {
  layoutDashboard,
  alertCircle,
  server,
  bookOpen,
  user,
  chevronRight,
  chevronLeft,
  bell,
  search,
  eye,
  eyeOff,
  filter,
  terminal,
  alertTriangle,
  sparkles,
  shieldCheck,
  github,
  externalLink,
  refreshCw,
  clock,
  check,
  x,
  layers,
  activity,
  play,
  share,
}

class _LucidePainter extends CustomPainter {
  final LucideIconData icon;
  final Color color;
  final double strokeWidth;

  _LucidePainter({
    required this.icon,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (icon) {
      case LucideIconData.layoutDashboard:
        // rect 3 3 7 9 rx 1
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(3, 3, 7, 9), const Radius.circular(1)),
          strokePaint,
        );
        // rect 14 3 7 5 rx 1
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(14, 3, 7, 5), const Radius.circular(1)),
          strokePaint,
        );
        // rect 14 12 7 9 rx 1
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(14, 12, 7, 9), const Radius.circular(1)),
          strokePaint,
        );
        // rect 3 16 7 5 rx 1
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(3, 16, 7, 5), const Radius.circular(1)),
          strokePaint,
        );
        break;

      case LucideIconData.alertCircle:
        canvas.drawCircle(const Offset(12, 12), 10, strokePaint);
        canvas.drawLine(const Offset(12, 8), const Offset(12, 12), strokePaint);
        canvas.drawCircle(const Offset(12, 16), 0.75, fillPaint);
        break;

      case LucideIconData.server:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(2, 2, 20, 8), const Radius.circular(2)),
          strokePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(2, 14, 20, 8), const Radius.circular(2)),
          strokePaint,
        );
        canvas.drawCircle(const Offset(6, 6), 0.75, fillPaint);
        canvas.drawCircle(const Offset(6, 18), 0.75, fillPaint);
        break;

      case LucideIconData.bookOpen:
        final p1 = Path();
        p1.moveTo(2, 3);
        p1.lineTo(8, 3);
        p1.cubicTo(10.2, 3, 12, 4.8, 12, 7);
        p1.lineTo(12, 21);
        p1.cubicTo(10.3, 19.8, 8.5, 18, 5, 18);
        p1.lineTo(2, 18);
        p1.close();
        canvas.drawPath(p1, strokePaint);

        final p2 = Path();
        p2.moveTo(22, 3);
        p2.lineTo(16, 3);
        p2.cubicTo(13.8, 3, 12, 4.8, 12, 7);
        p2.lineTo(12, 21);
        p2.cubicTo(13.7, 19.8, 15.5, 18, 19, 18);
        p2.lineTo(22, 18);
        p2.close();
        canvas.drawPath(p2, strokePaint);
        break;

      case LucideIconData.user:
        final userBody = Path();
        userBody.moveTo(20, 21);
        userBody.lineTo(20, 19);
        userBody.cubicTo(20, 16.8, 18.2, 15, 16, 15);
        userBody.lineTo(8, 15);
        userBody.cubicTo(5.8, 15, 4, 16.8, 4, 19);
        userBody.lineTo(4, 21);
        canvas.drawPath(userBody, strokePaint);
        canvas.drawCircle(const Offset(12, 7), 4, strokePaint);
        break;

      case LucideIconData.chevronRight:
        final path = Path();
        path.moveTo(9, 18);
        path.lineTo(15, 12);
        path.lineTo(9, 6);
        canvas.drawPath(path, strokePaint);
        break;

      case LucideIconData.chevronLeft:
        final path = Path();
        path.moveTo(15, 18);
        path.lineTo(9, 12);
        path.lineTo(15, 6);
        canvas.drawPath(path, strokePaint);
        break;

      case LucideIconData.bell:
        final path = Path();
        path.moveTo(18, 8);
        path.cubicTo(18, 4.7, 15.3, 2, 12, 2);
        path.cubicTo(8.7, 2, 6, 4.7, 6, 8);
        path.cubicTo(6, 15, 3, 17, 3, 17);
        path.lineTo(21, 17);
        path.cubicTo(21, 17, 18, 15, 18, 8);
        canvas.drawPath(path, strokePaint);

        final clapper = Path();
        clapper.moveTo(10.3, 21);
        clapper.cubicTo(10.8, 21.6, 11.4, 22, 12, 22);
        clapper.cubicTo(12.6, 22, 13.2, 21.6, 13.7, 21);
        canvas.drawPath(clapper, strokePaint);
        break;

      case LucideIconData.search:
        canvas.drawCircle(const Offset(11, 11), 8, strokePaint);
        canvas.drawLine(const Offset(21, 21), const Offset(16.65, 16.65), strokePaint);
        break;

      case LucideIconData.eye:
        final eye = Path();
        eye.moveTo(2, 12);
        eye.cubicTo(5.5, 5, 12, 5, 12, 5);
        eye.cubicTo(12, 5, 18.5, 5, 22, 12);
        eye.cubicTo(18.5, 19, 12, 19, 12, 19);
        eye.cubicTo(5.5, 19, 2, 12, 2, 12);
        eye.close();
        canvas.drawPath(eye, strokePaint);
        canvas.drawCircle(const Offset(12, 12), 3, strokePaint);
        break;

      case LucideIconData.eyeOff:
        final eye = Path();
        eye.moveTo(2, 12);
        eye.cubicTo(5.5, 5, 12, 5, 12, 5);
        eye.cubicTo(12, 5, 18.5, 5, 22, 12);
        canvas.drawPath(eye, strokePaint);
        canvas.drawLine(const Offset(2, 2), const Offset(22, 22), strokePaint);
        canvas.drawCircle(const Offset(12, 12), 3, strokePaint);
        break;

      case LucideIconData.filter:
        final path = Path();
        path.moveTo(22, 3);
        path.lineTo(2, 3);
        path.lineTo(10, 12.46);
        path.lineTo(10, 19);
        path.lineTo(14, 21);
        path.lineTo(14, 12.46);
        path.close();
        canvas.drawPath(path, strokePaint);
        break;

      case LucideIconData.terminal:
        final path = Path();
        path.moveTo(4, 17);
        path.lineTo(10, 11);
        path.lineTo(4, 5);
        canvas.drawPath(path, strokePaint);
        canvas.drawLine(const Offset(12, 19), const Offset(20, 19), strokePaint);
        break;

      case LucideIconData.alertTriangle:
        final path = Path();
        path.moveTo(10.3, 3.9);
        path.lineTo(1.8, 18.0);
        path.arcToPoint(const Offset(3.5, 21.0), radius: const Radius.circular(2.0));
        path.lineTo(20.5, 21.0);
        path.arcToPoint(const Offset(22.2, 18.0), radius: const Radius.circular(2.0));
        path.lineTo(13.7, 3.9);
        path.arcToPoint(const Offset(10.3, 3.9), radius: const Radius.circular(2.0));
        path.close();
        canvas.drawPath(path, strokePaint);
        canvas.drawLine(const Offset(12, 9), const Offset(12, 13), strokePaint);
        canvas.drawCircle(const Offset(12, 17), 0.75, fillPaint);
        break;

      case LucideIconData.sparkles:
        final p1 = Path();
        p1.moveTo(12.0, 3.0);
        p1.lineTo(13.8, 7.7);
        p1.lineTo(18.5, 9.5);
        p1.lineTo(13.8, 11.3);
        p1.lineTo(12.0, 16.0);
        p1.lineTo(10.2, 11.3);
        p1.lineTo(5.5, 9.5);
        p1.lineTo(10.2, 7.7);
        p1.close();
        canvas.drawPath(p1, strokePaint);

        final p2 = Path();
        p2.moveTo(19.0, 15.0);
        p2.lineTo(19.8, 17.2);
        p2.lineTo(22.0, 18.0);
        p2.lineTo(19.8, 18.8);
        p2.lineTo(19.0, 21.0);
        p2.lineTo(18.2, 18.8);
        p2.lineTo(16.0, 18.0);
        p2.lineTo(18.2, 17.2);
        p2.close();
        canvas.drawPath(p2, strokePaint);
        break;

      case LucideIconData.shieldCheck:
        final shield = Path();
        shield.moveTo(12.0, 22.0);
        shield.cubicTo(12.0, 22.0, 20.0, 18.0, 20.0, 12.0);
        shield.lineTo(20.0, 5.0);
        shield.lineTo(12.0, 2.0);
        shield.lineTo(4.0, 5.0);
        shield.lineTo(4.0, 12.0);
        shield.cubicTo(4.0, 18.0, 12.0, 22.0, 12.0, 22.0);
        shield.close();
        canvas.drawPath(shield, strokePaint);

        final check = Path();
        check.moveTo(9.0, 12.0);
        check.lineTo(11.0, 14.0);
        check.lineTo(15.0, 10.0);
        canvas.drawPath(check, strokePaint);
        break;

      case LucideIconData.github:
        final path = Path();
        path.moveTo(9, 19);
        path.cubicTo(4.7, 20.4, 4.7, 16.5, 3, 16);
        path.moveTo(15, 21);
        path.lineTo(15, 17.5);
        path.cubicTo(15, 16.5, 15.1, 16.1, 14.5, 15.5);
        path.cubicTo(17.3, 15.2, 20, 14.1, 20, 9.5);
        path.cubicTo(20, 8.2, 19.5, 7.1, 18.7, 6.3);
        path.cubicTo(18.8, 5.1, 18.7, 3.9, 18.6, 3.1);
        path.cubicTo(18.6, 3.1, 17.5, 2.8, 15.1, 4.4);
        path.cubicTo(13.9, 4.1, 12.7, 3.9, 11.5, 3.9);
        path.cubicTo(10.3, 3.9, 9.1, 4.1, 7.9, 4.4);
        path.cubicTo(5.5, 2.8, 4.4, 3.1, 4.4, 3.1);
        path.cubicTo(4.3, 3.9, 4.2, 5.1, 4.3, 6.3);
        path.cubicTo(3.5, 7.1, 3, 8.2, 3, 9.5);
        path.cubicTo(3, 14.1, 5.7, 15.2, 8.5, 15.5);
        path.cubicTo(7.9, 16.1, 7.9, 16.7, 8, 17.5);
        path.lineTo(8, 21);
        canvas.drawPath(path, strokePaint);
        break;

      case LucideIconData.externalLink:
        final path = Path();
        path.moveTo(18, 13);
        path.lineTo(18, 19);
        path.cubicTo(18, 20.1, 17.1, 21, 16, 21);
        path.lineTo(5, 21);
        path.cubicTo(3.9, 21, 3, 20.1, 3, 19);
        path.lineTo(3, 8);
        path.cubicTo(3, 6.9, 3.9, 6, 5, 6);
        path.lineTo(11, 6);
        canvas.drawPath(path, strokePaint);

        final arrow = Path();
        arrow.moveTo(15, 3);
        arrow.lineTo(21, 3);
        arrow.lineTo(21, 9);
        canvas.drawPath(arrow, strokePaint);
        canvas.drawLine(const Offset(10, 14), const Offset(21, 3), strokePaint);
        break;

      case LucideIconData.refreshCw:
        final a1 = Path();
        a1.moveTo(23, 4);
        a1.lineTo(23, 10);
        a1.lineTo(17, 10);
        canvas.drawPath(a1, strokePaint);

        final a2 = Path();
        a2.moveTo(1, 20);
        a2.lineTo(1, 14);
        a2.lineTo(7, 14);
        canvas.drawPath(a2, strokePaint);

        final arc1 = Path();
        arc1.moveTo(3.51, 9);
        arc1.arcToPoint(const Offset(20.49, 15), radius: const Radius.circular(9));
        canvas.drawPath(arc1, strokePaint);
        break;

      case LucideIconData.clock:
        canvas.drawCircle(const Offset(12, 12), 10, strokePaint);
        canvas.drawLine(const Offset(12, 6), const Offset(12, 12), strokePaint);
        canvas.drawLine(const Offset(12, 12), const Offset(16, 14), strokePaint);
        break;

      case LucideIconData.check:
        final path = Path();
        path.moveTo(20, 6);
        path.lineTo(9, 17);
        path.lineTo(4, 12);
        canvas.drawPath(path, strokePaint);
        break;

      case LucideIconData.x:
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), strokePaint);
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), strokePaint);
        break;

      case LucideIconData.layers:
        final p1 = Path();
        p1.moveTo(12, 2);
        p1.lineTo(2, 7);
        p1.lineTo(12, 12);
        p1.lineTo(22, 7);
        p1.close();
        canvas.drawPath(p1, strokePaint);

        final p2 = Path();
        p2.moveTo(2, 12);
        p2.lineTo(12, 17);
        p2.lineTo(22, 12);
        canvas.drawPath(p2, strokePaint);

        final p3 = Path();
        p3.moveTo(2, 17);
        p3.lineTo(12, 22);
        p3.lineTo(22, 17);
        canvas.drawPath(p3, strokePaint);
        break;

      case LucideIconData.activity:
        final path = Path();
        path.moveTo(22, 12);
        path.lineTo(18, 12);
        path.lineTo(15, 21);
        path.lineTo(9, 3);
        path.lineTo(6, 12);
        path.lineTo(2, 12);
        canvas.drawPath(path, strokePaint);
        break;

      case LucideIconData.play:
        final path = Path();
        path.moveTo(5, 3);
        path.lineTo(19, 12);
        path.lineTo(5, 21);
        path.close();
        canvas.drawPath(path, strokePaint);
        break;

      case LucideIconData.share:
        final path = Path();
        path.moveTo(4, 12);
        path.lineTo(4, 20);
        path.cubicTo(4, 20.6, 4.4, 21, 5, 21);
        path.lineTo(19, 21);
        path.cubicTo(19.6, 21, 20, 20.6, 20, 20);
        path.lineTo(20, 12);
        canvas.drawPath(path, strokePaint);

        final arrow = Path();
        arrow.moveTo(16, 6);
        arrow.lineTo(12, 2);
        arrow.lineTo(8, 6);
        canvas.drawPath(arrow, strokePaint);
        canvas.drawLine(const Offset(12, 2), const Offset(12, 15), strokePaint);
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LucidePainter oldDelegate) =>
      oldDelegate.icon != icon ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
