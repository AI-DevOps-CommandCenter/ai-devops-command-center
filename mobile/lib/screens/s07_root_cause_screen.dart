import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class S07RootCauseScreen extends StatelessWidget {
  const S07RootCauseScreen({super.key});

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
                          'Root Cause',
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
                    // AI Inference Card (with subtle dashed-style teal border)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.teal, width: 1.2),
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
                          _buildBadge('AI inference', colors.badgeTealBg, colors.teal),
                          const SizedBox(height: 8),
                          Text(
                            'Probable cause: database connection configuration change in v2.8.1',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Connection timeouts began 2 minutes after the deploy and match a lowered pool timeout.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.text,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Confidence: moderate (about 75%). Correlation supports this hypothesis; it does not prove it.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Observed Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBadge('Observed', colors.isDark ? const Color(0xFF26335C) : const Color(0xFFE1E8F4), colors.text),
                          const SizedBox(height: 10),
                          Text('• Error rate 0.3% → 12.4%', style: TextStyle(fontSize: 13, color: colors.text)),
                          const SizedBox(height: 4),
                          Text('• P95 180 ms → 2.4 s', style: TextStyle(fontSize: 13, color: colors.text)),
                          const SizedBox(height: 4),
                          Text('• 212 “connection timeout” log lines', style: TextStyle(fontSize: 13, color: colors.text)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Recommended Next Step Card
                    _buildCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended next step',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Roll back payments-api to v2.8.0.',
                            style: TextStyle(fontSize: 13, color: colors.text),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2 Buttons (Grid 2 cols): View Evidence / Recommended Action
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/evidence-details');
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
                                'View Evidence',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.text),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/recommended-action');
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
                                'Recommended Action',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}
