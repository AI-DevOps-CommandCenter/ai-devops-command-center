import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 's05_incident_details_screen.dart';

class S03OverviewDashboardScreen extends StatelessWidget {
  const S03OverviewDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
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
                          'Overview',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'Alex Morgan · Production',
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

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overall Health Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Overall health',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: colors.text,
                                ),
                              ),
                              _buildBadge('Degraded', colors.badgeAmberBg, colors.amber),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1 of 6 services degraded',
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Metrics Grid (2 columns x 3 rows)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.55,
                      children: [
                        _buildMetricCard(colors, 'Critical', '1', color: colors.red),
                        _buildMetricCard(colors, 'Warning', '2', color: colors.amber),
                        _buildMetricCard(colors, 'CPU', '71%'),
                        _buildMetricCard(colors, 'Memory', '64%'),
                        _buildMetricCard(colors, 'Error rate', '12.4%', color: colors.red),
                        _buildMetricCard(colors, 'P95 latency', '2.4 s', color: colors.red),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Pending Approval Card
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/approve-action');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCard(
                        colors: colors,
                        borderLeftColor: colors.amber,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1 approval pending',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Roll back payments-api to v2.8.0',
                              style: TextStyle(fontSize: 12, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recent Incidents Section Header
                    Text(
                      'Recent incidents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Incident 1: INC-1042 (Critical)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const S05IncidentDetailsScreen(
                              incidentId: 'INC-1042',
                              incidentTitle: 'Elevated errors after deployment',
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildIncidentCard(
                        colors: colors,
                        id: 'INC-1042',
                        title: 'Elevated errors after deployment',
                        service: 'payments-api · Production',
                        severity: 'Critical',
                        severityBg: colors.badgeRedBg,
                        severityColor: colors.red,
                        status: 'Investigating',
                        statusBg: colors.badgeAmberBg,
                        statusColor: colors.amber,
                        borderLeftColor: colors.red,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Incident 2: INC-1041 (Warning)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const S05IncidentDetailsScreen(
                              incidentId: 'INC-1041',
                              incidentTitle: 'Queue backlog growing',
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildIncidentCard(
                        colors: colors,
                        id: 'INC-1041',
                        title: 'Queue backlog growing',
                        service: 'orders-worker · Production',
                        severity: 'Warning',
                        severityBg: colors.badgeAmberBg,
                        severityColor: colors.amber,
                        status: 'Monitoring',
                        statusBg: colors.badgeAmberBg,
                        statusColor: colors.amber,
                        borderLeftColor: colors.amber,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Persistent Bottom Navigation Bar
            const AppBottomNav(currentRoute: 's03'),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required AppColorScheme colors,
    required Widget child,
    Color? borderLeftColor,
  }) {
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
      child: borderLeftColor != null
          ? IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: borderLeftColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: child),
                ],
              ),
            )
          : child,
    );
  }

  Widget _buildMetricCard(AppColorScheme colors, String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: colors.isDark ? Colors.black.withOpacity(0.25) : const Color.fromRGBO(15, 27, 51, 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color ?? colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard({
    required AppColorScheme colors,
    required String id,
    required String title,
    required String service,
    required String severity,
    required Color severityBg,
    required Color severityColor,
    required String status,
    required Color statusBg,
    required Color statusColor,
    required Color borderLeftColor,
  }) {
    return _buildCard(
      colors: colors,
      borderLeftColor: borderLeftColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                id,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.text),
              ),
              _buildBadge(severity, severityBg, severityColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 13, color: colors.text),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                service,
                style: TextStyle(fontSize: 12, color: colors.muted),
              ),
              _buildBadge(status, statusBg, statusColor),
            ],
          ),
        ],
      ),
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
