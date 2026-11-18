import 'package:flutter/material.dart';
import '../services/password_recovery.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';

/// S29 – request a password reset email (POST /api/auth/forgot-password).
/// The email link opens the app on S29b (/reset-password).
class S29ForgotPasswordScreen extends StatefulWidget {
  final PasswordResetService? service;
  const S29ForgotPasswordScreen({super.key, this.service});

  @override
  State<S29ForgotPasswordScreen> createState() => _S29ForgotPasswordScreenState();
}

class _S29ForgotPasswordScreenState extends State<S29ForgotPasswordScreen> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  final TextEditingController _emailController = TextEditingController();
  late final PasswordResetService _service = widget.service ?? PasswordResetService();
  bool _sending = false;
  String? _sentMessage;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await _service.requestReset(email);
      if (mounted) setState(() => _sentMessage = message);
    } on PasswordResetException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sent = _sentMessage != null;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reset password',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.2, color: colors.text),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enter the email of your account. We will send a link to set a new password.',
                      style: TextStyle(fontSize: 14, height: 1.45, color: colors.muted),
                    ),
                    const SizedBox(height: 16),
                    Text('Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('forgot-email'),
                      controller: _emailController,
                      enabled: !sent && !_sending,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(color: colors.text, fontSize: 15),
                      decoration: resetInputDecoration(colors, hint: 'name@company.com'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      ResetMessageBox(colors: colors, icon: Icons.error_outline, color: colors.critical, title: _error!),
                    ],
                    const SizedBox(height: 20),
                    if (!sent)
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('forgot-send'),
                          onPressed: _sending ? null : _send,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: colors.onAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _sending
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.onAccent),
                                )
                              : const Text('Send reset link', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      )
                    else ...[
                      ResetMessageBox(
                        colors: colors,
                        icon: Icons.mail_outline,
                        color: colors.success,
                        title: 'Check your inbox',
                        body: '$_sentMessage Open the link on this device. It can be used once and expires after one hour.',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: colors.card,
                            side: BorderSide(color: colors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Back to sign in',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text field style shared by S29 and S29b.
InputDecoration resetInputDecoration(AppColorScheme colors, {String? hint, Widget? suffix}) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    filled: true,
    fillColor: colors.card,
    hintText: hint,
    hintStyle: TextStyle(color: colors.muted),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(colors.border),
    enabledBorder: border(colors.border),
    disabledBorder: border(colors.border),
    focusedBorder: border(colors.accent, 1.5),
  );
}

/// Coloured message box shared by S29 and S29b.
class ResetMessageBox extends StatelessWidget {
  final AppColorScheme colors;
  final IconData icon;
  final Color color;
  final String title;
  final String? body;
  const ResetMessageBox({super.key, required this.colors, required this.icon, required this.color, required this.title, this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.text)),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(body!, style: TextStyle(fontSize: 13, height: 1.35, color: colors.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
