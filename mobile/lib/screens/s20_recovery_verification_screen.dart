import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../models/playbook_model.dart';
import '../widgets/flow_widgets.dart';
import 's21_postmortem_report_screen.dart';

/// S20 Recovery verification.
/// Shows the recovery check written by n8n workflow 07 for this playbook run
/// (GET /api/incidents/:id/recovery-checks). Polls every 5 s until a final
/// result (healthy / unhealthy / failed) arrives.
class S20RecoveryVerificationScreen extends StatefulWidget {
  final String? playbookRunId;

  const S20RecoveryVerificationScreen({super.key, this.playbookRunId});

  @override
  State<S20RecoveryVerificationScreen> createState() => _S20RecoveryVerificationScreenState();
}

class _S20RecoveryVerificationScreenState extends State<S20RecoveryVerificationScreen> {
  String? _runId;
  PlaybookRunModel? _run;
  Map<String, dynamic>? _check;
  String? _errorMessage;
  bool _isLoading = true;
  Timer? _poll;
  int _polls = 0;

  static const _maxPolls = 60; // 5 minutes

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_runId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _runId = (args is String && args.isNotEmpty) ? args : widget.playbookRunId;
      _load();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final runId = _runId;
    if (runId == null || runId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Open this screen from a remediation run.';
      });
      return;
    }
    try {
      final api = ApiService();
      final run = _run ?? await api.fetchPlaybookRun(runId);
      final checks = await api.fetchRecoveryChecks(run.incidentId);
      Map<String, dynamic>? match;
      for (final c in checks) {
        if (c['playbook_run_id']?.toString() == runId) {
          match = c;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _run = run;
        _check = match;
        _errorMessage = null;
        _isLoading = false;
      });
      final status = match?['status']?.toString();
      final isFinal = status == 'healthy' || status == 'unhealthy' || status == 'failed';
      if (!isFinal && _polls < _maxPolls) {
        _polls++;
        _poll?.cancel();
        _poll = Timer(const Duration(seconds: 5), _load);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final run = _run;
    final subtitle = run == null ? 'Loading run…' : '${run.serviceName} · ${run.actionType.name}';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(title: 'Recovery verification', subtitle: subtitle),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = context.colors;
    if (_isLoading) return const FlowMessage(icon: Icons.hourglass_top, message: 'Loading…', busy: true);
    if (_errorMessage != null) {
      return FlowMessage(icon: Icons.error_outline, message: _errorMessage!, onRetry: () {
        setState(() => _isLoading = true);
        _load();
      });
    }

    final status = _check?['status']?.toString();
    final details = _check?['details'] is Map ? Map<String, dynamic>.from(_check!['details']) : <String, dynamic>{};
    final checks = details['checks'] is List ? (details['checks'] as List) : const [];
    final reason = details['reason']?.toString();

    late final IconData icon;
    late final Color tone;
    late final Color toneBg;
    late final String headline;
    late final String body;
    switch (status) {
      case 'healthy':
        icon = Icons.check_circle_outline;
        tone = colors.success;
        toneBg = colors.successSoft;
        headline = 'Service recovered';
        body = 'Prometheus health checks passed after the remediation.';
        break;
      case 'unhealthy':
        icon = Icons.cancel_outlined;
        tone = colors.critical;
        toneBg = colors.criticalSoft;
        headline = 'Not recovered';
        body = reason ?? 'The service is still unhealthy after the remediation. Escalate to the on-call engineer.';
        break;
      case 'failed':
        icon = Icons.help_outline;
        tone = colors.warning;
        toneBg = colors.warningSoft;
        headline = 'Unable to verify';
        body = reason ?? 'The recovery check could not be completed.';
        break;
      default:
        icon = Icons.hourglass_top;
        tone = colors.accent;
        toneBg = colors.accentSoft;
        headline = 'Checking recovery…';
        body = 'Waiting for the health checks (this page refreshes every 5 seconds).';
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const FlowStepper(activeStage: 4),
          const SizedBox(height: 14),
          FlowCard(
            background: toneBg,
            borderColor: tone.withValues(alpha: 0.3),
            child: Row(
              children: [
                status == null
                    ? SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: tone))
                    : Icon(icon, color: tone, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headline, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.text)),
                      const SizedBox(height: 2),
                      Text(body, style: TextStyle(fontSize: 13, color: colors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_check != null) ...[
            FlowSection(
              label: 'Check',
              items: [
                'Type: ${_check!['check_type'] ?? 'prometheus'}',
                'Checks performed: ${checks.length}',
                if (_check!['checked_at'] != null) 'Checked at: ${_check!['checked_at']}',
                if (details['simulated_remediation'] == true) 'Remediation was simulated',
              ],
            ),
            if (checks.isNotEmpty)
              FlowSection(
                label: 'Health checks',
                items: checks.map((c) {
                  if (c is Map) {
                    final parts = c.entries
                        .where((e) => e.value is! Map && e.value is! List)
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' · ');
                    return parts.isEmpty ? c.toString() : parts;
                  }
                  return c.toString();
                }).toList(),
              ),
          ],
          if (status == 'healthy' && _run != null)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => S21PostmortemReportScreen(incidentId: _run!.incidentId),
                      settings: RouteSettings(arguments: _run!.incidentId),
                    ),
                  );
                },
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('View postmortem', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
