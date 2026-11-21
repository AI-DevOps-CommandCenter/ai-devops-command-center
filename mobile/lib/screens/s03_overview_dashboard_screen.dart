import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_icons.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/incident_model.dart';
import '../models/service_metrics_model.dart';
import '../widgets/metric_widgets.dart';
import 's17_recommended_action_screen.dart';
import 's05_incident_details_screen.dart';

class S03OverviewDashboardScreen extends StatefulWidget {
  const S03OverviewDashboardScreen({super.key});

  @override
  State<S03OverviewDashboardScreen> createState() => _S03OverviewDashboardScreenState();
}

class _S03OverviewDashboardScreenState extends State<S03OverviewDashboardScreen> {
  int _criticalCount = 0;
  int _openCount = 0;
  int _resolvedCount = 0;
  IncidentModel? _topIncident;
  String? _recommendedAction;
  bool _loadingIncidents = true;
  String? _incidentError;
  List<ServiceHealth> _services = [];
  ServiceMetrics? _metrics;
  String? _metricsError;
  int _unread = 0;

  static const _defaultService = 'sample-app';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final api = ApiService();
    String metricsService = _defaultService;

    try {
      final incidents = await api.fetchIncidents();
      final open = incidents.where((i) => i.status != IncidentStatus.resolved).toList()
        ..sort((a, b) {
          final bySeverity = a.severity.index.compareTo(b.severity.index);
          return bySeverity != 0 ? bySeverity : b.detectedAt.compareTo(a.detectedAt);
        });
      String? action;
      if (open.isNotEmpty) {
        metricsService = open.first.serviceName;
        try {
          final rec = await api.fetchRecommendation(open.first.id);
          action = (rec['analysis'] as Map?)?['recommended_action']?.toString();
        } catch (_) {
          action = null; // no analysis yet
        }
      }
      if (!mounted) return;
      setState(() {
        _topIncident = open.isEmpty ? null : open.first;
        _recommendedAction = action;
        _criticalCount = open.where((i) => i.severity == IncidentSeverity.critical).length;
        _openCount = open.length;
        _resolvedCount = incidents.length - open.length;
        _loadingIncidents = false;
        _incidentError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingIncidents = false;
        _incidentError = e is ApiException ? e.message : 'Could not load incidents.';
      });
    }

    try {
      final results = await Future.wait([
        api.fetchServiceHealth(),
        api.fetchServiceMetrics(metricsService),
      ]);
      if (!mounted) return;
      setState(() {
        _services = results[0] as List<ServiceHealth>;
        _metrics = results[1] as ServiceMetrics;
        _metricsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _metricsError = e is ApiException ? e.message : 'Metrics unavailable.');
    }

    try {
      final notes = await api.fetchNotifications(limit: 50);
      if (mounted) setState(() => _unread = notes.where((n) => !n.isRead).length);
    } catch (_) {
      // The bell just shows no dot.
    }
  }

  String _shortId(String id) => 'INC-${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';

