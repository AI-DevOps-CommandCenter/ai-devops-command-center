import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/api_service.dart';
import '../models/cicd_model.dart';

class S13RepositoriesScreen extends StatefulWidget {
  const S13RepositoriesScreen({super.key});

  @override
  State<S13RepositoriesScreen> createState() => _S13RepositoriesScreenState();
}

class _S13RepositoriesScreenState extends State<S13RepositoriesScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  List<GithubRepoModel> _repos = [];
  List<GitCommitModel> _commits = [];
  List<PullRequestModel> _pulls = [];
  List<WorkflowRunModel> _runs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repos = await _apiService.fetchRepositories();
      final commits = await _apiService.fetchCommits();
      final pulls = await _apiService.fetchPullRequests();
      final runs = await _apiService.fetchWorkflowRuns();

      if (mounted) {
        setState(() {
          _repos = repos;
          _commits = commits;
          _pulls = pulls;
          _runs = runs;
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

    final primaryRepo = _repos.isNotEmpty ? _repos.first : null;
    final secondaryRepo = _repos.length > 1 ? _repos[1] : null;
    final recentCommit = _commits.isNotEmpty ? _commits.first : null;
    final recentPr = _pulls.isNotEmpty ? _pulls.first : null;
    final failedRun = _runs.firstWhere(
      (r) => r.isFailed,
      orElse: () => _runs.isNotEmpty ? _runs.first : WorkflowRunModel(
        id: 318,
        name: 'CI',
        runNumber: 318,
        event: 'push',
        status: 'completed',
        conclusion: 'failure',
        branch: 'main',
        headSha: 'a91f3c2',
        actorLogin: 'devone',
        htmlUrl: '',
      ),
    );
    final deployRun = _runs.firstWhere(
      (r) => r.name.toLowerCase().contains('deploy') || r.branch == 'main',
      orElse: () => _runs.isNotEmpty ? _runs.last : WorkflowRunModel(
        id: 317,
        name: 'Deployment v2.8.1',
        runNumber: 317,
        event: 'push',
        status: 'completed',
        conclusion: 'success',
        branch: 'main',
        headSha: 'a91f3c2',
        actorLogin: 'alexm',
        htmlUrl: '',
      ),
    );

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
                      'Repositories',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                  ),
                  if (_isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.teal,
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: colors.teal,
                backgroundColor: colors.card,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Repository 1 header card
                      _buildCard(
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              primaryRepo != null ? 'github.com/${primaryRepo.fullName}' : 'github.com/acme/payments-api',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'GitHub · ${primaryRepo?.defaultBranch ?? "main"}',
                              style: TextStyle(fontSize: 12, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Recent commit
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/pull-request');
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: _buildCard(
                          colors: colors,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recent commit',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recentCommit != null
                                    ? '${recentCommit.shortSha} ${recentCommit.title}'
                                    : 'a91f3c2 Tune DB pool settings',
                                style: TextStyle(fontSize: 13, color: colors.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // PR #214
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/pull-request');
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: _buildCard(
                          colors: colors,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    recentPr != null ? 'PR #${recentPr.number}' : 'PR #214',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.text,
                                    ),
                                  ),
                                  _buildBadge(
                                    recentPr?.displayBadge ?? 'Merged',
                                    (recentPr?.isMerged ?? true) ? colors.badgeGreenBg : colors.badgeAmberBg,
                                    (recentPr?.isMerged ?? true) ? colors.green : colors.amber,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recentPr?.title ?? 'Tune DB pool settings',
                                style: TextStyle(fontSize: 13, color: colors.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Pipeline #318 (Failed job)
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/pipeline-job');
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: _buildCard(
                          colors: colors,
                          leftAccentColor: failedRun.isFailed ? colors.red : colors.green,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Pipeline #${failedRun.runNumber}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.text,
                                    ),
                                  ),
                                  _buildBadge(
                                    failedRun.isFailed ? 'Failed job' : failedRun.displayStatus,
                                    failedRun.isFailed ? colors.badgeRedBg : colors.badgeGreenBg,
                                    failedRun.isFailed ? colors.red : colors.green,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'integration-tests',
                                style: TextStyle(fontSize: 12, color: colors.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Deployment v2.8.1
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/deployment-details');
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: _buildCard(
                          colors: colors,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deployRun.name.contains('Deploy') ? deployRun.name : 'Deployment v2.8.1',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Production · 14:05',
                                style: TextStyle(fontSize: 12, color: colors.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Repository 2
                      _buildCard(
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              secondaryRepo != null ? 'github.com/${secondaryRepo.fullName}' : 'gitlab.com/demo-org/orders-worker',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'GitHub · pipeline passed',
                              style: TextStyle(fontSize: 12, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
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
                Container(
                  width: 4,
                  color: leftAccentColor,
                ),
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
