import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 's23_developer_assistant_screen.dart';

class S09LogsExplorerScreen extends StatefulWidget {
  const S09LogsExplorerScreen({super.key});

  @override
  State<S09LogsExplorerScreen> createState() => _S09LogsExplorerScreenState();
}

class _S09LogsExplorerScreenState extends State<S09LogsExplorerScreen> {
  final TextEditingController _searchController =
      TextEditingController(text: 'connection timeout');
  String _selectedLevel = 'All';

  final List<Map<String, dynamic>> _allLogs = const [
    {
      't': '14:07:11.402',
      'lvl': 'ERROR',
      'msg': 'connection timeout after 500ms (db-primary)',
      'hit': true,
    },
    {
      't': '14:07:14.119',
      'lvl': 'WARN',
      'msg': 'pool exhausted 20/20, waiting for free connection',
      'hit': false,
    },
    {
      't': '14:07:15.880',
      'lvl': 'ERROR',
      'msg': 'POST /charge 500 · connection timeout',
      'hit': true,
    },
    {
      't': '14:06:58.824',
      'lvl': 'INFO',
      'msg': 'POST /charge 200 · 190ms',
      'hit': false,
    },
    {
      't': '14:05:30.012',
      'lvl': 'INFO',
      'msg': 'service started v2.8.1 on :8080',
      'hit': false,
    },
    {
      't': '14:05:28.980',
      'lvl': 'INFO',
      'msg': 'loaded config DB_POOL_TIMEOUT=500',
      'hit': true,
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
    final filteredLogs = _allLogs.where((r) {
      if (_selectedLevel == 'All') return true;
      return r['lvl'] == _selectedLevel;
    }).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Monitor · payments-api · last hour · Loki · Live
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monitor',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.52,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'payments-api · last hour · Loki',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.ok.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.ok,
                        height: 1.5,
                      ),
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
                  // Sub-nav tabs: Services, Logs (active), Metrics
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.cardSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/services');
                            },
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              child: Text(
                                'Services',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.18),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              'Logs',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/metrics');
                            },
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              child: Text(
                                'Metrics',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Search bar
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: colors.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 14,
                              color: colors.text,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search logs',
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Level filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildLevelChip(context, 'All', '3.8k'),
                        const SizedBox(width: 6),
                        _buildLevelChip(context, 'ERROR', '214'),
                        const SizedBox(width: 6),
                        _buildLevelChip(context, 'WARN', '88'),
                        const SizedBox(width: 6),
                        _buildLevelChip(context, 'INFO', '3.5k'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Log rows list
                  ...filteredLogs.map((r) => _buildLogRow(context, r)),

                  const SizedBox(height: 6),

                  // Pattern found card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.bolt, color: colors.warning, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.text,
                                    height: 1.45,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'Pattern found: ',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(
                                      text:
                                          '“connection timeout” ×212 since 14:07, all after 500 ms.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const S23DeveloperAssistantScreen(),
                                ),
                              );
                            },
                            icon: Icon(Icons.auto_awesome, size: 18, color: colors.text),
                            label: Text(
                              'Explain with AI',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.card,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: colors.border),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Nav
            const AppBottomNav(currentIndex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelChip(BuildContext context, String level, String count) {
    final colors = context.colors;
    final isSelected = _selectedLevel == level;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLevel = level;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$level $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? colors.onAccent : colors.text,
          ),
        ),
      ),
    );
  }

  Widget _buildLogRow(BuildContext context, Map<String, dynamic> r) {
    final colors = context.colors;
    final lvl = r['lvl'] as String;
    final hit = r['hit'] as bool;

    Color fg;
    Color bg;
    if (lvl == 'ERROR') {
      fg = colors.critical;
      bg = colors.critical.withOpacity(0.14);
    } else if (lvl == 'WARN') {
      fg = colors.warning;
      bg = colors.warning.withOpacity(0.14);
    } else {
      fg = colors.info;
      bg = colors.info.withOpacity(0.14);
    }

    final edge = hit ? colors.warning : colors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  lvl,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                r['t'] as String,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: colors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r['msg'] as String,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              height: 1.5,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}
