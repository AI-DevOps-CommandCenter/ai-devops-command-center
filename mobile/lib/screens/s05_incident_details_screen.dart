import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 's06_ai_investigation_progress_screen.dart';

class S05IncidentDetailsScreen extends StatelessWidget {
  final String incidentId;
  final String incidentTitle;

  const S05IncidentDetailsScreen({
    super.key,
    this.incidentId = 'INC-1042',
    this.incidentTitle = 'Elevated errors after deployment',
  });

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
                          incidentId,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          incidentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

            // Main Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Context Card with Red Left Border (.card.cr)
                    _buildCard(
                      colors: colors,
                      borderLeftColor: colors.red,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildBadge('Critical', colors.badgeRedBg, colors.red),
                              _buildBadge('Investigating', colors.badgeAmberBg, colors.amber),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildRow(colors, 'Service', 'payments-api'),
                          Divider(color: colors.cardBorder, height: 16),
                          _buildRow(colors, 'Environment', 'Production'),
                          Divider(color: colors.cardBorder, height: 16),
                          _buildRow(colors, 'Detected', '14:12 UTC'),
                          Divider(color: colors.cardBorder, height: 16),
                          _buildRow(colors, 'Impact', 'Error rate 0.3% → 12.4%; P95 180 ms → 2.4 s'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Timeline Heading
                    Text(
                      'Timeline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Timeline items
                    Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: Column(
                        children: [
                          _buildTimelineItem(
                            colors: colors,
                            time: '14:05',
                            title: 'v2.8.1 deployed',
                            subtitle: 'Pipeline #318 passed',
                            isCompleted: true,
                          ),
                          _buildTimelineItem(
                            colors: colors,
                            time: '14:07',
                            title: 'DB connection timeouts begin',
                            isCompleted: true,
                          ),
                          _buildTimelineItem(
                            colors: colors,
                            time: '14:12',
                            title: 'Alert fired: error rate above 5%',
                            isCompleted: true,
                          ),
                          _buildTimelineItem(
                            colors: colors,
                            time: 'Next',
                            title: 'AI investigation',
                            isPending: true,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Start AI Investigation Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const S06AiInvestigationProgressScreen(),
                            ),
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
                          'Start AI Investigation',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Persistent Bottom Navigation Bar
            const AppBottomNav(currentRoute: 's04'),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required AppColorScheme colors,
    required Widget child,
    Color? borderLeftColor,
  }) {
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
      child: borderLeftColor != null
          ? IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: borderLeftColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: child),
                ],
              ),
            )
          : child,
    );
  }

  Widget _buildRow(AppColorScheme colors, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.muted),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required AppColorScheme colors,
    required String time,
    required String title,
    String? subtitle,
    bool isCompleted = false,
    bool isPending = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator line & circle
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isPending ? colors.border : colors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$time ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colors.text,
                          ),
                        ),
                        TextSpan(
                          text: title,
                          style: TextStyle(
                            fontSize: 13,
                            color: isPending ? colors.muted : colors.text,
                            fontWeight: isPending ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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
