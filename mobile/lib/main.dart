import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'screens/s01_welcome_screen.dart';
import 'screens/s02_signin_screen.dart';
import 'screens/s03_overview_dashboard_screen.dart';

void main() {
  runApp(const DevOpsCommandCenterApp());
}

class DevOpsCommandCenterApp extends StatelessWidget {
  const DevOpsCommandCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevOps Command Center',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: 'Segoe UI',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          primary: AppColors.teal,
          background: AppColors.bg,
        ),
        useMaterial3: false,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const S01WelcomeScreen(),
        '/signin': (context) => const S02SignInScreen(),
        '/dashboard': (context) => const S03OverviewDashboardScreen(),
      },
    );
  }
}
