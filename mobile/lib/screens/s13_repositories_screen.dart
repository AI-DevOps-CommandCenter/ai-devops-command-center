import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S13RepositoriesScreen extends StatelessWidget {
  const S13RepositoriesScreen({super.key});

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
                      'Repositories',
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
                    // Repository 1 header card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'github.com/demo-org/payments-api',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'GitHub · main',
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Recent commit
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/pull-request');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCard(
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent commit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'a91f3c2 Tune DB pool settings',
                              style: TextStyle(fontSize: 13, color: colors.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // PR #214
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/pull-request');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCard(
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PR #214',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: colors.text,
                                  ),
                                ),
                                _buildBadge('Merged', colors.badgeGreenBg, colors.green),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tune DB pool settings',
                              style: TextStyle(fontSize: 13, color: colors.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Pipeline #318 (Failed job)
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/pipeline-job');
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
                                  'Pipeline #318',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: colors.text,
                                  ),
                                ),
                                _buildBadge('Failed job', colors.badgeRedBg, colors.red),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'integration-tests',
                              style: TextStyle(fontSize: 12, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Deployment v2.8.1
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/deployment-details');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCard(
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Deployment v2.8.1',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Production · 14:05',
                              style: TextStyle(fontSize: 12, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Repository 2
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'gitlab.com/demo-org/orders-worker',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'GitLab · pipeline passed',
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
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
