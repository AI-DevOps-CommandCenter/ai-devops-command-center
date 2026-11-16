import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Draws the exact SVG icons used in the HTML prototype (24x24 viewBox, round caps).
class ProtoIcon extends StatelessWidget {
  final String paths;
  final double size;
  final Color color;
  final double strokeWidth;

  const ProtoIcon(
    this.paths, {
    super.key,
    this.size = 20,
    required this.color,
    this.strokeWidth = 2,
  });

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
        'viewBox="0 0 24 24" fill="none" stroke="${_hex(color)}" '
        'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">'
        '$paths</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// Inner SVG paths copied 1:1 from the prototype.
class ProtoIcons {
  ProtoIcons._();

  static const restart =
      '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>';
  static const layers =
      '<path d="m12 2 10 5-10 5L2 7z"/><path d="m2 17 10 5 10-5"/><path d="m2 12 10 5 10-5"/>';
  static const scale =
      '<path d="M12 3v18"/><path d="M5 8h14"/><path d="m5 8-3 7h6z"/><path d="m19 8-3 7h6z"/>';
  static const circuitBreaker =
      '<circle cx="12" cy="12" r="9"/><path d="M8 12h3"/><path d="M13 12h3"/><path d="m11 9 2 6"/>';
  static const shieldCheck =
      '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>';
  static const logs = '<path d="m4 17 6-5-6-5"/><path d="M12 19h8"/>';
  static const metrics = '<path d="M3 3v18h18"/><path d="m7 15 4-4 3 3 6-6"/>';
  static const deploy =
      '<circle cx="6" cy="6" r="2.5"/><circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="7" r="2.5"/><path d="M6 8.5v7"/><path d="M18 9.5c0 4-5 4-10.5 6.5"/>';
  static const pullRequest =
      '<circle cx="6" cy="6" r="2.5"/><circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="18" r="2.5"/><path d="M6 8.5v7"/><path d="M13 6h3a2 2 0 0 1 2 2v7.5"/>';
}
