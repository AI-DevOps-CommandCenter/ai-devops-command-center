import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';

class S02SignInScreen extends StatefulWidget {
  const S02SignInScreen({super.key});

  @override
  State<S02SignInScreen> createState() => _S02SignInScreenState();
}

class _S02SignInScreenState extends State<S02SignInScreen> {
  final TextEditingController _emailController =
      TextEditingController(text: 'alex.morgan@demo.dev');
  final TextEditingController _passwordController =
      TextEditingController(text: 'demo-password');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateToDashboard() {
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 28,
                    maxWidth: 420,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header: padding: 40px 8px 12px, gap: 12px
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 40, 8, 12),
                          child: Column(
                            children: [
                              const BrandLogo(size: 72),
                              const SizedBox(height: 12),
                              Text(
                                'Sign in to Command Center',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.52,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 300),
                                child: Text(
                                  'Detect, investigate and recover from production incidents without leaving your phone.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.45,
                                    color: colors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Form section: gap 14px
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),

                            // Work email
                            Text(
                              'Work email',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(fontSize: 15, color: colors.text),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Password
                            Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border),
                              ),
                              padding: const EdgeInsets.only(left: 14, right: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style: TextStyle(fontSize: 15, color: colors.text),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: IconButton(
                                      icon: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CustomPaint(
                                          painter: _LucideEyePainter(
                                            obscure: _obscurePassword,
                                            color: colors.muted,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Forgot password?
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pushNamed(context, '/forgot-password');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Sign in button
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _navigateToDashboard,
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
                                  'Sign in',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // "or" divider
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: colors.border,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: colors.border,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Continue with GitHub
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _navigateToDashboard,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: colors.card,
                              side: BorderSide(color: colors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(18, 18),
                                  painter: _GithubIconPainter(color: colors.text),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Continue with GitHub',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Try demo as Alex Morgan
                        InkWell(
                          onTap: _navigateToDashboard,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.accentSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: colors.accent,
                                  child: Text(
                                    'AM',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: colors.onAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Try the demo as Alex Morgan',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text,
                                        ),
                                      ),
                                      Text(
                                        'Tech lead · can approve playbooks',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CustomPaint(
                                    painter: _LucideChevronRightPainter(color: colors.text),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Bottom push spacer
                        const Spacer(),

                        // Footer
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Group 33 ·',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LucideEyePainter extends CustomPainter {
  final bool obscure;
  final Color color;
  _LucideEyePainter({required this.obscure, required this.color});

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

    if (obscure) {
      // eye:
      // M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z
      final eye = Path();
      eye.moveTo(2, 12);
      eye.cubicTo(5.5, 5, 12, 5, 12, 5);
      eye.cubicTo(12, 5, 18.5, 5, 22, 12);
      eye.cubicTo(18.5, 19, 12, 19, 12, 19);
      eye.cubicTo(5.5, 19, 2, 12, 2, 12);
      eye.close();
      canvas.drawPath(eye, strokePaint);

      // circle: cx="12" cy="12" r="3"
      canvas.drawCircle(const Offset(12, 12), 3, strokePaint);
    } else {
      // eye-off:
      final eye = Path();
      eye.moveTo(2, 12);
      eye.cubicTo(5.5, 5, 12, 5, 12, 5);
      eye.cubicTo(12, 5, 18.5, 5, 22, 12);
      canvas.drawPath(eye, strokePaint);
      canvas.drawLine(const Offset(2, 2), const Offset(22, 22), strokePaint);
      canvas.drawCircle(const Offset(12, 12), 3, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LucideEyePainter oldDelegate) =>
      oldDelegate.obscure != obscure || oldDelegate.color != color;
}

class _LucideChevronRightPainter extends CustomPainter {
  final Color color;
  _LucideChevronRightPainter({required this.color});

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

    final path = Path();
    path.moveTo(9, 18);
    path.lineTo(15, 12);
    path.lineTo(9, 6);
    canvas.drawPath(path, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LucideChevronRightPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GithubIconPainter extends CustomPainter {
  final Color color;
  _GithubIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Lucide github icon:
    // M9 19c-4.3 1.4-4.3-2.5-6-3m12 5v-3.5c0-1 .1-1.4-.5-2 2.8-.3 5.5-1.4 5.5-6a4.6 4.6 0 0 0-1.3-3.2 4.2 4.2 0 0 0-.1-3.2s-1.1-.3-3.5 1.3a12.3 12.3 0 0 0-6.2 0C6.5 2.8 5.4 3.1 5.4 3.1a4.2 4.2 0 0 0-.1 3.2A4.6 4.6 0 0 0 4 9.5c0 4.6 2.7 5.7 5.5 6-.6.6-.6 1.2-.5 2V21
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

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GithubIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
