import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';

class S11ServicesScreen extends StatelessWidget {
  const S11ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final services = [
      {
        'id': 'payments-api',
        'sub': '12.4% errors \u00b7 INC-1042',
        'status': 'Degraded',
        'statusBg': colors.criticalSoft,
        'statusFg': colors.critical,
        'iconBg': colors.criticalSoft,
        'iconFg': colors.critical,
        'route': 'detail',
      },
      {
        'id': 'orders-worker',
        'sub': 'Queue backlog 4,210 jobs \u00b7 INC-1041',
        'status': 'Warning',
        'statusBg': colors.warningSoft,
        'statusFg': colors.warning,
        'iconBg': colors.warningSoft,
        'iconFg': colors.warning,
        'route': 'inc_1041',
      },
      {
        'id': 'media-service',
        'sub': 'P95 1.1 s \u00b7 INC-1040',
        'status': 'Warning',
        'statusBg': colors.warningSoft,
        'statusFg': colors.warning,
        'iconBg': colors.warningSoft,
        'iconFg': colors.warning,
        'route': 'inc_1040',
      },
      {
        'id': 'catalog-api',
        'sub': '0.1% errors \u00b7 P95 85 ms',
        'status': 'Healthy',
        'statusBg': colors.successSoft,
        'statusFg': colors.success,
        'iconBg': colors.successSoft,
        'iconFg': colors.success,
        'route': null,
      },
      {
        'id': 'edge-gateway',
        'sub': '0.0% errors \u00b7 P95 24 ms',
        'status': 'Healthy',
        'statusBg': colors.successSoft,
        'statusFg': colors.success,
        'iconBg': colors.successSoft,
        'iconFg': colors.success,
        'route': null,
      },
      {
        'id': 'auth-service',
        'sub': '0.0% errors \u00b7 P95 95 ms',
        'status': 'Healthy',
        'statusBg': colors.successSoft,
        'statusFg': colors.success,
        'iconBg': colors.successSoft,
        'iconFg': colors.success,
        'route': null,
      },
    ];

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
                        'Monitor',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.52,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Production \u00b7 6 services',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/search');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      alignment: Alignment.center,
                      child: LucideIcon(LucideIconData.search, size: 20, color: colors.text),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Segmented tabs: Services | Logs | Metrics
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.cardSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Services',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/logs');
                            },
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              child: Text(
                                'Logs',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/metrics');
                            },
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              child: Text(
                                'Metrics',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 6 Service Cards
                  ...services.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () {
                          if (s['route'] == 'detail') {
                            Navigator.pushNamed(context, '/service-details');
                          } else if (s['route'] == 'inc_1041') {
                            Navigator.pushNamed(context, '/inc-1041');
                          } else if (s['route'] == 'inc_1040') {
                            Navigator.pushNamed(context, '/inc-1040');
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: s['iconBg'] as Color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: LucideIcon(
                                  LucideIconData.server,
                                  size: 20,
                                  color: s['iconFg'] as Color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s['id'] as String,
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: colors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s['sub'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: s['statusBg'] as Color,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  s['status'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: s['statusFg'] as Color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              LucideIcon(LucideIconData.chevronRight, size: 18, color: colors.muted),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  // Footer note
                  Text(
                    'Health from Prometheus \u00b7 updated 30 s ago',
                    textAlign: TextAlign.center,
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
      bottomNavigationBar: const AppBottomNav(currentRoute: 'monitor'),
    );
  }
}
