import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final String currentRoute;
  final Function(String)? onTabSelected;

  const AppBottomNav({
    super.key,
    required this.currentRoute,
    this.onTabSelected,
  });

  void _handleNavigation(BuildContext context, String targetRoute) {
    if (onTabSelected != null) {
      onTabSelected!(targetRoute);
      return;
    }

    if (currentRoute == targetRoute) return;

    switch (targetRoute) {
      case 's03':
        Navigator.pushNamed(context, '/dashboard');
        break;
      case 's04':
        Navigator.pushNamed(context, '/incidents');
        break;
      case 's11':
        Navigator.pushNamed(context, '/services');
        break;
      case 's23':
        Navigator.pushNamed(context, '/assistant');
        break;
      case 's28':
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tabs = [
      {'label': 'Overview', 'icon': '◉', 'route': 's03'},
      {'label': 'Incidents', 'icon': '⚠', 'route': 's04'},
      {'label': 'Services', 'icon': '▤', 'route': 's11'},
      {'label': 'Assistant', 'icon': '✦', 'route': 's23'},
      {'label': 'More', 'icon': '☰', 'route': 's28'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.navBg,
        border: Border(
          top: BorderSide(color: colors.navBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: tabs.map((t) {
              final isSelected = currentRoute == t['route'] || currentRoute == t['label'];
              return Expanded(
                child: InkWell(
                  onTap: () => _handleNavigation(context, t['route']!),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t['icon']!,
                        style: TextStyle(
                          fontSize: 18,
                          color: isSelected ? colors.teal : colors.muted,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t['label']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? colors.teal : colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
