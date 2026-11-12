import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import 's19_execution_progress_screen.dart';

class S18ApproveActionScreen extends StatefulWidget {
  const S18ApproveActionScreen({super.key});

  @override
  State<S18ApproveActionScreen> createState() => _S18ApproveActionScreenState();
}

class _S18ApproveActionScreenState extends State<S18ApproveActionScreen> {
  double _dragPosition = 0.0;
  bool _isApproved = false;

  void _triggerApproval() {
    if (_isApproved) return;
    setState(() {
      _isApproved = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const S19ExecutionProgressScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
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
                          'Approve Rollback',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'INC-1042 · Final confirmation',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                                child: Text('AM', style: TextStyle(color: colors.onAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Alex Morgan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.text)),
                                  Text('Tech Lead · Approver role', style: TextStyle(fontSize: 12, color: colors.muted)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(color: colors.border, height: 1),
                          const SizedBox(height: 14),
                          Text('TARGET SERVICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.muted)),
                          const SizedBox(height: 2),
                          Text('payments-api (production)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.text)),
                          const SizedBox(height: 10),
                          Text('ACTION TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.muted)),
                          const SizedBox(height: 2),
                          Text('Roll back to v2.8.0', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.text)),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Slide to Confirm Widget
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
                                  _isApproved ? 'Approved!' : 'Slide to approve rollback →',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _isApproved ? colors.success : colors.muted,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: _dragPosition,
                                top: 2,
                                bottom: 2,
                                child: GestureDetector(
                                  onHorizontalDragUpdate: (details) {
                                    if (_isApproved) return;
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
                                      color: _isApproved ? colors.success : colors.accent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      _isApproved ? Icons.check : Icons.arrow_forward,
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
                    Center(
                      child: Text(
                        'Audit record will be permanently logged',
                        style: TextStyle(fontSize: 12, color: colors.muted),
                      ),
                    ),
                    const SizedBox(height: 16),
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
