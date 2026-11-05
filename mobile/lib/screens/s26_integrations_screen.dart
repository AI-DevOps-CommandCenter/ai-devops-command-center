import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S26IntegrationsScreen extends StatefulWidget {
  const S26IntegrationsScreen({super.key});

  @override
  State<S26IntegrationsScreen> createState() => _S26IntegrationsScreenState();
}

class _S26IntegrationsScreenState extends State<S26IntegrationsScreen> {
  final List<Map<String, dynamic>> _integrations = [
    {'name': 'GitHub', 'status': 'Connected', 'isOk': true, 'lastSync': '2 min ago', 'syncing': false},
    {'name': 'GitLab', 'status': 'Connected', 'isOk': true, 'lastSync': '2 min ago', 'syncing': false},
    {'name': 'Prometheus', 'status': 'Connected', 'isOk': true, 'lastSync': '2 min ago', 'syncing': false},
    {'name': 'Loki', 'status': 'Sync failed', 'isOk': false, 'lastSync': '2 h ago', 'syncing': false},
    {'name': 'Slack', 'status': 'Connected', 'isOk': true, 'lastSync': '2 min ago', 'syncing': false},
    {'name': 'Discord', 'status': 'Connected', 'isOk': true, 'lastSync': '2 min ago', 'syncing': false},
  ];

  void _reconnect(int index) {
    setState(() {
      _integrations[index]['syncing'] = true;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _integrations[index]['syncing'] = false;
          _integrations[index]['status'] = 'Connected';
          _integrations[index]['isOk'] = true;
          _integrations[index]['lastSync'] = 'Just now (simulated)';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.text, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Integrations',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                itemCount: _integrations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _integrations[index];
                  final isOk = item['isOk'] as bool;
                  final isSyncing = item['syncing'] as bool;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder, width: 0.8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(15, 27, 51, 0.06),
                          blurRadius: 4,
                          offset: Offset(0, 1),
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
                              item['name'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOk ? AppColors.badgeGreenBg : AppColors.badgeRedBg,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                item['status'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isOk ? AppColors.green : AppColors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last sync ${item['lastSync']}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: OutlinedButton(
                            onPressed: isSyncing ? null : () => _reconnect(index),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.cardAccent,
                              foregroundColor: AppColors.text,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isSyncing
                                  ? 'Connecting…'
                                  : (isOk ? 'Reconnect' : 'Retry sync'),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 's28'),
    );
  }
}
