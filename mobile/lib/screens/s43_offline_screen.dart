import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 's04_incidents_screen.dart';

class S43OfflineScreen extends StatelessWidget {
  const S43OfflineScreen({super.key});

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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Incidents',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.52,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Showing saved data',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Offline warning banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.warningSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 22, color: colors.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You are offline',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Showing data from 14:16. Approvals and actions are paused until you reconnect.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Cached incident 1: INC-1042 (red bar)
                  _buildCachedIncidentCard(
                    context,
                    indicatorColor: colors.critical,
                    id: 'INC-1042',
                    title: 'Elevated errors after deployment',
                    service: 'payments-api \u00b7 Production',
                  ),

                  const SizedBox(height: 14),

                  // Cached incident 2: INC-1041 (amber bar)
                  _buildCachedIncidentCard(
                    context,
                    indicatorColor: colors.warning,
                    id: 'INC-1041',
                    title: 'Queue backlog growing',
                    service: 'orders-worker \u00b7 Production',
                  ),

                  const SizedBox(height: 14),

                  // Cached incident 3: INC-1040 (amber bar)
                  _buildCachedIncidentCard(
                    context,
                    indicatorColor: colors.warning,
                    id: 'INC-1040',
                    title: 'Slow image resizing',
                    service: 'media-service \u00b7 Production',
                  ),

                  const SizedBox(height: 14),

                  // Disabled button
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.cardSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Approve rollback (needs connection)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Retry connection button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const S04IncidentsScreen(),
                          ),
                        );
                      },
                      icon: Icon(Icons.refresh_rounded, size: 18, color: colors.text),
                      label: Text(
                        'Retry connection',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: colors.card,
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'incidents'),
    );
  }

  Widget _buildCachedIncidentCard(
    BuildContext context, {
    required Color indicatorColor,
    required String id,
    required String title,
    required String service,
  }) {
    final colors = context.colors;
    return Opacity(
      opacity: 0.85,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
