import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';
import '../services/api_service.dart';
import '../models/incident_model.dart';
import 's05_incident_details_screen.dart';
import 's30_search_screen.dart';

class S04IncidentsScreen extends StatefulWidget {
  const S04IncidentsScreen({super.key});

  @override
  State<S04IncidentsScreen> createState() => _S04IncidentsScreenState();
}

class _S04IncidentsScreenState extends State<S04IncidentsScreen> {
  String _currentTab = 'active'; // 'active' or 'history'
  String _selectedSev = 'All'; // 'All', 'Critical', 'Warning'
  bool _isLoading = true;
  String? _errorMessage;
  List<IncidentModel> _incidents = [];

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService().fetchIncidents();
      if (mounted) {
        setState(() {
          _incidents = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  int get _activeCount =>
      _incidents.where((i) => i.status != IncidentStatus.resolved).length;
  int get _criticalCount => _incidents
      .where((i) =>
          i.status != IncidentStatus.resolved &&
          i.severity == IncidentSeverity.critical)
      .length;

  List<IncidentModel> get _filteredList {
    return _incidents.where((item) {
      final isResolved = item.status == IncidentStatus.resolved;
      final tabMatch =
          _currentTab == 'active' ? !isResolved : isResolved;

      final sevMatch = _selectedSev == 'All' ||
          (_selectedSev == 'Critical' &&
              item.severity == IncidentSeverity.critical) ||
          (_selectedSev == 'Warning' &&
              (item.severity == IncidentSeverity.high ||
                  item.severity == IncidentSeverity.medium));

      return tabMatch && sevMatch;
    }).toList();
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filtered = _filteredList;

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
                        '$_activeCount active · $_criticalCount critical',
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
                      child: Center(
                        child: LucideIcon(
                          LucideIconData.search,
                          size: 20,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Segmented Tabs: Active vs History
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
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
                                color: _currentTab == 'active'
                                    ? colors.card
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _currentTab == 'active'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Active ($_activeCount)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _currentTab == 'active'
                                      ? colors.text
                                      : colors.muted,
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
                                color: _currentTab == 'history'
                                    ? colors.card
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _currentTab == 'history'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
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
                                  color: _currentTab == 'history'
                                      ? colors.text
                                      : colors.muted,
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
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? colors.onAccent
                                    : colors.text,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // List Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadIncidents,
                color: colors.accent,
                child: _buildBody(colors, filtered),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: 'incidents'),
    );
  }

  Widget _buildBody(AppColorScheme colors, List<IncidentModel> list) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.red),
              const SizedBox(height: 12),
              Text(
                'Failed to load incidents',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadIncidents,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: colors.ok),
            const SizedBox(height: 12),
            Text(
              _currentTab == 'active'
                  ? 'All clear! No active incidents'
                  : 'No incident history found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pull down to refresh',
              style: TextStyle(fontSize: 13, color: colors.muted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final incident = list[index];
        return _buildIncidentCard(context, incident, colors);
      },
    );
  }

  Widget _buildIncidentCard(
      BuildContext context, IncidentModel incident, AppColorScheme colors) {
    final isCritical = incident.severity == IncidentSeverity.critical;
    final barColor = isCritical ? colors.critical : colors.warning;
    final sevBg = isCritical ? colors.badgeRedBg : colors.badgeAmberBg;
    final sevFg = isCritical ? colors.critical : colors.warning;

    final shortId = incident.id.length > 8
        ? (incident.id.startsWith('INC-')
            ? incident.id
            : 'INC-${incident.id.substring(0, 8).toUpperCase()}')
        : (incident.id.isNotEmpty ? incident.id : 'INC-LIVE');

    final statusLabel = incident.status == IncidentStatus.open
        ? 'Open'
        : incident.status == IncidentStatus.investigating
            ? 'Investigating'
            : incident.status == IncidentStatus.remediating
                ? 'Mitigating'
                : 'Resolved';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          // Dynamic navigation using real selected incident ID
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  S05IncidentDetailsScreen(incidentId: incident.id),
              settings: RouteSettings(arguments: incident.id),
            ),
          );
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
              // Left severity color bar
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
                          shortId,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'JetBrains Mono',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: sevBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            incident.severity.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sevFg,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(incident.detectedAt),
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      incident.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${incident.serviceName} · Production',
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.surface2,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.muted,
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
      ),
    );
  }
}
