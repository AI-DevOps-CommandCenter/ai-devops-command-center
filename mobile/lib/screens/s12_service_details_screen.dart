import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S12ServiceDetailsScreen extends StatelessWidget {
  const S12ServiceDetailsScreen({super.key});

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'payments-api',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'Production',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.muted,
                          ),
                        ),
                      ],
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
                    // Status & Health Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Status',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              _buildBadge('Degraded', colors.badgeAmberBg, colors.amber),
                            ],
                          ),
                          Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                          _buildRow(colors, 'Error rate', '12.4%'),
                          Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                          _buildRow(colors, 'P95', '2.4 s'),
                          Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                          _buildRow(colors, 'CPU / Mem', '71% / 64%'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Deployments
                    Text(
                      'Deployments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Deployment v2.8.1 (Suspect)
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/deployment-details');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCard(
                        colors: colors,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 13, color: colors.text),
                                children: [
                                  const TextSpan(text: 'v2.8.1', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: ' · 14:05 · ', style: TextStyle(color: colors.muted)),
                                ],
                              ),
                            ),
                            _buildBadge('Suspect', colors.badgeRedBg, colors.red),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Deployment v2.8.0 (Healthy)
                    _buildCard(
                      colors: colors,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 13, color: colors.text),
                              children: [
                                const TextSpan(text: 'v2.8.0', style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: ' · yesterday 16:40 · ', style: TextStyle(color: colors.muted)),
                              ],
                            ),
                          ),
                          _buildBadge('Healthy', colors.badgeGreenBg, colors.green),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Related Incident
                    Text(
                      'Related incident',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Incident Card
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'INC-1042',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colors.text,
                                  ),
                                ),
                                _buildBadge('Critical', colors.badgeRedBg, colors.red),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Elevated errors after deployment',
                              style: TextStyle(fontSize: 13, color: colors.text),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'payments-api · Production',
                                  style: TextStyle(fontSize: 11, color: colors.muted),
                                ),
                                _buildBadge('Investigating', colors.badgeAmberBg, colors.amber),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // View Logs Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/logs');
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
                          'View Logs',
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
      bottomNavigationBar: const AppBottomNav(currentRoute: 's11'),
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

  Widget _buildBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}
