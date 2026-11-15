import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

/// Bottom navigation — exact copy of the prototype's <nav aria-label="Main">:
/// Home · Incidents · Monitor · CI/CD · Assistant
/// (padding 6/6/18, pill 56x30, label 12px, icons 20px / stroke 2)
class AppBottomNav extends StatelessWidget {
  final int? currentIndex;
  final String? currentRoute;
  final ValueChanged<int>? onTap;

  const AppBottomNav({
    super.key,
    this.currentIndex,
    this.currentRoute,
    this.onTap,
  });

  static const _routes = [
    '/dashboard',
    '/incidents',
    '/services',
    '/repositories',
    '/assistant',
  ];

  static const _labels = ['Home', 'Incidents', 'Monitor', 'CI/CD', 'Assistant'];

  // Inner SVG paths copied 1:1 from the prototype (24x24 viewBox).
  static const _icons = [
    '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/><path d="M10 21v-6h4v6"/>',
    '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
    '<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>',
    '<circle cx="6" cy="6" r="2.5"/><circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="7" r="2.5"/><path d="M6 8.5v7"/><path d="M18 9.5c0 4-5 4-10.5 6.5"/>',
    '<path d="M12 3l1.8 4.7 4.7 1.8-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8z"/><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>',
  ];

  int get _resolvedIndex {
    if (currentIndex != null) return currentIndex!;
    switch (currentRoute) {
      case 'overview':
      case 'dashboard':
      case '/dashboard':
        return 0;
      case 'incidents':
      case '/incidents':
      case 's04':
        return 1;
      case 'monitor':
      case 'services':
      case '/services':
        return 2;
      case 'cicd':
      case '/repositories':
        return 3;
      case 'assistant':
      case '/assistant':
        return 4;
    }
    return 0;
  }

  void _go(BuildContext context, int index) {
    if (onTap != null) {
      onTap!(index);
      return;
    }
    if (index == _resolvedIndex) return;
    Navigator.pushReplacementNamed(context, _routes[index]);
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = _resolvedIndex;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_labels.length, (i) {
          final on = i == active;
          final iconColor = on ? colors.accent : colors.muted;
          final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" '
              'viewBox="0 0 24 24" fill="none" stroke="${_hex(iconColor)}" '
              'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
              '${_icons[i]}</svg>';
          return Expanded(
            child: InkWell(
              onTap: () => _go(context, i),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? colors.accentSoft : null,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: SvgPicture.string(svg, width: 20, height: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                        color: on ? colors.text : colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
