import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class S21PostmortemReportScreen extends StatelessWidget {
  const S21PostmortemReportScreen({super.key});

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Postmortem',
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
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Summary',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Elevated errors on payments-api after v2.8.1; resolved by rollback.',
                            style: TextStyle(fontSize: 13, color: colors.text, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Impact Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Impact',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Error rate peaked 12.4%, P95 2.4 s, about 25 minutes.',
                            style: TextStyle(fontSize: 13, color: colors.text, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Timeline
                    Container(
                      padding: const EdgeInsets.all(16),
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
                        children: [
                          Text(
                            'Timeline',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTimelineItem(colors, '14:05', 'Deploy v2.8.1'),
                          _buildTimelineItem(colors, '14:12', 'Alert'),
                          _buildTimelineItem(colors, '14:20', 'AI analysis'),
                          _buildTimelineItem(colors, '14:24', 'Rollback approved by Alex Morgan'),
                          _buildTimelineItem(colors, '14:27', 'Execution done'),
                          _buildTimelineItem(colors, '14:33', 'Recovery verified', isLast: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Probable cause Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Probable cause',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'DB pool timeout lowered to 500 ms (hypothesis supported by logs and timing).',
                            style: TextStyle(fontSize: 13, color: colors.text, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Result Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Result',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Error rate 0.4%, P95 190 ms. Verified recovered.',
                            style: TextStyle(fontSize: 13, color: colors.text, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Return to Dashboard Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(context, '/overview', (route) => false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.teal,
                          foregroundColor: colors.isDark ? const Color(0xFF0B1226) : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Back to Dashboard',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
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

  static Widget _buildTimelineItem(AppColorScheme colors, String time, String desc, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.teal,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 26,
                color: colors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 0),
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: colors.text),
              children: [
                TextSpan(text: '$time  ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required AppColorScheme colors, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: child,
    );
  }
}
