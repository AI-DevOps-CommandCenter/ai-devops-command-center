import 'package:flutter/material.dart';
import '../models/playbook_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class S18ApproveActionScreen extends StatefulWidget {
  final ApprovalModel? initialApproval;

  const S18ApproveActionScreen({super.key, this.initialApproval});

  @override
  State<S18ApproveActionScreen> createState() => _S18ApproveActionScreenState();
}

class _S18ApproveActionScreenState extends State<S18ApproveActionScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();

  bool _isLoading = false;
  bool _isCancelled = false;
  String? _errorMessage;

  // Selected action type for testing/demonstration across all 4 supported playbook actions
  PlaybookActionType _selectedAction = PlaybookActionType.rollback;
  ApprovalModel? _currentApproval;

  @override
  void initState() {
    super.initState();
    _loadApprovalData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovalData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.initialApproval != null) {
        _currentApproval = widget.initialApproval;
        _selectedAction = widget.initialApproval!.actionType;
      } else {
        final approvals = await _apiService.fetchPendingApprovals();
        if (approvals.isNotEmpty) {
          _currentApproval = approvals.first;
          _selectedAction = _currentApproval!.actionType;
        }
      }
    } catch (_) {
      // Graceful fallback to mock data
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _switchActionType(PlaybookActionType type) {
    setState(() {
      _selectedAction = type;
      _commentController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _handleApprove() async {
    final currentUser = AuthService().currentUser?.name ?? 'Operator';
    final requester = _currentApproval?.requestedBy ?? 'Alex Morgan';

    // Verification check for Vinuka's Authorization Rule:
    // "Users cannot approve their own requests"
    if (currentUser.trim().toLowerCase() == requester.trim().toLowerCase()) {
      _showSelfApprovalWarning();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final runId = _currentApproval?.playbookRunId ?? 'run-uuid-1042-rb';
    final comments = _commentController.text.trim().isNotEmpty
        ? _commentController.text.trim()
        : 'Approved after incident root-cause review.';

    final res = await _apiService.submitPlaybookDecision(
      runId: runId,
      approve: true,
      comments: comments,
      approvalId: _currentApproval?.id,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success'] == true) {
        Navigator.pushNamed(context, '/execution-progress', arguments: runId);
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Unable to approve action.';
        });
      }
    }
  }

  Future<void> _handleCancelOrReject() async {
    setState(() => _isLoading = true);
    final runId = _currentApproval?.playbookRunId ?? 'run-uuid-1042-rb';
    final reason = _commentController.text.trim().isNotEmpty
        ? _commentController.text.trim()
        : 'Action cancelled by operator upon manual review.';

    await _apiService.cancelPlaybookRun(
      runId: runId,
      reason: reason,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isCancelled = true;
      });
    }
  }

  void _showSelfApprovalWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: context.colors.warnText, size: 22),
            const SizedBox(width: 8),
            Text(
              'Authorization Rule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.colors.text,
              ),
            ),
          ],
        ),
        content: Text(
          'Users cannot approve their own requests.\n\nThis approval was requested by "${_currentApproval?.requestedBy ?? 'Alex Morgan'}". A different admin or operator must approve this action.',
          style: TextStyle(fontSize: 13, color: context.colors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Understood', style: TextStyle(color: context.colors.teal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
                          'Approve Action',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          _currentApproval?.incidentId ?? 'INC-1042',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.cardAccent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_clock_outlined, size: 12, color: colors.warnText),
                        const SizedBox(width: 4),
                        Text(
                          'S18',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.warnText,
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
              child: _isLoading && _currentApproval == null
                  ? Center(child: CircularProgressIndicator(color: colors.teal))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: _isCancelled ? _buildCancelledView(colors) : _buildApprovalView(colors),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalView(AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Selector Pills (4 supported actions)
        Text(
          'SUPPORTED REMEDIATION ACTION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: colors.muted,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: PlaybookActionType.values.map((type) {
              final isSelected = _selectedAction == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type.icon,
                        size: 14,
                        color: isSelected
                            ? (colors.isDark ? const Color(0xFF0B1226) : Colors.white)
                            : colors.text,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (colors.isDark ? const Color(0xFF0B1226) : Colors.white)
                              : colors.text,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: colors.teal,
                  backgroundColor: colors.card,
                  checkmarkColor: Colors.transparent,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? colors.teal : colors.cardBorder,
                      width: 0.8,
                    ),
                  ),
                  onSelected: (_) => _switchActionType(type),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Approval Details Accent Card
        _buildActionDetailsCard(colors),
        const SizedBox(height: 14),

        // Warning / Impact Note
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.warnBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.warnText.withOpacity(0.3), width: 0.8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: colors.warnText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getImpactNote(),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.warnText,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Operator Review Comments Field
        Text(
          'DECISION COMMENTS (OPTIONAL)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: colors.muted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.cardBorder, width: 0.8),
          ),
          child: TextField(
            controller: _commentController,
            style: TextStyle(fontSize: 13, color: colors.text),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Enter justification or audit comments...',
              hintStyle: TextStyle(fontSize: 12, color: colors.muted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.red, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(fontSize: 12, color: colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Primary Action: Approve and Execute
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.red,
              foregroundColor: colors.isDark ? const Color(0xFF0B1226) : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Approve and Execute (${_selectedAction.displayName})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),

        // Cancel / Reject Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _handleCancelOrReject,
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.cardAccent,
              foregroundColor: colors.text,
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Reject / Cancel Action',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActionDetailsCard(AppColorScheme colors) {
    final title = _getActionTitle();
    final service = _currentApproval?.serviceName ?? 'payments-api';
    final env = _currentApproval?.environment ?? 'Production';
    final requester = _currentApproval?.requestedBy ?? 'Alex Morgan';

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
                        children: [
                          Icon(_selectedAction.icon, size: 18, color: colors.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.cardAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _selectedAction.slug,
                              style: TextStyle(fontSize: 10, color: colors.muted, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildRow(colors, 'Target Service', service),
                      Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                      _buildRow(colors, 'Environment', env),
                      Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                      _buildDynamicDetailRow(colors),
                      Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                      _buildRow(colors, 'Requested By', requester),
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

  String _getActionTitle() {
    switch (_selectedAction) {
      case PlaybookActionType.restart:
        return 'Restart payments-api pods';
      case PlaybookActionType.rollback:
        return 'Roll back payments-api deployment';
      case PlaybookActionType.scale:
        return 'Scale payments-api replicas (x2)';
      case PlaybookActionType.circuitBreaker:
        return 'Enable Circuit Breaker on payments-api';
    }
  }

  String _getImpactNote() {
    switch (_selectedAction) {
      case PlaybookActionType.restart:
        return 'Impact: Rolling restart with zero downtime. 1 replica restarted at a time. Total duration ~45s.';
      case PlaybookActionType.rollback:
        return 'Impact: Brief request failures during switchover (about 30 s). Reverts code to previous build v2.8.0.';
      case PlaybookActionType.scale:
        return 'Impact: Increases replicas from 3 to 6 pods. Minimal latency impact, extra cloud compute allocation.';
      case PlaybookActionType.circuitBreaker:
        return 'Impact: Temporarily rejects 3rd-party gateway requests with fast-fail response until health recovers.';
    }
  }

  Widget _buildDynamicDetailRow(AppColorScheme colors) {
    switch (_selectedAction) {
      case PlaybookActionType.rollback:
        return _buildRow(colors, 'From → To', 'v2.8.1 → v2.8.0');
      case PlaybookActionType.restart:
        return _buildRow(colors, 'Restart Mode', 'Rolling (3/3 replicas)');
      case PlaybookActionType.scale:
        return _buildRow(colors, 'Replicas', '3 pods → 6 pods (+100%)');
      case PlaybookActionType.circuitBreaker:
        return _buildRow(colors, 'Fail Threshold', '50% errors / 10s trip');
    }
  }

  Widget _buildCancelledView(AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                children: [
                  Container(width: 4, color: colors.muted),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cancel_outlined, color: colors.muted, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Approval cancelled',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nothing was executed. The incident remains open in the Command Center queue.',
                            style: TextStyle(fontSize: 13, color: colors.muted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _isCancelled = false;
              });
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.cardAccent,
              foregroundColor: colors.text,
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Back to approval form',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Return to Incident',
              style: TextStyle(fontSize: 14, color: colors.muted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(AppColorScheme colors, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.muted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
      ],
    );
  }
}
