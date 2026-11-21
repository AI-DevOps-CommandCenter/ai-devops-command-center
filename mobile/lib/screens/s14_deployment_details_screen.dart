import 'package:flutter/material.dart';
import '../models/cicd_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/cicd_widgets.dart';
import '../widgets/flow_widgets.dart';
import 's15_failed_pipeline_job_screen.dart';

/// S14 – one GitHub Actions workflow run (build / deployment) and its jobs.
/// Without arguments it shows the latest run of the first allow-listed repository.
class S14DeploymentDetailsScreen extends StatefulWidget {
  final RepoRef? repoRef;
  final int? runId;

  const S14DeploymentDetailsScreen({super.key, this.repoRef, this.runId});

  @override
  State<S14DeploymentDetailsScreen> createState() => _S14DeploymentDetailsScreenState();
}

class _S14DeploymentDetailsScreenState extends State<S14DeploymentDetailsScreen> {
  RepoRef? _ref;
  WorkflowRunModel? _run;
  List<WorkflowJobModel> _jobs = [];
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
      final runs = await api.fetchWorkflowRuns(owner: ref.owner, repo: ref.repo, limit: 30);
      if (runs.isEmpty) throw ApiException('${ref.fullName} has no workflow runs yet.');
      final run = widget.runId == null
          ? runs.first
          : runs.firstWhere((r) => r.id == widget.runId, orElse: () => runs.first);
      final jobs = await api.fetchWorkflowJobs(owner: ref.owner, repo: ref.repo, runId: run.id);
      if (!mounted) return;
      setState(() {
        _ref = ref;
        _run = run;
        _jobs = jobs;
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
    final run = _run;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(
              title: run == null ? 'Workflow run' : '${run.name} #${run.runNumber}',
              subtitle: _ref?.fullName ?? 'GitHub Actions',
            ),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'cicd'),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading) return const FlowMessage(icon: Icons.sync, message: 'Loading workflow run…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.link_off, message: _error!, onRetry: _load);
    final run = _run!;
    final (tone, label) = CicdUtils.runTone(colors, run.status, run.conclusion);
    final sha = run.headSha.length >= 7 ? run.headSha.substring(0, 7) : run.headSha;

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
                  Text(CicdUtils.ago(run.createdAt), style: TextStyle(fontSize: 12, color: colors.muted)),
                ]),
                const SizedBox(height: 10),
                ...[
                  ('Branch', run.branch),
                  ('Commit', sha),
                  ('Trigger', run.event),
                  ('Started by', run.actorLogin),
                  ('Duration', CicdUtils.duration(run.runStartedAt, run.status == 'completed' ? run.updatedAt : null)),
                ].map((kv) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        SizedBox(width: 96, child: Text(kv.$1, style: TextStyle(fontSize: 13, color: colors.muted))),
                        Expanded(
                          child: Text(kv.$2.isEmpty ? '—' : kv.$2,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.text)),
                        ),
                      ]),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const SectionLabel('Jobs'),
          if (_jobs.isEmpty)
            FlowCard(child: Text('This run has no jobs.', style: TextStyle(fontSize: 13, color: colors.muted))),
          ..._jobs.map((j) {
            final (jt, jl) = CicdUtils.runTone(colors, j.status, j.conclusion);
            return CicdRow(
              icon: j.conclusion == 'failure' ? Icons.error_outline : Icons.check_circle_outline,
              title: j.name,
              subtitle: '${j.steps.length} steps · ${CicdUtils.duration(j.startedAt, j.completedAt)}',
              pill: jl,
              pillColor: jt,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => S15FailedPipelineJobScreen(repoRef: _ref, runId: run.id, jobId: j.id),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
