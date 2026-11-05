import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S14DeploymentDetailsScreen extends StatelessWidget {
  const S14DeploymentDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
                      'Deployment v2.8.1',
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
                    // Overview Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        children: [
                          _buildRow(colors, 'Environment', 'Production'),
                          Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                          _buildRow(colors, 'Commit', 'a91f3c2'),
                          Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                          _buildRow(colors, 'Deployed', '14:05 UTC'),
                          Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                          _buildRow(colors, 'Pipeline', '#318 passed'),
                          Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                          _buildRow(colors, 'Previous', 'v2.8.0'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Changes Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Changes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Lower DB pool timeout, add retry wrapper, update logging.',
                            style: TextStyle(fontSize: 13, color: colors.text, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Related Incident Card
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/incident-details');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border(
                            left: BorderSide(color: colors.red, width: 4),
                            top: BorderSide(color: colors.cardBorder, width: 0.8),
                            right: BorderSide(color: colors.cardBorder, width: 0.8),
                            bottom: BorderSide(color: colors.cardBorder, width: 0.8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.isDark ? Colors.black.withOpacity(0.3) : const Color.fromRGBO(15, 27, 51, 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Related incident',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'INC-1042 started 7 minutes after this deploy',
                              style: TextStyle(fontSize: 13, color: colors.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pull request Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/pull-request');
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
                          'Pull request',
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

  Widget _buildRow(AppColorScheme colors, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.muted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
      ],
    );
  }
}
