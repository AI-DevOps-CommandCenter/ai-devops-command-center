import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import 's05_incident_details_screen.dart';
import 's12_service_details_screen.dart';
import 's14_deployment_details_screen.dart';
import 's15_failed_pipeline_job_screen.dart';
import 's24_pull_request_summary_screen.dart';
import 's32_inc_1041_screen.dart';
import 's34_pm_1037_screen.dart';

class S30SearchScreen extends StatefulWidget {
  const S30SearchScreen({super.key});

  @override
  State<S30SearchScreen> createState() => _S30SearchScreenState();
}

class _S30SearchScreenState extends State<S30SearchScreen> {
  final TextEditingController _searchController = TextEditingController(text: 'pay');
  String _query = 'pay';

  final List<Map<String, String>> _allResults = [
    {
      'kind': 'Incident',
      'title': 'INC-1042 · Elevated errors after deployment',
      'route': 'incident_1042',
    },
    {
      'kind': 'Service',
      'title': 'payments-api · Degraded',
      'route': 'service_detail',
    },
    {
      'kind': 'Deployment',
      'title': 'payments-api v2.8.1',
      'route': 'deployment_detail',
    },
    {
      'kind': 'Pull request',
      'title': 'PR #214 · Tune DB pool settings',
      'route': 'pr_summary',
    },
    {
      'kind': 'Pipeline',
      'title': '#319 · integration-tests failed',
      'route': 'pipeline_job',
    },
    {
      'kind': 'Incident',
      'title': 'INC-1037 · Cache hit ratio dropped',
      'route': 'pm_1037',
    },
    {
      'kind': 'Service',
      'title': 'orders-worker · Warning',
      'route': 'inc_1041',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToRoute(String route) {
    switch (route) {
      case 'incident_1042':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const S05IncidentDetailsScreen()),
        );
        break;
      case 'service_detail':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const S12ServiceDetailsScreen()),
        );
        break;
      case 'deployment_detail':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const S14DeploymentDetailsScreen()),
        );
        break;
      case 'pr_summary':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const S24PullRequestSummaryScreen()),
        );
        break;
      case 'pipeline_job':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const S15FailedPipelineJobScreen()),
        );
        break;
      case 'pm_1037':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const S34Pm1037Screen()),
        );
        break;
      case 'inc_1041':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const S32Inc1041Screen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final q = _query.toLowerCase();
    final results = _allResults.where((r) {
      if (q.isEmpty) return true;
      final k = r['kind']!.toLowerCase();
      final t = r['title']!.toLowerCase();
      return k.contains(q) || t.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: padding: 14px 16px 10px, gap: 10px
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content: padding: 4px 16px 24px, gap: 14px
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search Input Box
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.accent, width: 2),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 18, color: colors.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _query = val.trim();
                                });
                              },
                              style: TextStyle(fontSize: 15, color: colors.text),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Incidents, services, PRs, pipelines',
                                hintStyle: TextStyle(fontSize: 15, color: colors.muted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section: RESULTS
                    Text(
                      'RESULTS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.52,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (results.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: List.generate(results.length, (index) {
                            final r = results[index];
                            final hasBorder = index < results.length - 1;
                            return InkWell(
                              onTap: () => _navigateToRoute(r['route']!),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 58),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  border: hasBorder
                                      ? Border(bottom: BorderSide(color: colors.border))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r['kind']!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: colors.muted,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            r['title']!,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: colors.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: colors.muted,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          'No results. Try a service name or an incident ID.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
