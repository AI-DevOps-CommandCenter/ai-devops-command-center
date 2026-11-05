import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 's05_incident_details_screen.dart';

class S04IncidentsScreen extends StatefulWidget {
  const S04IncidentsScreen({super.key});

  @override
  State<S04IncidentsScreen> createState() => _S04IncidentsScreenState();
}

class _S04IncidentsScreenState extends State<S04IncidentsScreen> {
  String _selectedTab = 'Active';
  String? _selectedChip;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _activeIncidents = const [
    {
      'id': 'INC-1042',
      'title': 'Elevated errors after deployment',
      'service': 'payments-api · Production',
      'severity': 'Critical',
      'status': 'Investigating',
    },
    {
      'id': 'INC-1041',
      'title': 'Queue backlog growing',
      'service': 'orders-worker · Production',
      'severity': 'Warning',
      'status': 'Monitoring',
    },
    {
      'id': 'INC-1040',
      'title': 'Slow image resizing',
      'service': 'media-service · Production',
      'severity': 'Warning',
      'status': 'Acknowledged',
    },
  ];

  final List<String> _chips = const ['Critical', 'Warning', 'payments-api', 'Investigating'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query = _searchController.text.toLowerCase();
    final filteredIncidents = _activeIncidents.where((i) {
      final matchesQuery = query.isEmpty ||
          i['id']!.toLowerCase().contains(query) ||
          i['title']!.toLowerCase().contains(query) ||
          i['service']!.toLowerCase().contains(query);

      final matchesChip = _selectedChip == null ||
          i['severity'] == _selectedChip ||
          i['status'] == _selectedChip ||
          i['service']!.contains(_selectedChip!);

      return matchesQuery && matchesChip;
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
                    child: Text(
                      'Incidents',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tabs: Active / History
                    Row(
                      children: [
                        _buildTabButton(colors, 'Active'),
                        const SizedBox(width: 8),
                        _buildTabButton(colors, 'History'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search input
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() {}),
                        style: TextStyle(fontSize: 14, color: colors.text),
                        decoration: InputDecoration(
                          hintText: 'Search incidents',
                          hintStyle: TextStyle(color: colors.muted, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filter chips row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _chips.map((chip) {
                          final isSelected = _selectedChip == chip;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedChip = isSelected ? null : chip;
                                });
                              },
                              borderRadius: BorderRadius.circular(99),
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? colors.teal : Colors.transparent,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: isSelected ? Colors.transparent : colors.border,
                                  ),
                                ),
                                child: Text(
                                  chip,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
                    const SizedBox(height: 14),

                    // Incident Cards List
                    if (filteredIncidents.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Text('∅', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: colors.muted)),
                            const SizedBox(height: 4),
                            Text('No results', style: TextStyle(fontWeight: FontWeight.bold, color: colors.text)),
                            const SizedBox(height: 2),
                            Text('No incidents match.', style: TextStyle(color: colors.muted, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ...filteredIncidents.map((i) {
                        final isCrit = i['severity'] == 'Critical';
                        final sevBg = isCrit ? colors.badgeRedBg : colors.badgeAmberBg;
                        final sevCol = isCrit ? colors.red : colors.amber;

                        Color stBg = colors.badgeAmberBg;
                        Color stCol = colors.amber;
                        if (i['status'] == 'Acknowledged') {
                          stBg = colors.badgeTealBg;
                          stCol = colors.teal;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => S05IncidentDetailsScreen(
                                    incidentId: i['id']!,
                                    incidentTitle: i['title']!,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: _buildCard(
                              colors: colors,
                              borderLeftColor: sevCol,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        i['id']!,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.text),
                                      ),
                                      _buildBadge(i['severity']!, sevBg, sevCol),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    i['title']!,
                                    style: TextStyle(fontSize: 13, color: colors.text),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        i['service']!,
                                        style: TextStyle(fontSize: 12, color: colors.muted),
                                      ),
                                      _buildBadge(i['status']!, stBg, stCol),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
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

  Widget _buildTabButton(AppColorScheme colors, String label) {
    final isSelected = _selectedTab == label;
    return InkWell(
      onTap: () {
        if (label == 'History') {
          Navigator.pushNamed(context, '/incident-history');
          return;
        }
        setState(() {
          _selectedTab = label;
        });
      },
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isSelected ? Colors.transparent : colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (colors.isDark ? const Color(0xFF06202A) : Colors.white)
                : colors.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required AppColorScheme colors, required Widget child, Color? borderLeftColor}) {
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
                  const SizedBox(width: 10),
                  Expanded(child: child),
                ],
              ),
            )
          : child,
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
