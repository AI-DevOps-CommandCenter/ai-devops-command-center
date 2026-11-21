import 'package:flutter/material.dart';
import '../models/cicd_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/cicd_widgets.dart';
import '../widgets/flow_widgets.dart';

/// S15 – one pipeline job and its steps; the first failed step is highlighted.
/// Without arguments it shows the first failed job of the latest failed run.
class S15FailedPipelineJobScreen extends StatefulWidget {
  final RepoRef? repoRef;
  final int? runId;
  final int? jobId;

  const S15FailedPipelineJobScreen({super.key, this.repoRef, this.runId, this.jobId});

  @override
  State<S15FailedPipelineJobScreen> createState() => _S15FailedPipelineJobScreenState();
}

class _S15FailedPipelineJobScreenState extends State<S15FailedPipelineJobScreen> {
  RepoRef? _ref;
  WorkflowJobModel? _job;
  bool _loading = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final api = ApiService();
      final ref = widget.repoRef ?? await CicdUtils.defaultRepo();
      int? runId = widget.runId;
      if (runId == null) {
        final runs = await api.fetchWorkflowRuns(owner: ref.owner, repo: ref.repo, limit: 30);
        final failed = runs.where((r) => r.conclusion == 'failure').toList();
        if (failed.isEmpty) {
          if (!mounted) return;
          setState(() {
            _ref = ref;
            _loading = false;
            _info = 'No failed pipeline runs in ${ref.fullName}.';
          });
          return;
        }
        runId = failed.first.id;
      }
      final jobs = await api.fetchWorkflowJobs(owner: ref.owner, repo: ref.repo, runId: runId);
      if (jobs.isEmpty) throw ApiException('This run has no jobs.');
      final job = widget.jobId != null
          ? jobs.firstWhere((j) => j.id == widget.jobId, orElse: () => jobs.first)
          : jobs.firstWhere((j) => j.conclusion == 'failure', orElse: () => jobs.first);
      if (!mounted) return;
      setState(() {
        _ref = ref;
        _job = job;
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
            FlowHeader(title: _job?.name ?? 'Pipeline job', subtitle: _ref?.fullName ?? 'GitHub Actions'),
            Expanded(child: _body(colors)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'cicd'),
    );
  }

  Widget _body(AppColorScheme colors) {
    if (_loading) return const FlowMessage(icon: Icons.sync, message: 'Loading job…', busy: true);
    if (_error != null) return FlowMessage(icon: Icons.link_off, message: _error!, onRetry: _load);
    if (_info != null) return FlowMessage(icon: Icons.verified_outlined, message: _info!, onRetry: _load);
    final job = _job!;
    final (tone, label) = CicdUtils.runTone(colors, job.status, job.conclusion);
    final firstFailed = job.steps.indexWhere((s) => s.conclusion == 'failure');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          FlowCard(
            child: Row(children: [
              StatusPill(label: label, color: tone),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Duration ${CicdUtils.duration(job.startedAt, job.completedAt)}',
                    style: TextStyle(fontSize: 13, color: colors.muted)),
              ),
            ]),
          ),
          if (firstFailed >= 0) ...[
            const SizedBox(height: 10),
            FlowCard(
              background: colors.criticalSoft,
              borderColor: colors.critical.withValues(alpha: 0.3),
              child: Text(
                'Failed at step ${job.steps[firstFailed].number}: ${job.steps[firstFailed].name}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const SectionLabel('Steps'),
          ...job.steps.map((s) {
            final (st, sl) = CicdUtils.runTone(colors, s.status, s.conclusion);
            return CicdRow(
              icon: s.conclusion == 'failure'
                  ? Icons.cancel_outlined
                  : s.conclusion == 'success'
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
              title: '${s.number}. ${s.name}',
              subtitle: s.status,
              pill: sl,
              pillColor: st,
            );
          }),
          const SizedBox(height: 8),
          Text('Logs are available on GitHub: ${job.htmlUrl}', style: TextStyle(fontSize: 12, color: colors.muted)),
        ],
      ),
    );
  }
}
