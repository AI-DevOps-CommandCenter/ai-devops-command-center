import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_back_button.dart';
import '../services/api_service.dart';
import 's08_evidence_details_screen.dart';
import 's17_recommended_action_screen.dart';

class S07RootCauseScreen extends StatefulWidget {
  final String? incidentId;

  const S07RootCauseScreen({super.key, this.incidentId});

  @override
  State<S07RootCauseScreen> createState() => _S07RootCauseScreenState();
}

class _S07RootCauseScreenState extends State<S07RootCauseScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _investigations = [];
  String? _resolvedIncidentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedIncidentId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _resolvedIncidentId = args;
      } else if (widget.incidentId != null && widget.incidentId!.isNotEmpty) {
        _resolvedIncidentId = widget.incidentId;
      }
      _loadInvestigations();
    }
  }

  Future<void> _loadInvestigations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final id = _resolvedIncidentId;
    if (id == null || id.isEmpty) {
      try {
        final incidents = await ApiService().fetchIncidents();
        if (incidents.isNotEmpty && mounted) {
          _resolvedIncidentId = incidents.first.id;
        }
      } catch (_) {}
    }

    if (_resolvedIncidentId == null || _resolvedIncidentId!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Incident ID is required to fetch investigations.';
        });
      }
      return;
    }

    try {
      final list = await ApiService().fetchInvestigations(_resolvedIncidentId!);
      if (mounted) {
        setState(() {
          _investigations = list;
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inv = _investigations.isNotEmpty ? _investigations.first : null;

    final shortId = _resolvedIncidentId != null && _resolvedIncidentId!.length > 8
        ? 'INC-${_resolvedIncidentId!.substring(0, 8).toUpperCase()}'
        : (_resolvedIncidentId ?? 'INC-INVESTIGATION');

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Root cause',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          shortId,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _buildBody(colors, inv),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme colors, Map<String, dynamic>? inv) {
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
                'Failed to load investigations',
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
                onPressed: _loadInvestigations,
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

    final rootCause = inv?['root_cause']?.toString() ?? 'No probable cause has been stored yet.';
    final summary = inv?['summary']?.toString() ?? 'The AI investigation has not finished for this incident.';
    final aiModel = inv?['ai_model']?.toString() ?? '—';
    final evidence = (inv?['evidence'] is List) ? (inv!['evidence'] as List) : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Probable Cause Card
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI ROOT CAUSE ANALYSIS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.52,
                        color: colors.muted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.badgeAmberBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        aiModel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  rootCause,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Evidence Section
          Text(
            'INVESTIGATION EVIDENCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.52,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 8),

          if (evidence.isNotEmpty)
            ...evidence.map((item) {
              final text = item is Map ? (item['description'] ?? item['title'] ?? item.toString()) : item.toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: colors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text.toString(),
                          style: TextStyle(fontSize: 13, color: colors.text),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                'No evidence has been stored for this incident yet.',
                style: TextStyle(fontSize: 13, color: colors.text, height: 1.4),
              ),
            ),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => S08EvidenceDetailsScreen(incidentId: _resolvedIncidentId),
                  settings: RouteSettings(arguments: _resolvedIncidentId),
                ),
              ),
              child: const Text('View all evidence'),
            ),
          ),

          const SizedBox(height: 12),

          // Primary Button: Proceed to Approve
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => S17RecommendedActionScreen(incidentId: _resolvedIncidentId),
                    settings: RouteSettings(arguments: _resolvedIncidentId),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Review recommended action',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
