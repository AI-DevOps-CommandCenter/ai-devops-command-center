import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_icons.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? fallbackRoute;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.fallbackRoute,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () {
        if (onPressed != null) {
          onPressed!();
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else if (fallbackRoute != null) {
          Navigator.pushReplacementNamed(context, fallbackRoute!);
        } else {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
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
        alignment: Alignment.center,
        child: LucideIcon(
          LucideIconData.chevronLeft,
          size: 20,
          color: colors.text,
          strokeWidth: 2.0,
        ),
      ),
    );
  }
}
