import 'package:flutter/material.dart';
import '../models/cicd_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Shared helpers for the CI/CD screens (S13, S14, S15, S24), which read the
/// backend's read-only GitHub API (/api/github, allow-listed repositories).

class RepoRef {
  final String owner;
  final String repo;
  const RepoRef(this.owner, this.repo);
  String get fullName => '$owner/$repo';
}

class CicdUtils {
  /// The first allow-listed repository, used when a screen is opened without one.
  static Future<RepoRef> defaultRepo() async {
    final repos = await ApiService().fetchRepositories();
    if (repos.isEmpty) throw ApiException('No repositories are configured on the backend.');
    return RepoRef(repos.first.owner, repos.first.name);
  }

  static String errorText(Object e) {
    if (e is ApiException && e.statusCode == 503 && !e.message.toLowerCase().contains('rate limit')) {
      return 'GitHub is not connected. Set GITHUB_TOKEN and GITHUB_REPOSITORIES in backend/.env.';
    }
    if (e is ApiException && e.statusCode == 502 && e.message.toLowerCase().contains('misconfigured')) {
      return 'GitHub rejected the backend token. Check GITHUB_TOKEN in backend/.env (read-only token with access to the repository).';
    }
    return e is ApiException ? e.message : 'Could not load data from GitHub.';
  }

  static String ago(DateTime? t) {
    if (t == null) return '—';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 48) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  static String duration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '—';
    final d = end.difference(start);
    return d.inMinutes > 0 ? '${d.inMinutes} min ${d.inSeconds % 60} s' : '${d.inSeconds} s';
  }

  /// Colour and label for a GitHub status/conclusion pair.
  static (Color, String) runTone(AppColorScheme colors, String? status, String? conclusion) {
    if (status != 'completed') return (colors.accent, status == null ? 'unknown' : status.replaceAll('_', ' '));
    return switch (conclusion) {
      'success' => (colors.success, 'success'),
      'failure' || 'timed_out' || 'startup_failure' => (colors.critical, conclusion!.replaceAll('_', ' ')),
      'cancelled' || 'skipped' || 'neutral' => (colors.muted, conclusion!),
      _ => (colors.warning, conclusion ?? 'completed'),
    };
  }

  static (Color, String) prTone(AppColorScheme colors, PullRequestModel pr) {
    if (pr.isMerged) return (colors.info, 'merged');
    if (pr.state == 'closed') return (colors.muted, 'closed');
    if (pr.isDraft) return (colors.muted, 'draft');
    return (colors.success, 'open');
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

/// A tappable row card: title, subtitle and a status pill.
class CicdRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? pill;
  final Color? pillColor;
  final IconData icon;
  final VoidCallback? onTap;

  const CicdRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.pill,
    this.pillColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: pillColor ?? colors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (pill != null) ...[const SizedBox(width: 8), StatusPill(label: pill!, color: pillColor ?? colors.muted)],
            ],
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.52, color: context.colors.muted)),
      );
}
