import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class S19ExecutionProgressScreen extends StatefulWidget {
  const S19ExecutionProgressScreen({super.key});

  @override
  State<S19ExecutionProgressScreen> createState() => _S19ExecutionProgressScreenState();
}

class _S19ExecutionProgressScreenState extends State<S19ExecutionProgressScreen> {
  int _currentStepIndex = 1;
  Timer? _timer;

  final List<Map<String, String>> _steps = const [
    {'time': '14:24', 'title': 'Queued'},
    {'time': '14:25', 'title': 'Switching traffic to v2.8.0'},
    {'time': '14:26', 'title': 'Draining v2.8.1'},
    {'time': '14:27', 'title': 'Execution complete'},
  ];

  @override
  void initState() {
    super.initState();
    _startExecutionProgress();
  }

  void _startExecutionProgress() {
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (_currentStepIndex < _steps.length) {
        setState(() {
          _currentStepIndex++;
        });
      } else {
        _timer?.cancel();
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
    final isFinished = _currentStepIndex >= _steps.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
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
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.text, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Execution',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        'INC-1042',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
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
                    // Timeline Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(_steps.length, (index) {
                          final step = _steps[index];
                          final isCompleted = index < _currentStepIndex;
                          final isLast = index == _steps.length - 1;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Indicator & Line
                              Column(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCompleted ? AppColors.teal : AppColors.border,
                                    ),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 38,
                                      color: isCompleted ? AppColors.teal : AppColors.border,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),

                              // Text details
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 0),
                                  child: Row(
                                    children: [
                                      Text(
                                        isCompleted ? step['time']! : '--:--',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isCompleted ? AppColors.text : AppColors.muted,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          step['title']!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isCompleted ? AppColors.text : AppColors.muted,
                                            fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
                                          ),
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
                    ),
                    const SizedBox(height: 16),

                    // Post-execution Status
                    if (isFinished) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Execution finished',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Health is not yet verified. Recovery is checked next.',
                              style: TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/recovery-verification');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Verify Recovery',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
}
