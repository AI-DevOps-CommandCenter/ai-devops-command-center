import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import '../services/api_service.dart';
import '../models/playbook_model.dart';
import 's20_recovery_verification_screen.dart';

class S19ExecutionProgressScreen extends StatefulWidget {
  final String? playbookRunId;
  final String? approvalId;

  const S19ExecutionProgressScreen({
    super.key,
    this.playbookRunId,
    this.approvalId,
  });

  @override
  State<S19ExecutionProgressScreen> createState() =>
      _S19ExecutionProgressScreenState();
}

class _S19ExecutionProgressScreenState extends State<S19ExecutionProgressScreen> {
  Timer? _pollingTimer;
  bool _isLoading = true;
  String? _errorMessage;
  PlaybookRunModel? _run;
  String? _resolvedRunId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedRunId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _resolvedRunId = args;
      } else if (widget.playbookRunId != null &&
          widget.playbookRunId!.isNotEmpty) {
        _resolvedRunId = widget.playbookRunId;
      }

      _initRunAndPolling();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initRunAndPolling() async {
    await _fetchStatus();

    // Refresh playbook-run status every 3 seconds so the user can see actual execution state
    // approved -> running -> success / failed
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) return;
      await _fetchStatus(isPolling: true);

      // If run reached a terminal state (success, failed, rejected, cancelled), slow down or stop polling
      if (_run != null &&
          (_run!.status == PlaybookRunStatus.success ||
              _run!.status == PlaybookRunStatus.failed ||
              _run!.status == PlaybookRunStatus.cancelled ||
              _run!.status == PlaybookRunStatus.rejected)) {
        timer.cancel();
      }
    });
  }

  Future<void> _fetchStatus({bool isPolling = false}) async {
    if (!isPolling) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final id = _resolvedRunId;
    if (id == null || id.isEmpty) {
      try {
        final runs = await ApiService().fetchPlaybookRuns();
        if (runs.isNotEmpty && mounted) {
          _resolvedRunId = runs.first.id;
        }
      } catch (_) {}
    }

    if (_resolvedRunId == null || _resolvedRunId!.isEmpty) {
      if (mounted && !isPolling) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No playbook run ID available to track.';
        });
      }
      return;
    }

    try {
      final run = await ApiService().fetchPlaybookRun(_resolvedRunId!);
      if (mounted) {
        setState(() {
          _run = run;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !isPolling) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final run = _run;

    final shortRunId = _resolvedRunId != null && _resolvedRunId!.length > 8
        ? 'RUN-${_resolvedRunId!.substring(0, 8).toUpperCase()}'
        : (_resolvedRunId ?? 'RUN-EXECUTION');

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Execution Progress',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$shortRunId · ${run?.serviceName ?? "Service"}',
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
                ],
              ),
            ),

            // Content
            Expanded(
              child: _buildBody(colors, run),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme colors, PlaybookRunModel? run) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && run == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.red),
              const SizedBox(height: 12),
              Text(
                'Unable to track execution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchStatus(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final status = run?.status ?? PlaybookRunStatus.running;
    final isSuccess = status == PlaybookRunStatus.success;
    final isFailed = status == PlaybookRunStatus.failed ||
        status == PlaybookRunStatus.cancelled ||
        status == PlaybookRunStatus.rejected;
    final isRunning = status == PlaybookRunStatus.running ||
        status == PlaybookRunStatus.approved;

    Color statusColor = colors.accent;
    String statusTitle = 'Execution in progress';
    String statusSubtitle = 'n8n automation engine is running the remediation playbook.';
    IconData statusIcon = Icons.autorenew_rounded;

    if (isSuccess) {
      statusColor = colors.ok;
      statusTitle = 'Remediation completed successfully';
      statusSubtitle = 'All steps passed. System is verified healthy.';
      statusIcon = Icons.shield_outlined;
    } else if (isFailed) {
      statusColor = colors.critical;
      statusTitle = 'Playbook execution stopped';
      statusSubtitle = run?.cancellationReason ?? 'Execution encountered an error or was rejected.';
      statusIcon = Icons.error_outline;
    } else if (status == PlaybookRunStatus.approved) {
      statusTitle = 'Approved — Dispatching to runner';
      statusSubtitle = 'Preparing container rollback execution pipeline...';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stepper: Detect -> Investigate -> Cause -> Approve -> Recover (active)
          _buildStepper(context, isSuccess: isSuccess),
          const SizedBox(height: 14),

          // Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                if (isRunning)
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: statusColor,
                    ),
                  )
                else
                  Icon(statusIcon, size: 28, color: statusColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusSubtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Execution Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXECUTION DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Playbook ID', run?.playbookId ?? '--', colors),
                const SizedBox(height: 8),
                _buildInfoRow('Service', run?.serviceName ?? 'payments-api', colors),
                const SizedBox(height: 8),
                _buildInfoRow('Action', run?.actionType.displayName ?? 'Rollback', colors),
                const SizedBox(height: 8),
                _buildInfoRow('Status', status.slug.toUpperCase(), colors, highlightColor: statusColor),
                if (run?.startedAt != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('Started', run!.startedAt!.toLocal().toString().substring(11, 19), colors),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Steps list (Real or Fallback Steps)
          Text(
            'EXECUTION PHASES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.52,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 8),

          _buildPhaseCard(
            title: '1. Human Operator Approval',
            subtitle: 'Confirmed and digitally audited',
            isComplete: true,
            colors: colors,
          ),
          const SizedBox(height: 8),
          _buildPhaseCard(
            title: '2. n8n Engine Dispatch',
            subtitle: 'Remediation workflow executed with HMAC verification',
            isComplete: isRunning || isSuccess,
            isRunning: status == PlaybookRunStatus.approved,
            colors: colors,
          ),
          const SizedBox(height: 8),
          _buildPhaseCard(
            title: '3. Traffic Routing & Pod Deployment',
            subtitle: 'Drain traffic from failing version to rollback revision',
            isComplete: isSuccess,
            isRunning: status == PlaybookRunStatus.running,
            colors: colors,
          ),
          const SizedBox(height: 8),
          _buildPhaseCard(
            title: '4. Health Verification & Telemetry',
            subtitle: 'Automated 5-minute error rate check window',
            isComplete: isSuccess,
            isRunning: false,
            colors: colors,
          ),
          const SizedBox(height: 20),

          // Primary Navigation Button
          if (isSuccess) ...[
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => S20RecoveryVerificationScreen(
                        playbookRunId: _resolvedRunId,
                      ),
                      settings: RouteSettings(arguments: _resolvedRunId),
                    ),
                  );
                },
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text(
                  'Verify System Recovery',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.ok,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _fetchStatus(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'Refresh Execution State',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.card,
                  foregroundColor: colors.text,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, AppColorScheme colors,
      {Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.muted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: highlightColor ?? colors.text,
            fontFamily: label == 'Playbook ID' ? 'JetBrains Mono' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseCard({
    required String title,
    required String subtitle,
    required bool isComplete,
    bool isRunning = false,
    required AppColorScheme colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRunning
              ? colors.accent
              : (isComplete ? colors.ok.withOpacity(0.4) : colors.border),
        ),
      ),
      child: Row(
        children: [
          if (isRunning)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            )
          else
            Icon(
              isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: isComplete ? colors.ok : colors.muted,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(BuildContext context, {required bool isSuccess}) {
    final colors = context.colors;
    final stages = ['Detect', 'Investigate', 'Cause', 'Approve', 'Recover'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(stages.length, (index) {
          final isCurrent = index == 4;
          Color dotColor = isSuccess
              ? colors.ok
              : (isCurrent ? colors.accent : colors.ok);

          return Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stages[index],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent ? colors.text : colors.muted,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
