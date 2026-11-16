import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_back_button.dart';

/// Shared building blocks for the incident flow screens (S20, S21).

class FlowHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const FlowHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: colors.text)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: TextStyle(fontSize: 13, color: colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FlowCard extends StatelessWidget {
  final Widget child;
  final Color? background;
  final Color? borderColor;

  const FlowCard({super.key, required this.child, this.background, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background ?? colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? colors.border),
      ),
      child: child,
    );
  }
}

class FlowSection extends StatelessWidget {
  final String label;
  final String? text;
  final List<String>? items;

  const FlowSection({super.key, required this.label, this.text, this.items});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final list = items ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FlowCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.52, color: colors.muted)),
            const SizedBox(height: 6),
            if (text != null && text!.isNotEmpty)
              Text(text!, style: TextStyle(fontSize: 15, height: 1.45, color: colors.text)),
            ...list.map((item) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: TextStyle(fontSize: 15, color: colors.muted)),
                      Expanded(child: Text(item, style: TextStyle(fontSize: 14, height: 1.4, color: colors.text))),
                    ],
                  ),
                )),
            if ((text == null || text!.isEmpty) && list.isEmpty)
              Text('—', style: TextStyle(fontSize: 15, color: colors.muted)),
          ],
        ),
      ),
    );
  }
}

class FlowMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  final bool busy;

  const FlowMessage({super.key, required this.icon, required this.message, this.onRetry, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy ? CircularProgressIndicator(color: colors.accent) : Icon(icon, color: colors.muted, size: 32),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: colors.text, height: 1.4)),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onRetry, child: const Text('Refresh')),
            ],
          ],
        ),
      ),
    );
  }
}

class FlowStepper extends StatelessWidget {
  final int activeStage;

  const FlowStepper({super.key, required this.activeStage});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const stages = ['Detect', 'Investigate', 'Cause', 'Approve', 'Recover', 'Report'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: List.generate(stages.length, (index) {
          final done = index < activeStage;
          final active = index == activeStage;
          return Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (index > 0)
                  Positioned(
                    top: 10,
                    right: 0,
                    left: -50,
                    child: Container(height: 2, color: done || active ? colors.success : colors.border),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: done ? colors.success : active ? colors.accentSoft : colors.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: done ? colors.success : active ? colors.accent : colors.border, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: done
                          ? Icon(Icons.check, size: 13, color: colors.card)
                          : active
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle))
                              : null,
                    ),
                    const SizedBox(height: 6),
                    Text(stages[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? colors.accent : done ? colors.text : colors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
