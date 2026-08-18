import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A frosted-glass (glassmorphism) surface: blurs whatever is behind it and
/// overlays a translucent tint with a subtle light border. Adapts to light/dark.
///
/// Use for cards, bottom bars, dialogs, etc. The parent must let content render
/// behind it (e.g. `Scaffold(extendBody: true)` for bottom bars) for the blur
/// to be visible.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool border;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 18,
    this.opacity = 0.65,
    this.borderRadius,
    this.padding,
    this.tint,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = FinzoTheme.isDark(context);
    final baseTint = tint ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final radius = borderRadius ?? BorderRadius.circular(FinzoRadius.xl);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: baseTint.withOpacity(opacity),
            borderRadius: radius,
            border: border
                ? Border.all(
                    color: Colors.white.withOpacity(isDark ? 0.10 : 0.55),
                    width: 1,
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