  String _age(DateTime t) {
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 48) return '${d.inHours} h';
    return '${d.inDays} d';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s._@-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  }

  String _actionLabel(String a) => switch (a) {
        'restart' => 'restarting the service',
        'circuit_breaker' => 'opening the circuit breaker',
        'rollback' => 'rolling back the last deployment',
        'scale' => 'scaling the service',
        _ => a.replaceAll('_', ' '),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final userName = AuthService().currentUser?.name ?? 'Admin';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Overview + Bell (44x44) + Avatar (44x44)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const BrandLogo(size: 34),
                            const SizedBox(width: 10),
                            Text(
                              'Overview',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.52,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Production · ${_greeting()}, $userName',
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Notifications Bell button (44x44)
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/notifications');
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
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              LucideIcon(LucideIconData.bell, size: 20, color: colors.text),
                              if (_unread > 0)
                              Positioned(
                                top: 9,
                                right: 10,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colors.critical,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colors.card, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Profile AM button (44x44)
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/profile');
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(userName),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // 1. Most urgent open incident
                  _buildHeroCard(context),

                  const SizedBox(height: 14),

                  // 2. Incidents by severity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INCIDENTS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.52,
                          color: colors.muted,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/incidents');
                        },
                        child: Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 3-column severity cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSeverityCard(
                          context,
                          title: 'Critical',
                          dotColor: colors.critical,
                          count: '$_criticalCount',
                          sub: 'open, critical',
                          onTap: () {
                            Navigator.pushNamed(context, '/incidents');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSeverityCard(
                          context,
                          title: 'Open',
                          dotColor: colors.warning,
                          count: '$_openCount',
                          sub: 'open',
                          onTap: () {
                            Navigator.pushNamed(context, '/incidents');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSeverityCard(
                          context,
                          title: 'Resolved',
                          dotColor: colors.ok,
                          count: '$_resolvedCount',
                          sub: 'all time',
                          onTap: () {
                            Navigator.pushNamed(context, '/incidents');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 2. Service health
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SERVICE HEALTH',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.52,
                          color: colors.muted,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/services');
                        },
                        child: Text(
                          '${_services.length} services',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Service health bar card (Prometheus up + error rate)
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/services'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: ServiceHealthBar(services: _services),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Metrics of the incident's service (or sample-app) for the last hour
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(_metrics?.service ?? _topIncident?.serviceName ?? _defaultService).toUpperCase()} · LAST HOUR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.52,
                          color: colors.muted,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/metrics', arguments: _metrics?.service),
                        child: Text(
                          'Metrics',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.accent),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (_metrics != null)
                    ServiceMetricsGrid(
                      metrics: _metrics!,
                      onTap: () => Navigator.pushNamed(context, '/metrics', arguments: _metrics!.service),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: _metricsError == null
                          ? const Center(child: CircularProgressIndicator())
                          : Text(_metricsError!, style: TextStyle(fontSize: 13, color: colors.muted)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _badge(String text, Color fg, Color bg, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ]),
      );

  Widget _buildHeroCard(BuildContext context) {
    final colors = context.colors;
    final decoration = BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: colors.border),
    );
    if (_loadingIncidents) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: decoration,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_incidentError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Row(children: [
          Icon(Icons.cloud_off, color: colors.critical),
          const SizedBox(width: 10),
          Expanded(child: Text(_incidentError!, style: TextStyle(color: colors.text))),
          TextButton(onPressed: _loadDashboardData, child: const Text('Retry')),
        ]),
      );
    }
    final inc = _topIncident;
    if (inc == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Row(children: [
          Icon(Icons.verified_outlined, color: colors.ok, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('All clear', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.text)),
              const SizedBox(height: 2),
              Text('No open incidents right now.', style: TextStyle(fontSize: 14, color: colors.muted)),
            ]),
          ),
        ]),
      );
    }

    final (Color sevFg, Color sevBg) = switch (inc.severity) {
      IncidentSeverity.critical => (colors.critical, colors.criticalSoft),
      IncidentSeverity.high => (colors.warning, colors.warningSoft),
      _ => (colors.info, colors.accentSoft),
    };
    final statusText = switch (inc.status) {
      IncidentStatus.investigating => _recommendedAction == null ? 'Investigating' : 'Action recommended',
      IncidentStatus.remediating => 'Remediating',
      _ => 'Open',
    };
    final sevName = inc.severity.name[0].toUpperCase() + inc.severity.name.substring(1);

    void open(Widget screen) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen, settings: RouteSettings(arguments: inc.id)),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge(sevName, sevFg, sevBg, icon: Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            _badge(statusText, colors.warning, colors.warningSoft),
            const Spacer(),
            Text(_age(inc.detectedAt), style: TextStyle(fontSize: 13, color: colors.muted)),
          ]),
          const SizedBox(height: 12),
          Text('${_shortId(inc.id)} · ${inc.serviceName}',
              style: TextStyle(fontSize: 13, fontFamily: 'JetBrains Mono', color: colors.muted)),
          const SizedBox(height: 2),
          Text(inc.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.text)),
          const SizedBox(height: 8),
          if (_recommendedAction != null)
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: colors.muted),
                children: [
                  const TextSpan(text: 'AI found a probable cause and recommends '),
                  TextSpan(
                    text: _actionLabel(_recommendedAction!),
                    style: TextStyle(fontWeight: FontWeight.w700, color: colors.text),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            )
          else
            Text('The AI investigation is still running.', style: TextStyle(fontSize: 14, color: colors.muted)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => open(S05IncidentDetailsScreen(incidentId: inc.id)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.card,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.text)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _recommendedAction == null ? null : () => open(S17RecommendedActionScreen(incidentId: inc.id)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Review action', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSeverityCard(
    BuildContext context, {
    required String title,
    required Color dotColor,
    required String count,
    required String sub,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dotColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            Text(
              sub,
              style: TextStyle(fontSize: 12, color: colors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
