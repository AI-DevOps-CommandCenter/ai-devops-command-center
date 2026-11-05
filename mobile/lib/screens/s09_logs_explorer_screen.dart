import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class S09LogsExplorerScreen extends StatefulWidget {
  const S09LogsExplorerScreen({super.key});

  @override
  State<S09LogsExplorerScreen> createState() => _S09LogsExplorerScreenState();
}

class _S09LogsExplorerScreenState extends State<S09LogsExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = '';

  final List<Map<String, dynamic>> _rawLogs = const [
    {
      'time': '14:07:11',
      'level': 'ERROR',
      'prefix': '',
      'highlight': 'connection timeout',
      'suffix': ' after 500ms (db-primary)',
    },
    {
      'time': '14:07:14',
      'level': 'WARN',
      'prefix': 'pool exhausted 20/20',
      'highlight': null,
      'suffix': '',
    },
    {
      'time': '14:06:58',
      'level': 'INFO',
      'prefix': 'request POST /charge 200 190ms',
      'highlight': null,
      'suffix': '',
    },
    {
      'time': '14:05:30',
      'level': 'INFO',
      'prefix': 'service started v2.8.1',
      'highlight': null,
      'suffix': '',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query = _searchController.text.toLowerCase();
    final filteredLogs = _rawLogs.where((log) {
      final level = log['level'] as String;
      final fullText = '${log['time']} $level ${log['prefix']} ${log['highlight'] ?? ''} ${log['suffix']}'.toLowerCase();

      final matchesQuery = query.isEmpty || fullText.contains(query);
      final matchesFilter = _selectedFilter.isEmpty ||
          _selectedFilter == 'Last 1h' ||
          level == _selectedFilter;

      return matchesQuery && matchesFilter;
    }).toList();

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
                          'Logs',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'payments-api',
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
                    // Search bar
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: colors.muted, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search logs',
                                hintStyle: TextStyle(color: colors.muted, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: TextStyle(color: colors.text, fontSize: 14),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              child: Icon(Icons.clear, color: colors.muted, size: 18),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filter Chips (ERROR, WARN, INFO, Last 1h)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['ERROR', 'WARN', 'INFO', 'Last 1h'].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedFilter = isSelected ? '' : filter;
                                });
                              },
                              borderRadius: BorderRadius.circular(99),
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? colors.teal : Colors.transparent,
                                  borderRadius: BorderRadius.circular(99),
                                  border: isSelected ? null : Border.all(color: colors.border),
                                ),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? (colors.isDark ? const Color(0xFF06202A) : Colors.white)
                                        : colors.muted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Log items or Empty state
                    if (filteredLogs.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.cardBorder, width: 0.8),
                        ),
                        child: Column(
                          children: [
                            Text('∅', style: TextStyle(fontSize: 32, color: colors.muted)),
                            const SizedBox(height: 6),
                            Text('No logs for this filter.', style: TextStyle(fontWeight: FontWeight.bold, color: colors.text)),
                            const SizedBox(height: 4),
                            Text('Try clearing the search or filter.', style: TextStyle(color: colors.muted, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ...filteredLogs.map((log) {
                        final level = log['level'] as String;
                        Color levColor = colors.muted;
                        Color levBg = colors.isDark ? const Color(0xFF26335C) : const Color(0xFFE1E8F4);
                        if (level == 'ERROR') {
                          levColor = colors.red;
                          levBg = colors.badgeRedBg;
                        } else if (level == 'WARN') {
                          levColor = colors.amber;
                          levBg = colors.badgeAmberBg;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildLogItem(
                            colors: colors,
                            timestamp: log['time'] as String,
                            level: level,
                            levelColor: levColor,
                            levelBg: levBg,
                            prefix: log['prefix'] as String,
                            highlight: log['highlight'] as String?,
                            suffix: log['suffix'] as String,
                          ),
                        );
                      }),

                    const SizedBox(height: 20),

                    // Explain error pattern Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/assistant', arguments: 'logs');
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
                          'Explain error pattern',
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
