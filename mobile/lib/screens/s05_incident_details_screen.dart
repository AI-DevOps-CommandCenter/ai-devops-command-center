import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import '../widgets/proto_icon.dart';
import '../services/api_service.dart';
import '../models/incident_model.dart';
import 's06_ai_investigation_progress_screen.dart';
import 's07_root_cause_screen.dart';
import 's18_approve_action_screen.dart';
import 's09_logs_explorer_screen.dart';
import 's10_metrics_screen.dart';
import 's14_deployment_details_screen.dart';
import 's19_execution_progress_screen.dart';
import 's20_recovery_verification_screen.dart';
import 's21_postmortem_report_screen.dart';
import '../models/playbook_model.dart';
import '../utils/run_format.dart';

class S05IncidentDetailsScreen extends StatefulWidget {
  final String? incidentId;

  const S05IncidentDetailsScreen({super.key, this.incidentId});

  @override
  State<S05IncidentDetailsScreen> createState() => _S05IncidentDetailsScreenState();
}

class _S05IncidentDetailsScreenState extends State<S05IncidentDetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  IncidentModel? _incident;
  String? _resolvedIncidentId;
  // Remediation history for the links to S19 / S20 / S21. Loaded after the
  // incident; a failure here only hides the links.
  PlaybookRunModel? _latestRun;
  Map<String, dynamic>? _latestCheck;
  bool _hasPostmortem = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedIncidentId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _resolvedIncidentId = args;
      } else if (widget.incidentId != null && widget.incidentId!.isNotEmpty) {
        _resolvedIncidentId = widget.incidentId;
      }
      _loadIncident();
    }
  }

  Future<void> _loadIncident() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final id = _resolvedIncidentId;
    if (id == null || id.isEmpty) {
      // If no ID passed, try fetching the first incident from the list
      try {
        final list = await ApiService().fetchIncidents();
        if (list.isNotEmpty && mounted) {
          setState(() {
            _incident = list.first;
            _resolvedIncidentId = list.first.id;
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
        return;
      }
    }

    try {
      final incident = await ApiService().fetchIncidentById(_resolvedIncidentId!);
      if (mounted) {
        setState(() {
          _incident = incident;
          _isLoading = false;
        });
        _loadRemediation(incident.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRemediation(String incidentId) async {
    final api = ApiService();
    PlaybookRunModel? latest;
    Map<String, dynamic>? check;
    var hasPostmortem = false;
    try {
      final runs = (await api.fetchPlaybookRuns(incidentId: incidentId))
          .where((r) => r.incidentId == incidentId && r.status != PlaybookRunStatus.pendingApproval)
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      latest = runs.isEmpty ? null : runs.first;
      if (latest != null) {
        check = recoveryCheckForRun(await api.fetchRecoveryChecks(incidentId), latest.id);
      }
    } catch (_) {}
    try {
      hasPostmortem = await api.fetchLatestPostmortem(incidentId) != null;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _latestRun = latest;
      _latestCheck = check;
      _hasPostmortem = hasPostmortem;
    });
  }

  Widget _buildRemediationLinks(AppColorScheme colors, IncidentModel incident) {
    final run = _latestRun;
    if (run == null && !_hasPostmortem) return const SizedBox.shrink();
    final checkStatus = _latestCheck?['status']?.toString();
    final checkLabel = switch (checkStatus) {
      'healthy' => 'Recovered',
      'unhealthy' => 'Not recovered',
      'failed' => 'Could not verify',
      _ => run?.status == PlaybookRunStatus.success ? 'Checking…' : 'No check yet',
    };

    Widget link({required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        enabled: onTap != null,
        leading: Icon(icon, size: 20, color: onTap != null ? colors.accent : colors.muted),
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: colors.muted)),
        trailing: onTap != null ? Icon(Icons.chevron_right, color: colors.muted) : null,
        onTap: onTap,
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REMEDIATION',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: colors.muted)),
          if (run != null) ...[
            link(
              icon: Icons.play_circle_outline,
              title: 'Latest run',
              subtitle: '${run.playbookName ?? run.actionType.displayName} · ${run.status.slug}'
                  '${run.createdAt != null ? ' · ${localTime(run.createdAt)}' : ''}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => S19ExecutionProgressScreen(playbookRunId: run.id),
                  settings: RouteSettings(arguments: run.id),
                ),
              ),
            ),
            link(
              icon: Icons.monitor_heart_outlined,
              title: 'Recovery checks',
              subtitle: checkLabel,
              onTap: run.status == PlaybookRunStatus.success
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => S20RecoveryVerificationScreen(playbookRunId: run.id),
                          settings: RouteSettings(arguments: run.id),
                        ),
                      )
                  : null,
            ),
          ],
          link(
            icon: Icons.description_outlined,
            title: 'Postmortem',
            subtitle: _hasPostmortem ? 'AI draft ready' : 'Not written yet',
            onTap: _hasPostmortem
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => S21PostmortemReportScreen(incidentId: incident.id),
                        settings: RouteSettings(arguments: incident.id),
                      ),
                    )
                : null,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final incident = _incident;

    final shortId = incident != null
        ? (incident.id.length > 8
            ? (incident.id.startsWith('INC-')
                ? incident.id
                : 'INC-${incident.id.substring(0, 8).toUpperCase()}')
            : incident.id)
        : (_resolvedIncidentId != null && _resolvedIncidentId!.length > 8
            ? 'INC-${_resolvedIncidentId!.substring(0, 8).toUpperCase()}'
            : 'INC-DETAILS');

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
                          shortId,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          incident?.title ?? 'Incident details',
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
              child: _buildBody(colors, incident),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme colors, IncidentModel? incident) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || incident == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.red),
              const SizedBox(height: 12),
              Text(
                'Failed to load incident details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage ?? 'Incident not found on backend.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadIncident,
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

    final isCritical = incident.severity == IncidentSeverity.critical;
    final sevBg = isCritical ? colors.badgeRedBg : colors.badgeAmberBg;
    final sevFg = isCritical ? colors.critical : colors.warning;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Badges row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: sevBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 13, color: sevFg),
                    const SizedBox(width: 4),
                    Text(
                      incident.severity.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: sevFg,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  incident.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: colors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Production',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: colors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stepper: Detect -> Investigate -> Cause -> Approve -> Recover -> Report
          _buildStepper(context, activeStage: incident.status == IncidentStatus.open ? 0 : 1),
          const SizedBox(height: 14),

          // Metadata Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                _buildMetaRow(
                  label: 'Service',
                  valueWidget: Text(
                    incident.serviceName,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildMetaRow(
                  label: 'Detected',
                  valueWidget: Text(
                    _formatDateTime(incident.detectedAt),
                    style: TextStyle(fontSize: 13, color: colors.text),
                  ),
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildMetaRow(
                  label: 'Status',
                  valueWidget: Text(
                    incident.status.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildMetaRow(
                  label: 'ID',
                  valueWidget: Text(
                    incident.id,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'JetBrains Mono',
                      color: colors.muted,
                    ),
                  ),
                  colors: colors,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Description Card
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
                  'INCIDENT SUMMARY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  incident.summary.isNotEmpty
                      ? incident.summary
                      : 'Production alert triggered on ${incident.serviceName}. Automated investigation in progress.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Explore Buttons (Logs, Metrics, Deploy)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => S09LogsExplorerScreen(service: incident.serviceName),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        ProtoIcon(ProtoIcons.logs, size: 20, color: colors.text),
                        const SizedBox(height: 6),
                        Text(
                          'Logs',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => S10MetricsScreen(service: incident.serviceName),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        ProtoIcon(ProtoIcons.metrics, size: 20, color: colors.text),
                        const SizedBox(height: 6),
                        Text(
                          'Metrics',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const S14DeploymentDetailsScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        ProtoIcon(ProtoIcons.deploy, size: 20, color: colors.text),
                        const SizedBox(height: 6),
                        Text(
                          'Deploy',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => S06AiInvestigationProgressScreen(incidentId: incident.id),
                  settings: RouteSettings(arguments: incident.id),
                ),
              ),
              icon: const Icon(Icons.timelapse, size: 18),
              label: const Text('Investigation progress'),
            ),
          ),
          const SizedBox(height: 6),
          // Primary Button 1: View AI Root Cause
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => S07RootCauseScreen(incidentId: incident.id),
                    settings: RouteSettings(arguments: incident.id),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text(
                'View AI Root Cause',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Primary Button 2: Remediation / Approve Action
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => S18ApproveActionScreen(incidentId: incident.id),
                    settings: RouteSettings(arguments: incident.id),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text(
                'Review Remediation & Approvals',
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
          _buildRemediationLinks(colors, incident),
        ],
      ),
    );
  }

  Widget _buildMetaRow({
    required String label,
    required Widget valueWidget,
    required AppColorScheme colors,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: colors.muted),
        ),
        valueWidget,
      ],
    );
  }

  Widget _buildStepper(BuildContext context, {required int activeStage}) {
    final colors = context.colors;
    final stages = ['Detect', 'Investigate', 'Cause', 'Approve', 'Recover', 'Report'];

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
          final isPast = index < activeStage;
          final isCurrent = index == activeStage;
          Color dotColor = colors.muted;
          if (isPast) dotColor = colors.ok;
          if (isCurrent) dotColor = colors.accent;

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
