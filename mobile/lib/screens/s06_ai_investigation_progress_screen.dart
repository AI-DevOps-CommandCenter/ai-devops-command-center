import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 's07_root_cause_screen.dart';

class S06AiInvestigationProgressScreen extends StatefulWidget {
  const S06AiInvestigationProgressScreen({super.key});

  @override
  State<S06AiInvestigationProgressScreen> createState() => _S06AiInvestigationProgressScreenState();
}

class _S06AiInvestigationProgressScreenState extends State<S06AiInvestigationProgressScreen> {
  double _progress = 0.0;
  int _currentStepIndex = 0;
  Timer? _timer;

  final List<String> _steps = const [
    'Collecting logs',
    'Checking metrics',
    'Reviewing deployments',
    'Correlating evidence',
  ];

  @override
  void initState() {
    super.initState();
    _startInvestigationSimulation();
  }

  void _startInvestigationSimulation() {
    _timer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (_currentStepIndex < _steps.length) {
        setState(() {
          _currentStepIndex++;
          _progress = (_currentStepIndex) / _steps.length;
        });
      } else {
        _timer?.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const S07RootCauseScreen()),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Investigating',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.text,
                        ),
                      ),
                      Text(
                        'INC-1042',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Progress Bar
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.isDark ? const Color(0xFF26335C) : const Color(0xFFE1E8F4),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.teal,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Steps List with animated checkmarks
              Expanded(
                child: Column(
                  children: List.generate(_steps.length, (index) {
                    final isDone = index < _currentStepIndex;
                    final isCurrent = index == _currentStepIndex;
                    final isPending = index > _currentStepIndex;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? colors.teal
                                  : isCurrent
                                      ? colors.badgeTealBg
                                      : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDone || isCurrent ? colors.teal : colors.border,
                                width: 2,
                              ),
                            ),
                            child: isDone
                                ? Icon(Icons.check, size: 14, color: colors.isDark ? const Color(0xFF06202A) : Colors.white)
                                : isCurrent
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: colors.teal,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            _steps[index],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isDone || isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isPending ? colors.muted : colors.text,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              // Button when completed
              if (_progress >= 1.0)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const S07RootCauseScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.teal,
                      foregroundColor: colors.isDark ? const Color(0xFF06202A) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'See Root Cause',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
