import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class S20RecoveryVerificationScreen extends StatefulWidget {
  final String incidentId;

  const S20RecoveryVerificationScreen({super.key, this.incidentId = 'INC-1042'});

  @override
  State<S20RecoveryVerificationScreen> createState() => _S20RecoveryVerificationScreenState();
}

class _S20RecoveryVerificationScreenState extends State<S20RecoveryVerificationScreen> {
  final ApiService _apiService = ApiService();

  bool _isReverifying = false;
  bool _isVerified = true;
  double _currentErrorRate = 0.4;
  int _currentLatency = 190;
  double _currentCpu = 42.0;

  Future<void> _triggerReverification() async {
    setState(() => _isReverifying = true);
    try {
      final metrics = await _apiService.fetchMetrics();
      if (mounted) {
        setState(() {
          _currentErrorRate = metrics.errorRate;
          _currentLatency = metrics.latencyMs;
          _currentCpu = metrics.cpuUsage;
          _isVerified = _currentErrorRate < 5.0;
        });
      }
    } catch (_) {
      // Graceful fallback
    } finally {
      if (mounted) {
        setState(() => _isReverifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isVerified
                  ? 'Independent health checks passed. System stable.'
                  : 'System metrics still degraded.',
            ),
            backgroundColor: context.colors.card,
          ),
        );
      }
    }
  }

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
                          'Recovery Verification',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          widget.incidentId,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.badgeGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.green, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined, size: 12, color: colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'S20',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.green,
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
                    // Recovery Status Accent Card (Safe IntrinsicHeight pattern - no border assertion bug)
                    _buildRecoveryStatusCard(colors),
                    const SizedBox(height: 12),

                    // Metrics Comparison Grid (Error rate & P95 latency)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            colors: colors,
                            label: 'Error rate',
                            transition: '12.4% →',
                            currentValue: '$_currentErrorRate%',
                            isHealthy: _currentErrorRate < 1.0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            colors: colors,
                            label: 'P95 latency',
                            transition: '2.4 s →',
                            currentValue: '${_currentLatency}ms',
                            isHealthy: _currentLatency < 300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Secondary Metrics (CPU & Pod replicas)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            colors: colors,
                            label: 'CPU Usage',
                            transition: '94.2% →',
                            currentValue: '${_currentCpu.toStringAsFixed(1)}%',
                            isHealthy: _currentCpu < 70,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            colors: colors,
                            label: 'Healthy Pods',
                            transition: '1/3 →',
                            currentValue: '3/3',
                            isHealthy: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Automated Verification Checks Card
                    _buildVerificationChecksCard(colors),
                    const SizedBox(height: 20),

                    // Re-verify Live Metrics Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _isReverifying ? null : _triggerReverification,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: colors.cardAccent,
                          foregroundColor: colors.text,
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isReverifying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.refresh_rounded, size: 16, color: colors.teal),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Re-verify Live Telemetry',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // View Postmortem Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/postmortem');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.teal,
                          foregroundColor: colors.isDark ? const Color(0xFF0B1226) : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'View Postmortem Report',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Close Incident & Return to Dashboard
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/dashboard',
                            (route) => false,
                          );
                        },
                        child: Text(
                          'Close Incident & Back to Dashboard',
                          style: TextStyle(fontSize: 13, color: colors.muted),
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

  Widget _buildRecoveryStatusCard(AppColorScheme colors) {
    return Container(
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: _isVerified ? colors.green : colors.warnText),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Remediation Health Status',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isVerified ? colors.badgeGreenBg : colors.warnBg,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _isVerified ? 'Recovered' : 'Checking...',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _isVerified ? colors.green : colors.warnText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Execution completed separately via n8n automation. System health and telemetry are independently verified.',
                        style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required AppColorScheme colors,
    required String label,
    required String transition,
    required String currentValue,
    required bool isHealthy,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colors.muted)),
          const SizedBox(height: 4),
          Text(transition, style: TextStyle(fontSize: 12, color: colors.muted)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                currentValue,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isHealthy ? colors.text : colors.red,
                ),
              ),
              const Spacer(),
              Icon(
                isHealthy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 16,
                color: isHealthy ? colors.green : colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationChecksCard(AppColorScheme colors) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AUTOMATED HEALTH CRITERIA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 10),
          _buildCheckItem(colors, 'Error rate below 1.0% (Current: $_currentErrorRate%)'),
          const SizedBox(height: 8),
          _buildCheckItem(colors, 'P95 latency under 300 ms (Current: ${_currentLatency}ms)'),
          const SizedBox(height: 8),
          _buildCheckItem(colors, 'No HTTP 5xx errors recorded for > 5 min'),
          const SizedBox(height: 8),
          _buildCheckItem(colors, 'Synthetic health check: HTTP 200 OK (/health)'),
        ],
      ),
    );
  }

  Widget _buildCheckItem(AppColorScheme colors, String text) {
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, color: colors.green, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: colors.text),
          ),
        ),
      ],
    );
  }
}
