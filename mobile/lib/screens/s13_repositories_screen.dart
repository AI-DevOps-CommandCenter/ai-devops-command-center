import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 's14_deployment_details_screen.dart';
import 's15_failed_pipeline_job_screen.dart';
import 's19_execution_progress_screen.dart';
import 's24_pull_request_summary_screen.dart';
import 's30_search_screen.dart';

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
            // Header: CI/CD · demo-org/payments-api · GitHub · Search button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CI/CD',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.52,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'demo-org/payments-api \u00b7 GitHub',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const S30SearchScreen(),
                        ),
                      );
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
                      child: Icon(Icons.search, size: 20, color: colors.text),
                    ),
                  ),
                ],
              ),
            ),

            // Main scroll list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Deployments section
                  _buildSectionHeader('DEPLOYMENTS', colors.muted),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        _buildRowItem(
                          context,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const S14DeploymentDetailsScreen(),
                              ),
                            );
                          },
                          icon: Icon(Icons.layers_outlined, size: 20, color: colors.critical),
                          title: 'v2.8.1 \u00b7 Production',
                          subtitle: 'Today 14:05 \u00b7 linked to INC-1042',
                          badgeLabel: 'Rolled back',
                          badgeBg: colors.warningSoft,
                          badgeFg: colors.warning,
                        ),
                        Divider(height: 1, indent: 46, color: colors.border),
                        _buildRowItem(
                          context,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const S19ExecutionProgressScreen(),
                              ),
                            );
                          },
                          icon: Icon(Icons.layers_outlined, size: 20, color: colors.success),
                          title: 'v2.8.0 \u00b7 Production',
                          subtitle: 'Redeployed 14:25 \u00b7 stable 22 h before',
                          badgeLabel: 'Live',
                          badgeBg: colors.successSoft,
                          badgeFg: colors.success,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Pipelines section
                  _buildSectionHeader('PIPELINES', colors.muted),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        _buildRowItem(
                          context,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const S15FailedPipelineJobScreen(),
                              ),
                            );
                          },
                          icon: Icon(Icons.close, size: 20, color: colors.critical),
                          title: '#319 \u00b7 integration-tests failed',
                          subtitle: 'PR #215 \u00b7 12 min ago',
                          badgeLabel: 'Failed',
                          badgeBg: colors.criticalSoft,
                          badgeFg: colors.critical,
                        ),
                        Divider(height: 1, indent: 46, color: colors.border),
                        _buildRowItem(
                          context,
                          onTap: () {},
                          icon: Icon(Icons.check, size: 20, color: colors.success),
                          title: '#320 \u00b7 rollback deploy',
                          subtitle: 'main \u00b7 14:25 \u00b7 1m 10s',
                          badgeLabel: 'Passed',
                          badgeBg: colors.successSoft,
                          badgeFg: colors.success,
                        ),
                        Divider(height: 1, indent: 46, color: colors.border),
                        _buildRowItem(
                          context,
                          onTap: () {},
                          icon: Icon(Icons.check, size: 20, color: colors.success),
                          title: '#318 \u00b7 build and deploy',
                          subtitle: 'main \u00b7 14:03 \u00b7 2m 05s',
                          badgeLabel: 'Passed',
                          badgeBg: colors.successSoft,
                          badgeFg: colors.success,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Pull requests section
                  _buildSectionHeader('PULL REQUESTS', colors.muted),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        _buildRowItem(
                          context,
                          onTap: () {},
                          icon: Icon(Icons.merge_type, size: 20, color: colors.success),
                          title: '#215 Restore pool timeout to 1000 ms',
                          subtitle: 'Open \u00b7 checks failing',
                          badgeLabel: 'Open',
                          badgeBg: colors.successSoft,
                          badgeFg: colors.success,
                        ),
                        Divider(height: 1, indent: 46, color: colors.border),
                        _buildRowItem(
                          context,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const S24PullRequestSummaryScreen(),
                              ),
                            );
                          },
                          icon: Icon(Icons.call_merge, size: 20, color: colors.accent),
                          title: '#214 Tune DB pool settings',
                          subtitle: 'Merged today \u00b7 suspect change',
                          badgeLabel: 'Merged',
                          badgeBg: colors.accentSoft,
                          badgeFg: colors.accent,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Recent commits section
                  _buildSectionHeader('RECENT COMMITS', colors.muted),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: _buildRowItem(
                      context,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const S24PullRequestSummaryScreen(),
                          ),
                        );
                      },
                      icon: Icon(Icons.commit, size: 20, color: colors.muted),
                      title: 'Tune DB pool settings',
                      subtitle: 'a91f3c2 \u00b7 Alex Morgan \u00b7 13:58',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'cicd'),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.52,
        color: color,
      ),
    );
  }

  Widget _buildRowItem(
    BuildContext context, {
    required VoidCallback onTap,
    required Widget icon,
    required String title,
    required String subtitle,
    String? badgeLabel,
    Color? badgeBg,
    Color? badgeFg,
  }) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 20, height: 20, child: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badgeLabel != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
