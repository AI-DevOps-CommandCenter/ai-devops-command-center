import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';

class S31RejectActionScreen extends StatefulWidget {
  const S31RejectActionScreen({super.key});

  @override
  State<S31RejectActionScreen> createState() => _S31RejectActionScreenState();
}

class _S31RejectActionScreenState extends State<S31RejectActionScreen> {
  String? _selectedReason;
  final TextEditingController _notesController = TextEditingController(
    text: 'Will ship PR #215 instead.',
  );

  final List<String> _reasons = [
    'Evidence is not strong enough',
    'I will fix it with a new deploy',
    'Wrong time, high traffic now',
    'Other',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ready = _selectedReason != null;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: padding: 14px 16px 10px, gap: 10px
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
                          'Reject rollback',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'INC-1042 · payments-api',
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

            // Content: padding: 4px 16px 24px, gap: 14px
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nothing will run. The incident stays open and the reason is saved to the audit log.',
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section: Reason
                    Text(
                      'REASON',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.52,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Radiogroup
                    Column(
                      children: _reasons.map((r) {
                        final isSelected = _selectedReason == r;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            onTap: () => setState(() => _selectedReason = r),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 52),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? colors.accent : colors.muted,
                                        width: 2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: isSelected
                                        ? Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: colors.accent,
                                              shape: BoxShape.circle,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      r,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: colors.text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Note (optional)
                    Text(
                      'Note (optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: 15,
                          color: colors.text,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Action Button
                    if (ready)
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.critical,
                            foregroundColor: colors.card,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Reject and keep investigating',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'Choose a reason',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.muted,
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
