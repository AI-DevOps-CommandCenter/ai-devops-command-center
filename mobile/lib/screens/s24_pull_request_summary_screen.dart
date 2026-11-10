import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/api_service.dart';
import '../models/cicd_model.dart';

class S24PullRequestSummaryScreen extends StatefulWidget {
  const S24PullRequestSummaryScreen({super.key});

  @override
  State<S24PullRequestSummaryScreen> createState() => _S24PullRequestSummaryScreenState();
}

class _S24PullRequestSummaryScreenState extends State<S24PullRequestSummaryScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  PullRequestModel? _pr;

  @override
  void initState() {
    super.initState();
    _loadPullRequest();
  }

  Future<void> _loadPullRequest() async {
    setState(() => _isLoading = true);
    try {
      final pr = await _apiService.fetchPullRequestDetail(number: 214);
      if (mounted) {
        setState(() {
          _pr = pr;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pr = _pr;

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
                        Row(
                          children: [
                            Text(
                              pr != null ? 'PR #${pr.number}' : 'PR #214',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildBadge(
                              pr?.displayBadge ?? 'Merged',
                              (pr?.isMerged ?? true) ? colors.badgeGreenBg : colors.badgeAmberBg,
                              (pr?.isMerged ?? true) ? colors.green : colors.amber,
                            ),
                          ],
                        ),
                        Text(
                          pr?.title ?? 'Tune DB pool settings',
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
                    // Branch & Pipeline Card
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/pipeline-job');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCard(
                        colors: colors,
                        child: Column(
                          children: [
                            _buildRow(
                              colors,
                              'Branch',
                              pr != null ? '${pr.headBranch} → ${pr.baseBranch}' : 'tune-db-pool → main',
                            ),
                            Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                            _buildRow(colors, 'Pipeline', '#318 job failed'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Changed Files Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Changed files (${pr?.changedFiles ?? 3})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '+${pr?.additions ?? 12}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.green),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '-${pr?.deletions ?? 4}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.red),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'db/pool.ts · config/prod.yaml · logger.ts',
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Summary Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Summary',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pr?.body ?? 'Lowers pool timeout, adds retries, tweaks logging.',
                            style: TextStyle(fontSize: 13, color: colors.text, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Possible Concerns Card (Amber warning left accent)
                    _buildCard(
                      colors: colors,
                      leftAccentColor: colors.amber,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Possible concerns',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Timeout set to 500 ms; no load test attached.',
                            style: TextStyle(fontSize: 13, color: colors.text),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ask assistant Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text(
                          'Ask assistant',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/assistant', arguments: 'pr');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.teal,
                          foregroundColor: colors.isDark ? const Color(0xFF0B1226) : Colors.white,
                          elevation: 0,
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

  Widget _buildCard({
    required AppColorScheme colors,
    required Widget child,
    Color? leftAccentColor,
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
              if (leftAccentColor != null)
                Container(width: 4, color: leftAccentColor),
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

  Widget _buildRow(AppColorScheme colors, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.muted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
      ],
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
