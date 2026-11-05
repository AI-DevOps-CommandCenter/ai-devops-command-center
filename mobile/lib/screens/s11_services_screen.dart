import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S11ServicesScreen extends StatelessWidget {
  const S11ServicesScreen({super.key});

  final List<Map<String, dynamic>> services = const [
    {
      'name': 'payments-api',
      'status': 'Degraded',
      'isHealthy': false,
      'details': 'Production · 12.4% errors · 1 active incident',
    },
    {
      'name': 'orders-worker',
      'status': 'Warning',
      'isHealthy': false,
      'details': 'Production · Queue 4.2k',
    },
    {
      'name': 'catalog-api',
      'status': 'Healthy',
      'isHealthy': true,
      'details': 'Production · 0.1% errors',
    },
    {
      'name': 'media-service',
      'status': 'Warning',
      'isHealthy': false,
      'details': 'Production · P95 1.1 s',
    },
    {
      'name': 'edge-gateway',
      'status': 'Healthy',
      'isHealthy': true,
      'details': 'Production · 0.0% errors',
    },
    {
      'name': 'auth-service',
      'status': 'Healthy',
      'isHealthy': true,
      'details': 'Production · P95 95 ms',
    },
  ];

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
                          'Services',
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

            // Content List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                itemCount: services.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final svc = services[index];
                  final isHealthy = svc['isHealthy'] as bool;

                  return InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/service-details');
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                svc['name'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isHealthy ? colors.badgeGreenBg : colors.badgeAmberBg,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  svc['status'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isHealthy ? colors.green : colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            svc['details'],
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 's11'),
    );
  }
}
