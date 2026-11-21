import 'package:flutter/material.dart';
import '../models/cicd_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/cicd_widgets.dart';
import '../widgets/flow_widgets.dart';

/// S24 – one pull request (GET /api/github/repositories/:owner/:repo/pulls/:number).
/// Without arguments it shows the most recently updated pull request.
class S24PullRequestSummaryScreen extends StatefulWidget {
  final RepoRef? repoRef;
  final int? number;

  const S24PullRequestSummaryScreen({super.key, this.repoRef, this.number});

  @override
  State<S24PullRequestSummaryScreen> createState() => _S24PullRequestSummaryScreenState();
}

class _S24PullRequestSummaryScreenState extends State<S24PullRequestSummaryScreen> {
  RepoRef? _ref;
  PullRequestModel? _pr;
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
      final ref = widget.repoRef ?? await CicdUtils.defaultRepo();
      var number = widget.number;
      if (number == null) {
        final pulls = await api.fetchPullRequests(owner: ref.owner, repo: ref.repo, state: 'all', limit: 1);
        if (pulls.isEmpty) throw ApiException('${ref.fullName} has no pull requests.');
        number = pulls.first.number;
      }
      final pr = await api.fetchPullRequestDetail(owner: ref.owner, repo: ref.repo, number: number);
      if (!mounted) return;
      setState(() {
        _ref = ref;
        _pr = pr;
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
            FlowHeader(title: _pr == null ? 'Pull request' : 'PR #${_pr!.number}', subtitle: _ref?.fullName ?? 'GitHub'),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'cicd'),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading) return const FlowMessage(icon: Icons.sync, message: 'Loading pull request…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.link_off, message: _error!, onRetry: _load);
    final pr = _pr!;
    final (tone, label) = CicdUtils.prTone(colors, pr);

    Widget stat(String value, String name, Color c) => Expanded(
          child: FlowCard(
            child: Column(children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c)),
              const SizedBox(height: 2),
              Text(name, style: TextStyle(fontSize: 12, color: colors.muted)),
            ]),
          ),
        );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          FlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  StatusPill(label: label, color: tone),
                  const Spacer(),
                  Text(CicdUtils.ago(pr.updatedAt), style: TextStyle(fontSize: 12, color: colors.muted)),
                ]),
                const SizedBox(height: 10),
                Text(pr.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.text)),
                const SizedBox(height: 6),
                Text('${pr.authorLogin} wants to merge ${pr.headBranch} into ${pr.baseBranch}',
                    style: TextStyle(fontSize: 13, color: colors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            stat('${pr.commitsCount}', 'commits', colors.text),
            const SizedBox(width: 8),
            stat('${pr.changedFiles}', 'files', colors.text),
            const SizedBox(width: 8),
            stat('+${pr.additions}', 'added', colors.success),
            const SizedBox(width: 8),
            stat('-${pr.deletions}', 'removed', colors.critical),
          ]),
          const SizedBox(height: 10),
          FlowSection(
            label: 'Description',
            text: (pr.body == null || pr.body!.trim().isEmpty) ? 'No description.' : pr.body!.trim(),
          ),
          if (pr.mergeableState != null)
            FlowSection(label: 'Merge state', text: pr.mergeableState!.replaceAll('_', ' ')),
          Text(pr.htmlUrl, style: TextStyle(fontSize: 12, color: colors.muted)),
        ],
      ),
    );
  }
}
