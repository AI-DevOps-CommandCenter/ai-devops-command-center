import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S22IncidentHistoryScreen extends StatefulWidget {
  const S22IncidentHistoryScreen({super.key});

  @override
  State<S22IncidentHistoryScreen> createState() => _S22IncidentHistoryScreenState();
}

class _S22IncidentHistoryScreenState extends State<S22IncidentHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedChip = '';

  final List<Map<String, dynamic>> _resolvedIncidents = [
    {
      'id': 'INC-1042',
      'title': 'Elevated errors after deployment',
      'badge': 'Postmortem',
      'badgeBg': AppColors.badgeTealBg,
      'badgeColor': AppColors.teal,
      'service': 'payments-api · Production',
    },
    {
      'id': 'INC-1037',
      'title': 'Cache hit ratio dropped',
      'badge': 'Resolved',
      'badgeBg': AppColors.badgeGreenBg,
      'badgeColor': AppColors.green,
      'service': 'catalog-api · Production',
    },
    {
      'id': 'INC-1033',
      'title': 'TLS cert nearing expiry',
      'badge': 'Resolved',
      'badgeBg': AppColors.badgeGreenBg,
      'badgeColor': AppColors.green,
      'service': 'edge-gateway · Production',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final filtered = _resolvedIncidents.where((i) {
      final matchesQuery = query.isEmpty ||
          i['id']!.toLowerCase().contains(query) ||
          i['title']!.toLowerCase().contains(query) ||
          i['service']!.toLowerCase().contains(query);

      final matchesChip = _selectedChip.isEmpty ||
          (_selectedChip == 'Resolved' && i['badge'] == 'Resolved') ||
          i['service']!.toLowerCase().contains(_selectedChip.toLowerCase());

      return matchesQuery && matchesChip;
    }).toList();

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
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
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
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.muted, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                hintText: 'Search resolved',
                                hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(color: AppColors.text, fontSize: 14),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              child: const Icon(Icons.clear, color: AppColors.muted, size: 18),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filter Chips (Resolved, payments-api, catalog-api)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Resolved', 'payments-api', 'catalog-api'].map((chip) {
                          final isSelected = _selectedChip == chip;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedChip = isSelected ? '' : chip;
                                });
                              },
                              borderRadius: BorderRadius.circular(99),
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.teal : Colors.transparent,
                                  borderRadius: BorderRadius.circular(99),
                                  border: isSelected ? null : Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  chip,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : AppColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Resolved Incidents List
                    if (filtered.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder, width: 0.8),
                        ),
                        child: Column(
                          children: const [
                            Text('∅', style: TextStyle(fontSize: 32, color: AppColors.muted)),
                            SizedBox(height: 6),
                            Text('No resolved incidents.', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
                            SizedBox(height: 4),
                            Text('Try clearing the search or filter.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ...filtered.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(context, '/postmortem');
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.cardBorder, width: 0.8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(15, 27, 51, 0.06),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item['id']!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: item['badgeBg'] as Color,
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                        child: Text(
                                          item['badge']!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: item['badgeColor'] as Color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['title']!,
                                    style: const TextStyle(fontSize: 13, color: AppColors.text),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['service']!,
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 's04'),
    );
  }
}
