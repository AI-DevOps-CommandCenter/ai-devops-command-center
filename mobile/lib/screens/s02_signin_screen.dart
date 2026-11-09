import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import 's03_overview_dashboard_screen.dart';

class S02SignInScreen extends StatefulWidget {
  const S02SignInScreen({super.key});

  @override
  State<S02SignInScreen> createState() => _S02SignInScreenState();
}

class _S02SignInScreenState extends State<S02SignInScreen> {
  final TextEditingController _emailController = TextEditingController(text: 'alex@example.com');
  final TextEditingController _passwordController = TextEditingController(text: 'password123');
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AuthController.instance.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    AuthController.instance.removeListener(_onAuthStateChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Enter a valid email.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password must be 6+ characters.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    // Authenticate via Himasha's AuthController & Vinuka's Backend /api/me
    final success = await AuthController.instance.signIn(
      email: email,
      password: password,
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const S03OverviewDashboardScreen(),
        ),
      );
    } else if (mounted) {
      setState(() {
        _errorMessage = AuthController.instance.errorMessage ?? 'Authentication failed.';
      });
    }
  }

  Future<void> _enterDemo() async {
    await AuthController.instance.enterDemoMode();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const S03OverviewDashboardScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLoading = AuthController.instance.isLoading;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Title: <h1>Sign in</h1>
              Text(
                'Sign in',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 20),

              // Email Input: <input class="in" id="em" placeholder="Email">
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: colors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _emailController,
                  style: TextStyle(fontSize: 14, color: colors.text),
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle: TextStyle(color: colors.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Password row with Show/Hide toggle
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(fontSize: 14, color: colors.text),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: colors.muted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: colors.cardAccent,
                        foregroundColor: colors.text,
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        _obscurePassword ? 'Show' : 'Hide',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colors.text),
                      ),
                    ),
                  ),
                ],
              ),

              // Error Message box (if validation or auth fails)
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.badgeRedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Primary Button: Sign In (with real loading indicator)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.teal,
                    foregroundColor: colors.isDark ? const Color(0xFF06202A) : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary Button: Enter Demo as Alex Morgan
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: isLoading ? null : _enterDemo,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.cardAccent,
                    foregroundColor: colors.text,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Enter Demo as Alex Morgan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
