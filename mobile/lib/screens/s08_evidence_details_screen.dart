import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class S08EvidenceDetailsScreen extends StatelessWidget {
  const S08EvidenceDetailsScreen({super.key});

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
                          'Evidence',
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
                    // Section 1: Log excerpts
                    Text(
                      'Log excerpts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Log Item 1: 14:07:11 ERROR payments-api connection timeout after 500ms
                    _buildLogItem(
                      colors: colors,
                      timestamp: '14:07:11',
                      level: 'ERROR',
                      levelColor: colors.red,
                      levelBg: colors.badgeRedBg,
                      prefix: 'payments-api ',
                      highlight: 'connection timeout',
                      suffix: ' after 500ms',
                    ),
                    const SizedBox(height: 8),

                    // Log Item 2: 14:07:14 WARN pool exhausted (20/20)
                    _buildLogItem(
                      colors: colors,
                      timestamp: '14:07:14',
                      level: 'WARN',
                      levelColor: colors.amber,
                      levelBg: colors.badgeAmberBg,
                      prefix: 'pool exhausted (20/20)',
                      highlight: null,
                      suffix: '',
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Metric changes
                    Text(
                      'Metric changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildCard(
                      colors: colors,
                      child: Column(
                        children: [
                          _buildRow(colors, 'Error rate', '0.3% → 12.4%'),
                          Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                          _buildRow(colors, 'P95 latency', '180 ms → 2.4 s'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Deployment timing
                    Text(
                      'Deployment timing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildCard(
                      colors: colors,
                      child: Column(
                        children: [
                          _buildRow(colors, 'v2.8.1 deployed', '14:05'),
                          Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
                          _buildRow(colors, 'First timeout', '14:07'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Buttons: Logs & Metrics (Grid 2 cols)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/logs');
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
                                'Logs',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/metrics');
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
                                'Metrics',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Full-width Button: Deployment
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/deployment-details');
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
                          'Deployment',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
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

  Widget _buildLogItem({
    required AppColorScheme colors,
    required String timestamp,
    required String level,
    required Color levelColor,
    required Color levelBg,
    required String prefix,
    required String? highlight,
    required String suffix,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.logBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: 12,
            color: colors.text,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$timestamp ',
              style: TextStyle(color: colors.muted),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: levelBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: levelColor,
                  ),
                ),
              ),
            ),
            TextSpan(text: prefix),
            if (highlight != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0xFF4A1D27) : const Color(0xFFFDE2E2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    highlight,
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.isDark ? const Color(0xFFFFB4B4) : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ),
            TextSpan(text: suffix),
          ],
        ),
      ),
    );
  }
}
