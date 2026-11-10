import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/api_service.dart';
import '../models/cicd_model.dart';

class S15FailedPipelineJobScreen extends StatefulWidget {
  const S15FailedPipelineJobScreen({super.key});

  @override
  State<S15FailedPipelineJobScreen> createState() => _S15FailedPipelineJobScreenState();
}

class _S15FailedPipelineJobScreenState extends State<S15FailedPipelineJobScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  WorkflowJobModel? _job;

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await _apiService.fetchWorkflowJobs(runId: 318);
      if (mounted) {
        setState(() {
          _job = jobs.isNotEmpty ? jobs.first : null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRetryNotice(BuildContext context, AppColorScheme colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: colors.amber, size: 22),
            const SizedBox(width: 8),
            Text(
              'Pipeline Action Restricted',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.text),
            ),
          ],
        ),
        content: Text(
          'GitHub token is configured as read-only. In this DevOps Command Center, automated remediation and CI/CD reruns require designated human authorization.\n\nYou can review this run directly on GitHub actions.',
          style: TextStyle(fontSize: 13, color: colors.text, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: colors.teal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final job = _job;
    final failedStep = job?.failedStep;

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
                          job?.name ?? 'integration-tests',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'Pipeline #318',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.teal),
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
                    // Failed Step Card (With safe accent border)
                    _buildAccentCard(
                      colors: colors,
                      accentColor: colors.red,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Failed step',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.badgeRedBg,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  failedStep != null ? 'Step ${failedStep.number} failed' : 'Step 4 failed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            failedStep != null
                                ? '${failedStep.name} · Duration ${job?.durationString ?? "2m 14s"}'
                                : 'Duration 2m 14s',
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Step Execution List Card
                    if (job != null && job.steps.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.cardBorder, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Execution Steps',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...job.steps.map((step) {
                              final isSuccess = step.isPassed;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSuccess ? Icons.check_circle : Icons.cancel,
                                      size: 16,
                                      color: isSuccess ? colors.green : colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Step ${step.number}: ${step.name}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSuccess ? colors.text : colors.red,
                                          fontWeight: isSuccess ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      isSuccess ? 'Passed' : 'Failed',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSuccess ? colors.green : colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Log Line 1
                    _buildLogItem(colors, '13:58:02', 'ERROR', 'postgres not ready after 30s'),
                    const SizedBox(height: 8),

                    // Log Line 2
                    _buildLogItem(colors, '13:58:03', 'ERROR', 'ECONNREFUSED 14 tests failed'),
                    const SizedBox(height: 20),

                    // Explain with AI Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text(
                          'Explain with AI',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/assistant', arguments: 'build');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.teal,
                          foregroundColor: colors.isDark ? const Color(0xFF06202A) : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Retry Pipeline Button (With authorization safety check)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.replay, size: 18, color: colors.text),
                        label: Text(
                          'Retry Pipeline',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
                        ),
                        onPressed: () => _showRetryNotice(context, colors),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: colors.cardAccent,
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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

  Widget _buildAccentCard({
    required AppColorScheme colors,
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(AppColorScheme colors, String time, String level, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.logBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: 12,
            color: colors.text,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$time ',
              style: TextStyle(color: colors.muted),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: colors.badgeRedBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colors.red,
                  ),
                ),
              ),
            ),
            TextSpan(text: message),
          ],
        ),
      ),
    );
  }
}
