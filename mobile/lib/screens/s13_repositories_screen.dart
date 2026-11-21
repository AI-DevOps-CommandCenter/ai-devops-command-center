import 'package:flutter/material.dart';
import '../models/cicd_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/cicd_widgets.dart';
import '../widgets/flow_widgets.dart';
import 's14_deployment_details_screen.dart';
import 's24_pull_request_summary_screen.dart';

/// S13 – CI/CD overview: workflow runs, pull requests and commits of an
/// allow-listed repository (GET /api/github/...).
class S13RepositoriesScreen extends StatefulWidget {
  const S13RepositoriesScreen({super.key});

  @override
  State<S13RepositoriesScreen> createState() => _S13RepositoriesScreenState();
}

class _S13RepositoriesScreenState extends State<S13RepositoriesScreen> {
  List<GithubRepoModel> _repos = [];
  GithubRepoModel? _repo;
  List<WorkflowRunModel> _runs = [];
  List<PullRequestModel> _pulls = [];
  List<GitCommitModel> _commits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final repos = _repos.isEmpty ? await api.fetchRepositories() : _repos;
      if (repos.isEmpty) throw ApiException('No repositories are configured on the backend.');
      final repo = _repo ?? repos.first;
      final results = await Future.wait([
        api.fetchWorkflowRuns(owner: repo.owner, repo: repo.name, limit: 5),
        api.fetchPullRequests(owner: repo.owner, repo: repo.name, state: 'all', limit: 5),
        api.fetchCommits(owner: repo.owner, repo: repo.name, branch: repo.defaultBranch, limit: 5),
      ]);
      if (!mounted) return;
      setState(() {
        _repos = repos;
        _repo = repo;
        _runs = results[0] as List<WorkflowRunModel>;
        _pulls = results[1] as List<PullRequestModel>;
        _commits = results[2] as List<GitCommitModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = CicdUtils.errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(title: 'CI/CD', subtitle: _repo?.fullName ?? 'GitHub'),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'cicd'),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading && _repo == null) return const FlowMessage(icon: Icons.sync, message: 'Loading from GitHub…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.link_off, message: _error!, onRetry: _load);
    final repo = _repo!;
    final ref = RepoRef(repo.owner, repo.name);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (_repos.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _repos
                    .map((r) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(r.name),
                            selected: r.fullName == repo.fullName,
                            onSelected: (_) {
                              _repo = r;
                              _load();
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          FlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(repo.fullName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.text)),
                if (repo.description != null && repo.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(repo.description!, style: TextStyle(fontSize: 13, color: colors.muted)),
                ],
                const SizedBox(height: 6),
                Text(
                  'Default branch ${repo.defaultBranch} · last push ${CicdUtils.ago(repo.pushedAt)} · ${repo.openIssuesCount} open issues',
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const SectionLabel('Workflow runs'),
          if (_runs.isEmpty) _empty(colors, 'No workflow runs yet.'),
          ..._runs.map((r) {
            final (tone, label) = CicdUtils.runTone(colors, r.status, r.conclusion);
            return CicdRow(
              icon: Icons.play_circle_outline,
              title: '${r.name} #${r.runNumber}',
              subtitle: '${r.branch} · ${r.event} · ${r.actorLogin} · ${CicdUtils.ago(r.createdAt)}',
              pill: label,
              pillColor: tone,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => S14DeploymentDetailsScreen(repoRef: ref, runId: r.id)),
              ),
            );
          }),
          const SectionLabel('Pull requests'),
          if (_pulls.isEmpty) _empty(colors, 'No pull requests.'),
          ..._pulls.map((p) {
            final (tone, label) = CicdUtils.prTone(colors, p);
            return CicdRow(
              icon: Icons.merge_type,
              title: '#${p.number} ${p.title}',
              subtitle: '${p.authorLogin} · ${p.headBranch} → ${p.baseBranch} · ${CicdUtils.ago(p.updatedAt)}',
              pill: label,
              pillColor: tone,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => S24PullRequestSummaryScreen(repoRef: ref, number: p.number)),
              ),
            );
          }),
          SectionLabel('Commits on ${repo.defaultBranch}'),
          if (_commits.isEmpty) _empty(colors, 'No commits.'),
          ..._commits.map((c) => CicdRow(
                icon: Icons.commit,
                title: c.title,
                subtitle: '${c.shortSha} · ${c.authorLogin.isNotEmpty ? c.authorLogin : c.authorName} · ${CicdUtils.ago(c.authoredAt)}',
              )),
        ],
      ),
    );
  }

  Widget _empty(AppColorScheme colors, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FlowCard(child: Text(text, style: TextStyle(fontSize: 13, color: colors.muted))),
      );
}
