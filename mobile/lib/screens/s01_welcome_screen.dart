import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 's02_signin_screen.dart';

class S01WelcomeScreen extends StatelessWidget {
  const S01WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Big Teal Diamond Symbol (◈)
                    Text(
                      '◈',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: colors.teal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title: DevOps Command Center
                    Text(
                      'DevOps Command Center',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Subtitle
                    Text(
                      'Detect, investigate and recover from production incidents without leaving your phone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              // Get Started Primary Button (btn p)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const S02SignInScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.teal,
                    foregroundColor: colors.isDark ? const Color(0xFF06202A) : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
