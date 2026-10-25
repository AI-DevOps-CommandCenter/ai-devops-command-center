import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final String currentRoute;
  final Function(String) onTabSelected;

  const AppBottomNav({
    super.key,
    required this.currentRoute,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'label': 'Overview', 'icon': '◉', 'route': 's03'},
      {'label': 'Incidents', 'icon': '⚠', 'route': 's04'},
      {'label': 'Services', 'icon': '▤', 'route': 's11'},
      {'label': 'Assistant', 'icon': '✦', 'route': 's23'},
      {'label': 'More', 'icon': '☰', 'route': 's28'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.navBorder, width: 1),
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
                  onTap: () => onTabSelected(t['route']!),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t['icon']!,
                        style: TextStyle(
                          fontSize: 18,
                          color: isSelected ? AppColors.teal : AppColors.muted,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t['label']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.teal : AppColors.muted,
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
