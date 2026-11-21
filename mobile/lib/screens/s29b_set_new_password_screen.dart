import 'package:flutter/material.dart';
import '../services/password_recovery.dart';
import '../theme/app_colors.dart';
import 's29_forgot_password_screen.dart' show ResetMessageBox, resetInputDecoration;

/// S29b – set a new password after opening the reset email link
/// (POST /api/auth/reset-password with the recovery token from the link).
/// Opened by main.dart when the page URL carries a recovery link.
class S29bSetNewPasswordScreen extends StatefulWidget {
  final RecoveryLink? link;
  final PasswordResetService? service;
  const S29bSetNewPasswordScreen({super.key, this.link, this.service});

  @override
  State<S29bSetNewPasswordScreen> createState() => _S29bSetNewPasswordScreenState();
}

class _S29bSetNewPasswordScreenState extends State<S29bSetNewPasswordScreen> {
  static const minLength = 8;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final PasswordResetService _service = widget.service ?? PasswordResetService();
  late final RecoveryLink? _link = widget.link ?? PasswordRecovery.take();
  bool _saving = false;
  bool _obscure = true;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    if (password.length < minLength) {
      setState(() => _error = 'Use at least $minLength characters.');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.setNewPassword(_link!.accessToken!, password);
      if (mounted) setState(() => _done = true);
    } on PasswordResetException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toSignIn() => Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final link = _link;

    Widget button(String label, VoidCallback? onPressed, {Key? key, bool busy = false}) => SizedBox(
          height: 48,
          child: ElevatedButton(
            key: key,
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: busy
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onAccent))
                : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        );

    final List<Widget> content;
    if (link == null || !link.hasToken) {
      content = [
        ResetMessageBox(
          colors: colors,
          icon: Icons.link_off,
          color: colors.critical,
          title: 'Reset link not valid',
          body: link?.errorMessage ?? 'Open the link from the reset email, or request a new one.',
        ),
        const SizedBox(height: 16),
        button('Request a new link', () => Navigator.pushReplacementNamed(context, '/forgot-password')),
      ];
    } else if (_done) {
      content = [
        ResetMessageBox(
          colors: colors,
          icon: Icons.check_circle_outline,
          color: colors.success,
          title: 'Password changed',
          body: 'Sign in with your new password.',
        ),
        const SizedBox(height: 16),
        button('Go to sign in', _toSignIn, key: const Key('reset-to-signin')),
      ];
    } else {
      final toggle = IconButton(
        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: colors.muted),
        onPressed: () => setState(() => _obscure = !_obscure),
        tooltip: _obscure ? 'Show password' : 'Hide password',
      );
      content = [
        Text('Choose a new password for your account (at least $minLength characters).',
            style: TextStyle(fontSize: 14, height: 1.45, color: colors.muted)),
        const SizedBox(height: 16),
        Text('New password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
        const SizedBox(height: 6),
        TextField(
          key: const Key('reset-password'),
          controller: _password,
          obscureText: _obscure,
          enabled: !_saving,
          autofillHints: const [AutofillHints.newPassword],
          style: TextStyle(color: colors.text, fontSize: 15),
          decoration: resetInputDecoration(colors, suffix: toggle),
        ),
        const SizedBox(height: 12),
        Text('Repeat new password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
        const SizedBox(height: 6),
        TextField(
          key: const Key('reset-confirm'),
          controller: _confirm,
          obscureText: _obscure,
          enabled: !_saving,
          onSubmitted: (_) => _save(),
          style: TextStyle(color: colors.text, fontSize: 15),
          decoration: resetInputDecoration(colors),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          ResetMessageBox(colors: colors, icon: Icons.error_outline, color: colors.critical, title: _error!),
        ],
        const SizedBox(height: 20),
        button('Set new password', _saving ? null : _save, key: const Key('reset-save'), busy: _saving),
      ];
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Text('Set a new password',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.2, color: colors.text)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
