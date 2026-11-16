import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import '../services/api_service.dart';
import '../models/incident_model.dart';
import '../models/playbook_model.dart';
import 's18_approve_action_screen.dart';
import 's23_developer_assistant_screen.dart';

/// S17 Recommended action.
/// Shows the AI's recommended remediation for an incident (latest AI analysis)
/// and the enabled playbook(s) for that action. "Request remediation" creates a
/// playbook run + approval (POST /api/playbook-runs). Nothing runs until a
/// DIFFERENT operator/admin approves it on S18.
class S17RecommendedActionScreen extends StatefulWidget {
  final String? incidentId;

  const S17RecommendedActionScreen({super.key, this.incidentId});

  @override
  State<S17RecommendedActionScreen> createState() => _S17RecommendedActionScreenState();
}

class _S17RecommendedActionScreenState extends State<S17RecommendedActionScreen> {
  String? _incidentId;
  IncidentModel? _incident;
  Map<String, dynamic>? _analysis;
  List<Map<String, dynamic>> _playbooks = [];
  List<Map<String, dynamic>> _otherPlaybooks = [];
  String? _selectedPlaybookId;
  ApprovalModel? _pendingApproval;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _reviewed = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_incidentId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _incidentId = args;
      } else if (widget.incidentId != null && widget.incidentId!.isNotEmpty) {
        _incidentId = widget.incidentId;
      }
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final id = _incidentId;
    if (id == null || id.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Open this screen from an incident.';
      });
      return;
    }
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.fetchIncidentById(id),
        api.fetchRecommendation(id),
        api.fetchApprovals(status: 'pending'),
      ]);
      final incident = results[0] as IncidentModel;
      final rec = results[1] as Map<String, dynamic>;
      final approvals = results[2] as List<ApprovalModel>;
      final playbooks = (rec['playbooks'] as List<Map<String, dynamic>>?) ?? [];
      final others = (rec['other_playbooks'] as List<Map<String, dynamic>>?) ?? [];
      ApprovalModel? pending;
      for (final a in approvals) {
        if (a.incidentId == id) {
          pending = a;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _incident = incident;
        _analysis = rec['analysis'] as Map<String, dynamic>?;
        _playbooks = playbooks;
        _otherPlaybooks = others;
        _selectedPlaybookId = playbooks.isNotEmpty ? playbooks.first['id']?.toString() : null;
        _pendingApproval = pending;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _requestRemediation() async {
    final id = _incidentId;
    final playbookId = _selectedPlaybookId;
    if (id == null || playbookId == null) return;
    setState(() => _isSubmitting = true);
    try {
      await ApiService().createPlaybookRun(
        incidentId: id,
        playbookId: playbookId,
        requestPayload: {
          if (_incident != null && _incident!.serviceName.isNotEmpty) 'service_name': _incident!.serviceName,
          if (_analysis?['id'] != null) 'ai_analysis_id': _analysis!['id'],
        },
        idempotencyKey: 'mobile-$id-$playbookId',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remediation requested. Another operator must approve it.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request failed: $message')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openApproval() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => S18ApproveActionScreen(incidentId: _incidentId, approvalId: _pendingApproval?.id),
        settings: RouteSettings(arguments: _incidentId),
      ),
    );
  }

  String _actionLabel(String? action) {
    switch (action) {
      case 'restart':
        return 'Restart service';
      case 'rollback':
        return 'Roll back deployment';
      case 'scale':
        return 'Scale service';
      case 'circuit_breaker':
        return 'Open circuit breaker';
      default:
        return 'No action recommended';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = _incident == null
        ? 'Loading incident…'
        : '${_incident!.title} · ${_incident!.serviceName}';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
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
                          'Recommended action',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 13, color: colors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = context.colors;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colors.critical, size: 32),
              const SizedBox(height: 10),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: colors.text)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final action = _analysis?['recommended_action']?.toString();
    final confidence = _analysis?['confidence'];
    final confidencePct = confidence is num ? '${(confidence * 100).round()}%' : '—';

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepper(context, activeStage: 3),
            const SizedBox(height: 14),

            if (_analysis == null)
              _card(
                context,
                child: Text(
                  'The AI investigation has not produced a recommendation for this incident yet. Pull down to refresh.',
                  style: TextStyle(fontSize: 14, color: colors.text, height: 1.4),
                ),
              )
            else ...[
              _card(
                context,
                accent: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 18, color: colors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _actionLabel(action),
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.text),
                          ),
                        ),
                        _pill(context, 'Confidence $confidencePct'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _labelled(context, 'Root cause', _analysis?['root_cause']?.toString() ?? '—'),
                    const SizedBox(height: 8),
                    _labelled(context, 'Summary', _analysis?['summary']?.toString() ?? '—'),
                    if (_analysis?['model_name'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Model: ${_analysis!['model_name']}', style: TextStyle(fontSize: 12, color: colors.muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Recommended playbook', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.muted)),
              const SizedBox(height: 6),
              if (_playbooks.isEmpty)
                _card(
                  context,
                  child: Text(
                    action == null
                        ? 'No action was recommended.'
                        : 'No enabled playbook for "$action". Choose another option below, or ask an admin to enable one.',
                    style: TextStyle(fontSize: 14, color: colors.text),
                  ),
                )
              else
                ..._playbooks.map((p) => _playbookTile(context, p)),
              if (_otherPlaybooks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Other options (your decision)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.muted)),
                const SizedBox(height: 6),
                ..._otherPlaybooks.map((p) => _playbookTile(context, p)),
              ],
              const SizedBox(height: 6),
              _card(
                context,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 18, color: colors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Human in the loop: the request must be approved by a different operator before anything runs. The AI never runs actions itself.',
                        style: TextStyle(fontSize: 13, color: colors.text, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_pendingApproval != null) ...[
                _card(
                  context,
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_top, size: 18, color: colors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Remediation requested — waiting for approval.',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _primaryButton(context, 'Open approval', Icons.arrow_forward, _openApproval),
              ] else if (_playbooks.isNotEmpty || _otherPlaybooks.isNotEmpty) ...[
                CheckboxListTile(
                  value: _reviewed,
                  onChanged: (v) => setState(() => _reviewed = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: colors.accent,
                  title: Text('I reviewed the root cause and evidence',
                      style: TextStyle(fontSize: 14, color: colors.text)),
                ),
                const SizedBox(height: 6),
                _primaryButton(
                  context,
                  _isSubmitting ? 'Requesting…' : 'Request remediation',
                  Icons.send,
                  _reviewed && !_isSubmitting && _selectedPlaybookId != null ? _requestRemediation : null,
                ),
              ],
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const S23DeveloperAssistantScreen()),
                  );
                },
                icon: Icon(Icons.auto_awesome, size: 18, color: colors.text),
                label: Text('Ask assistant',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.card,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playbookTile(BuildContext context, Map<String, dynamic> p) {
    final colors = context.colors;
    final id = p['id']?.toString();
    final selected = id == _selectedPlaybookId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pendingApproval == null ? () => setState(() => _selectedPlaybookId = id) : null,
        child: _card(
          context,
          accent: selected,
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 18, color: selected ? colors.accent : colors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name']?.toString() ?? 'Playbook',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
                    if ((p['description']?.toString() ?? '').isNotEmpty)
                      Text(p['description'].toString(), style: TextStyle(fontSize: 12, color: colors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child, bool accent = false}) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent ? colors.cardAccent : colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent ? colors.accent : colors.border),
      ),
      child: child,
    );
  }

  Widget _pill(BuildContext context, String text) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.accent)),
    );
  }

  Widget _labelled(BuildContext context, String label, String value) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.muted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, color: colors.text, height: 1.4)),
      ],
    );
  }

  Widget _primaryButton(BuildContext context, String label, IconData icon, VoidCallback? onPressed) {
    final colors = context.colors;
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.surface2,
          disabledForegroundColor: colors.muted,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
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
        children: List.generate(stages.length, (index) {
          final isCompleted = index < activeStage;
          final isActive = index == activeStage;
          Color textColor = colors.muted;
          FontWeight fontWeight = FontWeight.w500;
          if (isActive) {
            textColor = colors.accent;
            fontWeight = FontWeight.w600;
          } else if (isCompleted) {
            textColor = colors.text;
          }
          return Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (index > 0)
                  Positioned(
                    top: 10,
                    right: 0,
                    left: -50,
                    child: Container(height: 2, color: isCompleted || isActive ? colors.success : colors.border),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isCompleted ? colors.success : isActive ? colors.accentSoft : colors.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted ? colors.success : isActive ? colors.accent : colors.border,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isCompleted
                          ? Icon(Icons.check, size: 13, color: colors.card)
                          : isActive
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                                )
                              : null,
                    ),
                    const SizedBox(height: 6),
                    Text(stages[index],
                        style: TextStyle(fontSize: 11, fontWeight: fontWeight, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
