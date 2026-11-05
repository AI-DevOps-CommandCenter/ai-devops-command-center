import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S28ProfileScreen extends StatelessWidget {
  const S28ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = ThemeController.instance.isDark;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.text, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Operator Profile Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alex Morgan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Operator · Default env: Production',
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Theme Switcher Card (Light / Dark Mode)
                    _buildCard(
                      colors: colors,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDark ? Icons.dark_mode : Icons.light_mode,
                                color: colors.teal,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dark Mode',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: colors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isDark ? 'Dark theme active' : 'Light theme active',
                                    style: TextStyle(fontSize: 12, color: colors.muted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: isDark,
                            activeColor: colors.teal,
                            onChanged: (_) {
                              ThemeController.instance.toggleTheme();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Playbooks
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/playbooks');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCard(
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Playbooks',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '4 reviewed playbooks',
                              style: TextStyle(fontSize: 12, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Integrations
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/integrations');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCard(
                        colors: colors,
                        child: Text(
                          'Integrations',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Preferences
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/preferences');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCard(
                        colors: colors,
                        child: Text(
                          'Preferences',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Demo Information
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Demo information',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Simulated data only. Scenario: INC-1042.',
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Reset Demo Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demo state reset successfully.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: colors.cardAccent,
                          foregroundColor: colors.text,
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Reset Demo',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Sign Out Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: colors.cardAccent,
                          foregroundColor: colors.text,
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Sign Out',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 's28'),
    );
  }

  Widget _buildCard({required AppColorScheme colors, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: colors.isDark ? Colors.black.withOpacity(0.3) : const Color.fromRGBO(15, 27, 51, 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
