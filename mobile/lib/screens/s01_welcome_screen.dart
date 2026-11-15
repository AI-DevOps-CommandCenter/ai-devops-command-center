import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';

class S01WelcomeScreen extends StatelessWidget {
  const S01WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero top section
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BrandLogo(size: 104),
                            const SizedBox(height: 14),
                            Column(
                              children: [
                                Text(
                                  'DEVOPS',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2.86,
                                    color: colors.accent,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Command Center',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.64,
                                    color: colors.text,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 270),
                              child: Text(
                                'From alert to verified fix, on your phone.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.45,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Feature list (ol): gap 10px
                  Column(
                    children: [
                      _buildFeatureItem(
                        context,
                        icon: _FeatureIconType.detect,
                        title: 'Detect',
                        subtitle: 'Alerts from Prometheus and Loki',
                      ),
                      const SizedBox(height: 10),
                      _buildFeatureItem(
                        context,
                        icon: _FeatureIconType.investigate,
                        title: 'Investigate',
                        subtitle: 'AI checks logs, metrics and deploys',
                      ),
                      const SizedBox(height: 10),
                      _buildFeatureItem(
                        context,
                        icon: _FeatureIconType.recover,
                        title: 'Recover safely',
                        subtitle: 'Reviewed playbooks with your approval',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. Get started button: min-height 48px, radius 12px
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/signin');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.onAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colors.accent),
                        ),
                      ),
                      child: const Text(
                        'Get started',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Footer
                  Text(
                    'Group 33 ·',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required _FeatureIconType icon,
    required String title,
    required String subtitle,
  }) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(
                painter: _LucideIconPainter(
                  type: icon,
                  color: colors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _FeatureIconType {
  detect,
  investigate,
  recover,
}

class _LucideIconPainter extends CustomPainter {
  final _FeatureIconType type;
  final Color color;

  _LucideIconPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case _FeatureIconType.detect:
        // alert-triangle:
        // M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z
        final path = Path();
        path.moveTo(10.3, 3.9);
        path.lineTo(1.8, 18.0);
        path.arcToPoint(
          const Offset(3.5, 21.0),
          radius: const Radius.circular(2.0),
        );
        path.lineTo(20.5, 21.0);
        path.arcToPoint(
          const Offset(22.2, 18.0),
          radius: const Radius.circular(2.0),
        );
        path.lineTo(13.7, 3.9);
        path.arcToPoint(
          const Offset(10.3, 3.9),
          radius: const Radius.circular(2.0),
        );
        path.close();
        canvas.drawPath(path, strokePaint);

        // vertical exclamation stroke: M12 9v4
        canvas.drawLine(const Offset(12, 9), const Offset(12, 13), strokePaint);

        // dot: M12 17h.01
        canvas.drawCircle(const Offset(12, 17), 0.75, Paint()..color = color..style = PaintingStyle.fill);
        break;

      case _FeatureIconType.investigate:
        // sparkles:
        // M12 3l1.8 4.7 4.7 1.8-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8z
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

        // M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z
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

      case _FeatureIconType.recover:
        // shield-check:
        // M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z
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

        // checkmark: m9 12 2 2 4-4
        final check = Path();
        check.moveTo(9.0, 12.0);
        check.lineTo(11.0, 14.0);
        check.lineTo(15.0, 10.0);
        canvas.drawPath(check, strokePaint);
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
