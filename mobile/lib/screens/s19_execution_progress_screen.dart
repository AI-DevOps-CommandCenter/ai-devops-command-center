import 'dart:async';
import 'package:flutter/material.dart';
import '../models/playbook_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class S19ExecutionProgressScreen extends StatefulWidget {
  final String? runId;

  const S19ExecutionProgressScreen({super.key, this.runId});

  @override
  State<S19ExecutionProgressScreen> createState() => _S19ExecutionProgressScreenState();
}

class _S19ExecutionProgressScreenState extends State<S19ExecutionProgressScreen> {
  final ApiService _apiService = ApiService();

  PlaybookRunModel? _run;
  bool _isLoading = true;
  int _currentStepIndex = 1;
  Timer? _stepTimer;
  Timer? _pollTimer;
  bool _isCancelling = false;

  final List<Map<String, String>> _defaultSteps = const [
    {
      'time': '14:24:02',
      'title': 'Queued & Approved',
      'detail': 'Playbook run validated by operator decision',
    },
    {
      'time': '14:24:18',
      'title': 'Dispatched to n8n workflow',
      'detail': 'Workflow: remediation-workflow (ID: n8n-exec-8491)',
    },
    {
      'time': '14:25:05',
      'title': 'Switching traffic & draining pods',
      'detail': 'Routing ingress to healthy deployment v2.8.0',
    },
    {
      'time': '14:26:12',
      'title': 'Execution complete',
      'detail': 'Playbook action finished. Awaiting health verification.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPlaybookRun();
    _startSimulatedStepProgression();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPlaybookRun() async {
    try {
      final id = widget.runId ?? 'run-uuid-1042-rb';
      final run = await _apiService.fetchPlaybookRun(id);
      if (mounted) {
        setState(() {
          _run = run;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startSimulatedStepProgression() {
    // Progressively advances the n8n execution timeline every 2.5 seconds for live visual verification
    _stepTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (!mounted) return;
      if (_currentStepIndex < _defaultSteps.length) {
        setState(() {
          _currentStepIndex++;
        });
      } else {
        _stepTimer?.cancel();
      }
    });
  }

  Future<void> _handleCancelRun() async {
    final runId = _run?.id ?? widget.runId ?? 'run-uuid-1042-rb';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Playbook Run?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.text),
        ),
        content: Text(
          'Are you sure you want to stop this playbook execution? Running processes in n8n will be aborted.',
          style: TextStyle(fontSize: 13, color: context.colors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Running', style: TextStyle(color: context.colors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel Run', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isCancelling = true);
      _stepTimer?.cancel();

      await _apiService.cancelPlaybookRun(
        runId: runId,
        reason: 'Execution manually cancelled from mobile command center.',
      );

      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Playbook run cancelled successfully.'),
            backgroundColor: context.colors.card,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isFinished = _currentStepIndex >= _defaultSteps.length;
    final incidentId = _run?.incidentId ?? 'INC-1042';

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
                          'Execution Progress',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          incidentId,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFinished ? colors.badgeGreenBg : colors.cardAccent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFinished ? colors.green : colors.border,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFinished ? Icons.check_circle_outline : Icons.sync_rounded,
                          size: 12,
                          color: isFinished ? colors.green : colors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isFinished ? 'COMPLETED' : 'RUNNING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isFinished ? colors.green : colors.teal,
                          ),
                        ),
                      ],
                    ),
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
                    // Action Summary Card
                    _buildSummaryCard(colors),
                    const SizedBox(height: 14),

                    // Live Timeline Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'N8N WORKFLOW EXECUTION STEPS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: colors.muted,
                          ),
                        ),
                        Text(
                          'Step $_currentStepIndex of ${_defaultSteps.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Timeline Card
                    _buildTimelineCard(colors),
                    const SizedBox(height: 16),

                    // Post-execution Status or Cancel Button
                    if (isFinished) ...[
                      _buildFinishedCard(colors),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/recovery-verification');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.teal,
                            foregroundColor: colors.isDark ? const Color(0xFF0B1226) : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Verify Recovery',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Cancel Button while in progress
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: _isCancelling ? null : _handleCancelRun,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: colors.cardAccent,
                            foregroundColor: colors.red,
                            side: BorderSide(color: colors.red.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isCancelling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Cancel Run (POST /api/playbook-runs/:id/cancel)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AppColorScheme colors) {
    final action = _run?.actionType ?? PlaybookActionType.rollback;
    final service = _run?.serviceName ?? 'payments-api';
    final fromTo = '${_run?.fromVersion ?? "v2.8.1"} → ${_run?.toVersion ?? "v2.8.0"}';

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
              Container(width: 4, color: colors.teal),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            action.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          Text(
                            service,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.teal,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Target: $fromTo · Production Cluster',
                        style: TextStyle(fontSize: 12, color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineCard(AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_defaultSteps.length, (index) {
          final step = _defaultSteps[index];
          final isCompleted = index < _currentStepIndex;
          final isCurrent = index == _currentStepIndex - 1;
          final isLast = index == _defaultSteps.length - 1;

          Color dotColor = colors.border;
          if (isCompleted) {
            dotColor = colors.teal;
          } else if (isCurrent) {
            dotColor = colors.warnText;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicator & Line
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : (isCurrent
                            ? Container(
                                margin: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              )
                            : null),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 46,
                      color: isCompleted ? colors.teal : colors.border,
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            step['title']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCompleted || isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isCompleted || isCurrent ? colors.text : colors.muted,
                            ),
                          ),
                          Text(
                            isCompleted ? step['time']! : '--:--:--',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: isCompleted ? colors.muted : colors.border,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step['detail']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFinishedCard(AppColorScheme colors) {
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
              Container(width: 4, color: colors.green),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: colors.green, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Execution finished successfully',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'n8n automated workflow has terminated with exit code 0. Health is not yet verified. Recovery must be checked independently.',
                        style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
