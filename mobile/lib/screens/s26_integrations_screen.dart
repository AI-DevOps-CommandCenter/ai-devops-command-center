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
                  Text(
                    'Integrations',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
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
                              item['name'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOk ? colors.badgeGreenBg : colors.badgeRedBg,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                item['status'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isOk ? colors.green : colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last sync ${item['lastSync']}',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: OutlinedButton(
                            onPressed: isSyncing ? null : () => _reconnect(index),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: colors.cardAccent,
                              foregroundColor: colors.text,
                              side: BorderSide(color: colors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isSyncing
                                  ? 'Connecting…'
                                  : (isOk ? 'Reconnect' : 'Retry sync'),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.text),
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
