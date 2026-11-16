import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';
import '../controllers/auth_controller.dart';

class S02SignInScreen extends StatefulWidget {
  const S02SignInScreen({super.key});

  @override
  State<S02SignInScreen> createState() => _S02SignInScreenState();
}

class _S02SignInScreenState extends State<S02SignInScreen> {
  final TextEditingController _emailController =
      TextEditingController(text: '');
  final TextEditingController _passwordController =
      TextEditingController(text: '');
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both work email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await AuthController.instance.signIn(
      email: email,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      setState(() {
        _errorMessage = AuthController.instance.errorMessage ?? 'Invalid login credentials.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? 'Invalid login credentials.'),
          backgroundColor: context.colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: colors.red.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: colors.red.withOpacity(0.4)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
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
                                decoration: InputDecoration(
                                  hintText: 'name@company.com',
                                  hintStyle: TextStyle(
                                    fontSize: 15,
                                    color: colors.muted,
                                  ),
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
                                      decoration: InputDecoration(
                                        hintText: '••••••••••••',
                                        hintStyle: TextStyle(
                                          fontSize: 15,
                                          color: colors.muted,
                                        ),
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
                                onPressed: _isLoading ? null : _handleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.accent,
                                  foregroundColor: colors.onAccent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: colors.accent),
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(colors.onAccent),
                                        ),
                                      )
                                    : const Text(
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
