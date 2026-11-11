import 'package:flutter/material.dart';
import '../models/playbook_model.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S16RemediationPlaybooksScreen extends StatelessWidget {
  const S16RemediationPlaybooksScreen({super.key});

  final List<Map<String, String>> playbooks = const [
    {
      'title': 'Restart service',
      'desc': 'Restarts all instances one at a time.',
      'impact': 'Medium · brief capacity drop',
    },
    {
      'title': 'Roll back deployment',
      'desc': 'Reverts to the previous healthy version.',
      'impact': 'High · changes production code',
      'action': 's17',
    },
    {
      'title': 'Scale service',
      'desc': 'Adds replicas to absorb load.',
      'impact': 'Low · higher cost',
    },
    {
      'title': 'Enable circuit breaker',
      'desc': 'Stops calls to a failing dependency.',
      'impact': 'Medium · degraded features',
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
                    child: Text(
                      'Playbooks',
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
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                itemCount: playbooks.length + 1,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        'Only these reviewed playbooks can run. High-impact ones need approval.',
                        style: TextStyle(fontSize: 12, color: colors.muted),
                      ),
                    );
                  }

                  final p = playbooks[index - 1];

                  return InkWell(
                    onTap: () {
                      if (p['action'] == 's17') {
                        Navigator.pushNamed(context, '/recommended-action');
                        return;
                      }

                      PlaybookActionType actionType = PlaybookActionType.rollback;
                      if (p['title'] == 'Restart service') {
                        actionType = PlaybookActionType.restart;
                      } else if (p['title'] == 'Scale service') {
                        actionType = PlaybookActionType.scale;
                      } else if (p['title'] == 'Enable circuit breaker') {
                        actionType = PlaybookActionType.circuitBreaker;
                      }

                      final approval = ApprovalModel(
                        id: 'appr-uuid-${actionType.slug}-01',
                        playbookRunId: 'run-uuid-${actionType.slug}-01',
                        incidentId: 'INC-1042',
                        playbookId: 'pb-uuid-${actionType.slug}-01',
                        actionType: actionType,
                        status: 'pending',
                        requestedBy: 'Alex Morgan',
                        serviceName: 'payments-api',
                        environment: 'Production',
                      );

                      Navigator.pushNamed(context, '/approve-action', arguments: approval);
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
                          Text(
                            p['title']!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p['desc']!,
                            style: TextStyle(fontSize: 13, color: colors.text),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Impact: ${p['impact']!}',
                            style: TextStyle(fontSize: 12, color: colors.muted),
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
      bottomNavigationBar: const AppBottomNav(currentRoute: 's28'),
    );
  }
}
