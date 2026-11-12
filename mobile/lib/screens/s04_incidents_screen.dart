import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';
import 's05_incident_details_screen.dart';
import 's30_search_screen.dart';
import 's32_inc_1041_screen.dart';
import 's33_inc_1040_screen.dart';
import 's34_pm_1037_screen.dart';
import 's35_pm_1033_screen.dart';
import 's36_pm_1029_screen.dart';

class S04IncidentsScreen extends StatefulWidget {
  const S04IncidentsScreen({super.key});

  @override
  State<S04IncidentsScreen> createState() => _S04IncidentsScreenState();
}

class _S04IncidentsScreenState extends State<S04IncidentsScreen> {
  String _currentTab = 'active'; // 'active' or 'history'
  String _selectedSev = 'All'; // 'All', 'Critical', 'Warning'

  final List<Map<String, dynamic>> _allIncidents = [
    {
      'id': 'INC-1042',
      'title': 'Elevated errors after deployment',
      'svc': 'payments-api',
      'sev': 'Critical',
      'status': 'Awaiting approval',
      'time': '19 min ago',
      'active': true,
      'isCritical': true,
      'isWarning': false,
    },
    {
      'id': 'INC-1041',
      'title': 'Queue backlog growing',
      'svc': 'orders-worker',
      'sev': 'Warning',
      'status': 'Monitoring',
      'time': '41 min ago',
      'active': true,
      'isCritical': false,
      'isWarning': true,
    },
    {
      'id': 'INC-1040',
      'title': 'Slow image resizing',
      'svc': 'media-service',
      'sev': 'Warning',
      'status': 'Acknowledged',
      'time': '1 h ago',
      'active': true,
      'isCritical': false,
      'isWarning': true,
    },
    {
      'id': 'INC-1037',
      'title': 'Cache hit ratio dropped',
      'svc': 'catalog-api',
      'sev': 'Warning',
      'status': 'Resolved',
      'time': 'Yesterday',
      'active': false,
      'isCritical': false,
      'isWarning': true,
    },
    {
      'id': 'INC-1033',
      'title': 'TLS certificate nearing expiry',
      'svc': 'edge-gateway',
      'sev': 'Warning',
      'status': 'Resolved',
      'time': '3 days ago',
      'active': false,
      'isCritical': false,
      'isWarning': true,
    },
    {
      'id': 'INC-1029',
      'title': 'Deploy failed health checks',
      'svc': 'auth-service',
      'sev': 'Critical',
      'status': 'Resolved',
      'time': '6 days ago',
      'active': false,
      'isCritical': true,
      'isWarning': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final filteredList = _allIncidents.where((i) {
      final tabMatch = (i['active'] as bool) == (_currentTab == 'active');
      final sevMatch = _selectedSev == 'All' || i['sev'] == _selectedSev;
      return tabMatch && sevMatch;
    }).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Incidents',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.52,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '3 active · 1 critical',
                        style: TextStyle(fontSize: 13, color: colors.muted),
                      ),
                    ],
                  ),
                  // Search button
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const S30SearchScreen(),
                        ),
                      );
                    },
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
                      child: LucideIcon(LucideIconData.search, size: 20, color: colors.text),
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
                  // Tablist Switcher (Active / History)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _currentTab = 'active'),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _currentTab == 'active' ? colors.card : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _currentTab == 'active'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _currentTab == 'active' ? colors.text : colors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _currentTab = 'history'),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _currentTab == 'history' ? colors.card : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _currentTab == 'history'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'History',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _currentTab == 'history' ? colors.text : colors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips (All, Critical, Warning)
                  Row(
                    children: ['All', 'Critical', 'Warning'].map((sev) {
                      final isSelected = _selectedSev == sev;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () => setState(() => _selectedSev = sev),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? colors.accent : colors.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isSelected ? colors.accent : colors.border,
                              ),
                            ),
                            child: Text(
                              sev,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? colors.onAccent : colors.text,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Incidents List
                  if (filteredList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Text(
                          'No incidents match this filter.',
                          style: TextStyle(fontSize: 14, color: colors.muted),
                        ),
                      ),
                    )
                  else
                    ...filteredList.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: _buildExactIncidentCard(context, item),
                      );
                    }),
                ],
              ),
            ),

            const AppBottomNav(currentRoute: 'incidents'),
          ],
        ),
      ),
    );
  }

  Widget _buildExactIncidentCard(BuildContext context, Map<String, dynamic> item) {
    final colors = context.colors;
    final isCritical = item['isCritical'] as bool;
    final id = item['id'] as String;

    Color barColor = isCritical ? colors.critical : colors.warning;
    Color sevBg = isCritical ? colors.badgeRedBg : colors.badgeAmberBg;
    Color sevFg = isCritical ? colors.critical : colors.warning;

    Color stBg = colors.surface2;
    Color stFg = colors.muted;

    final status = item['status'] as String;
    if (status == 'Awaiting approval') {
      stBg = colors.badgeAmberBg;
      stFg = colors.warning;
    } else if (status == 'Monitoring' || status == 'Acknowledged') {
      stBg = colors.info.withValues(alpha: 0.14);
      stFg = colors.info;
    } else if (status == 'Resolved') {
      stBg = colors.badgeGreenBg;
      stFg = colors.success;
    }

    return InkWell(
      onTap: () {
        if (id == 'INC-1042') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const S05IncidentDetailsScreen(),
            ),
          );
        } else if (id == 'INC-1041') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const S32Inc1041Screen(),
            ),
          );
        } else if (id == 'INC-1040') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const S33Inc1040Screen(),
            ),
          );
        } else if (id == 'INC-1037') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const S34Pm1037Screen(),
            ),
          );
        } else if (id == 'INC-1033') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const S35Pm1033Screen(),
            ),
          );
        } else if (id == 'INC-1029') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const S36Pm1029Screen(),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left color bar
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        id,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: sevBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item['sev'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sevFg,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item['time'] as String,
                        style: TextStyle(fontSize: 12, color: colors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item['svc']} · Production',
                        style: TextStyle(fontSize: 13, color: colors.muted),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: stBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: stFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
