import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import '../services/api_service.dart';

class S31RejectActionScreen extends StatefulWidget {
  final String? approvalId;
  final String? incidentId;

  const S31RejectActionScreen({super.key, this.approvalId, this.incidentId});

  @override
  State<S31RejectActionScreen> createState() => _S31RejectActionScreenState();
}

class _S31RejectActionScreenState extends State<S31RejectActionScreen> {
  String? _selectedReason = 'Evidence is not strong enough';
  final TextEditingController _notesController = TextEditingController(
    text: 'Manual investigation required before executing playbook.',
  );

  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _reasons = [
    'Evidence is not strong enough',
    'I will fix it with a new deploy',
    'Wrong time, high traffic now',
    'Action parameters require correction',
    'Other',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleReject() async {
    final approvalId = widget.approvalId;
    if (approvalId == null || approvalId.isEmpty) {
      setState(() {
        _errorMessage = 'Approval ID is required.';
      });
      return;
    }

    final reason = _notesController.text.trim().isNotEmpty
        ? '${_selectedReason ?? "Rejected"}: ${_notesController.text.trim()}'
        : (_selectedReason ?? 'Action rejected by operator.');

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ApiService().decideApproval(
        approvalId: approvalId,
        approve: false,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Action rejected successfully.'),
            backgroundColor: context.colors.critical,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ready = _selectedReason != null;

    final shortInc = widget.incidentId != null && widget.incidentId!.length > 8
        ? (widget.incidentId!.startsWith('INC-')
            ? widget.incidentId!
            : 'INC-${widget.incidentId!.substring(0, 8).toUpperCase()}')
        : (widget.incidentId ?? 'INC-REJECT');

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
                          'Reject Action',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$shortInc · Remediation decision',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
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

                    Text(
                      'Nothing will run. The incident stays open and the rejection reason is saved to the backend audit log.',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section: Reason
                    Text(
                      'SELECT REJECTION REASON',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.52,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Reasons List
                    ..._reasons.map((r) {
                      final isSelected = _selectedReason == r;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedReason = r;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? colors.accentSoft : colors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? colors.accent : colors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  size: 18,
                                  color: isSelected ? colors.accent : colors.muted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    r,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: colors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 14),

                    // Additional Notes
                    Text(
                      'ADDITIONAL AUDIT COMMENTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.52,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: TextStyle(fontSize: 14, color: colors.text),
                        decoration: const InputDecoration(
                          hintText: 'Enter reason for rejecting this playbook...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: ready && !_isSubmitting ? _handleReject : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.critical,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirm Rejection',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
