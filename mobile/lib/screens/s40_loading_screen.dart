import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S40LoadingScreen extends StatelessWidget {
  const S40LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'Loading latest data…',
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fetching incidents and metrics from the API…',
                      style: TextStyle(fontSize: 14, color: colors.muted),
                    ),
                    const SizedBox(height: 14),
                    _buildSkeleton(height: 170, width: double.infinity, color: colors.surface2),
                    const SizedBox(height: 14),
                    _buildSkeleton(height: 14, width: 160, color: colors.surface2),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildSkeleton(height: 84, width: double.infinity, color: colors.surface2)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildSkeleton(height: 84, width: double.infinity, color: colors.surface2)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildSkeleton(height: 84, width: double.infinity, color: colors.surface2)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSkeleton(height: 14, width: 140, color: colors.surface2),
                    const SizedBox(height: 10),
                    _buildSkeleton(height: 64, width: double.infinity, color: colors.surface2),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _buildSkeleton(height: 110, width: double.infinity, color: colors.surface2)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildSkeleton(height: 110, width: double.infinity, color: colors.surface2)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const AppBottomNav(currentRoute: 'dashboard'),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton({required double height, required double width, required Color color}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
