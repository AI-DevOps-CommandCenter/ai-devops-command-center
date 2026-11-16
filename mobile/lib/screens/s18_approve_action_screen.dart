import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import '../services/api_service.dart';
import '../models/playbook_model.dart';
import 's19_execution_progress_screen.dart';
import 's31_reject_action_screen.dart';

class S18ApproveActionScreen extends StatefulWidget {
  final String? incidentId;
  final String? approvalId;

  const S18ApproveActionScreen({super.key, this.incidentId, this.approvalId});

  @override
  State<S18ApproveActionScreen> createState() => _S18ApproveActionScreenState();
}

class _S18ApproveActionScreenState extends State<S18ApproveActionScreen> {
  double _dragPosition = 0.0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<ApprovalModel> _pendingApprovals = [];
  ApprovalModel? _selectedApproval;
  String? _resolvedIncidentId;

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
      _loadApprovals();
    }
  }

  Future<void> _loadApprovals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService().fetchApprovals(status: 'pending');
      if (mounted) {
        setState(() {
          _pendingApprovals = list;
          ApprovalModel? match;
          for (final a in list) {
            if (widget.approvalId != null && a.id == widget.approvalId) {
              match = a;
              break;
            }
            if (_resolvedIncidentId != null && a.incidentId == _resolvedIncidentId) {
              match = a;
              break;
            }
          }
          _selectedApproval = match ?? (list.isNotEmpty ? list.first : null);
          _isLoading = false;
        });
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

  Future<void> _triggerApproval() async {
    final approval = _selectedApproval;
    if (approval == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService().decideApproval(
        approvalId: approval.id,
        approve: true,
      );

      final runId = approval.playbookRunId.isNotEmpty
          ? approval.playbookRunId
          : (res['data'] is Map ? res['data']['playbook_run_id']?.toString() ?? '' : '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Action approved successfully!'),
            backgroundColor: context.colors.ok,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => S19ExecutionProgressScreen(
              playbookRunId: runId,
              approvalId: approval.id,
            ),
            settings: RouteSettings(arguments: runId),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _dragPosition = 0.0;
          _errorMessage = e.message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: context.colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _dragPosition = 0.0;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final approval = _selectedApproval;

    final shortIncId = approval != null && approval.incidentId.length > 8
        ? (approval.incidentId.startsWith('INC-')
            ? approval.incidentId
            : 'INC-${approval.incidentId.substring(0, 8).toUpperCase()}')
        : (approval?.incidentId ?? 'INC-ACTION');

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
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approve Action',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          '$shortIncId · Final confirmation',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _buildContent(colors, approval),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppColorScheme colors, ApprovalModel? approval) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && approval == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.red),
              const SizedBox(height: 12),
              Text(
                'Unable to load pending approvals',
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
                onPressed: _loadApprovals,
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

    if (approval == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: colors.ok),
              const SizedBox(height: 12),
              Text(
                'No pending approvals found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'All actions for this incident have already been reviewed or executed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.card,
                  foregroundColor: colors.text,
                ),
                child: const Text('Back to Incident'),
              ),
            ],
          ),
        ),
      );
    }

    final actionDisplayName = approval.actionType.displayName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Multiple Approvals Selector (Supports Vishwa's 2-approval testing requirement)
          if (_pendingApprovals.length > 1) ...[
            Text(
              'PENDING APPROVALS (${_pendingApprovals.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colors.muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _pendingApprovals.map((item) {
                final isSelected = item.id == approval.id;
                return ChoiceChip(
                  label: Text('${item.actionType.displayName} (#${item.id.length > 6 ? item.id.substring(0, 6) : item.id})'),
                  selected: isSelected,
                  selectedColor: colors.accent,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? colors.onAccent : colors.text,
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedApproval = item;
                        _dragPosition = 0.0;
                        _errorMessage = null;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Approval Detail Card
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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colors.accent,
                      child: Text(
                        approval.requestedBy.isNotEmpty
                            ? approval.requestedBy.substring(0, 1).toUpperCase()
                            : 'O',
                        style: TextStyle(
                          color: colors.onAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          approval.requestedBy,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'Requested remediation action',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: colors.border, height: 1),
                const SizedBox(height: 14),
                Text(
                  'TARGET SERVICE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${approval.serviceName} (${approval.environment})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'ACTION TYPE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  actionDisplayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'IMPACT DESCRIPTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  approval.impactDescription,
                  style: TextStyle(fontSize: 13, color: colors.text, height: 1.4),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Slide to Confirm / Approve
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxDrag = constraints.maxWidth - 56;
                return Stack(
                  children: [
                    Center(
                      child: Text(
                        _isSubmitting
                            ? 'Approving via backend...'
                            : 'Slide to approve action →',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _isSubmitting ? colors.accent : colors.muted,
                        ),
                      ),
                    ),
                    Positioned(
                      left: _dragPosition,
                      top: 2,
                      bottom: 2,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          if (_isSubmitting) return;
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx)
                                .clamp(0.0, maxDrag);
                          });
                        },
                        onHorizontalDragEnd: (details) {
                          if (_dragPosition >= maxDrag * 0.75) {
                            setState(() => _dragPosition = maxDrag);
                            _triggerApproval();
                          } else {
                            setState(() => _dragPosition = 0.0);
                          }
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _isSubmitting ? colors.ok : colors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_forward,
                                  color: colors.onAccent,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Reject Button: Navigates to S31
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () async {
                final rejected = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => S31RejectActionScreen(
                      approvalId: approval.id,
                      incidentId: approval.incidentId,
                    ),
                  ),
                );
                if (rejected == true) {
                  _loadApprovals();
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.critical.withOpacity(0.5)),
                foregroundColor: colors.critical,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Reject Action',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Center(
            child: Text(
              'Decision will be permanently recorded in audit logs',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
