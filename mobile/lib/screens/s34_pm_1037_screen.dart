import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class S34Pm1037Screen extends StatelessWidget {
  const S34Pm1037Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Postmortem · INC-1037 · catalog-api
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.chevron_left, size: 20, color: colors.text),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Postmortem',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'INC-1037 · catalog-api',
                          style: TextStyle(
                            fontSize: 13,
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Badges: Resolved · catalog-api
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.ok.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 13, color: colors.ok),
                            const SizedBox(width: 4),
                            Text(
                              'Resolved',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.ok,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.cardSecondary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'catalog-api',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.muted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Cache hit ratio dropped',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Summary Card
                  _buildSectionCard(
                    title: 'Summary',
                    body:
                        'Cache hit ratio fell after a Redis node restarted. Restarting catalog-api re-warmed the cache.',
                    colors: colors,
                  ),

                  const SizedBox(height: 14),

                  // 3-col Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile('Impact', '34 min', colors),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile('Hit ratio', '41%', colors),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile('Time to fix', '12 min', colors),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Timeline Card
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
                        Text(
                          'Timeline',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.52,
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildTimelineEvent('16:28', 'Redis node restarted',
                            'AWS maintenance', colors.info, false, colors),
                        _buildTimelineEvent('16:31', 'Alert: hit ratio below 70%',
                            'Prometheus', colors.warning, false, colors),
                        _buildTimelineEvent('16:40', 'Restart approved',
                            'Alex Morgan', colors.warning, false, colors),
                        _buildTimelineEvent('17:02', 'Recovery verified',
                            'Hit ratio 93%', colors.ok, true, colors),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  _buildSectionCard(
                    title: 'Root cause',
                    body:
                        'Cold cache after Redis restart; catalog-api kept stale connections.',
                    colors: colors,
                  ),

                  const SizedBox(height: 14),

                  _buildSectionCard(
                    title: 'Evidence',
                    body:
                        'Loki: 1,140 “cache miss” lines · Prometheus: hit ratio 94% → 41%',
                    colors: colors,
                  ),

                  const SizedBox(height: 14),

                  _buildSectionCard(
                    title: 'Action and result',
                    body: 'Restart service playbook. Hit ratio back to 93%.',
                    colors: colors,
                  ),

                  const SizedBox(height: 14),

                  _buildSectionCard(
                    title: 'Follow-ups',
                    body: '• Reconnect to Redis automatically',
                    colors: colors,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String body,
    required dynamic colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.52,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, dynamic colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEvent(String time, String title, String sub,
      Color dotColor, bool isLast, dynamic colors) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colors.border,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 14, color: colors.text),
                      children: [
                        TextSpan(
                          text: '$time  ',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
                            color: colors.muted,
                          ),
                        ),
                        TextSpan(
                          text: title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(fontSize: 13, color: colors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
