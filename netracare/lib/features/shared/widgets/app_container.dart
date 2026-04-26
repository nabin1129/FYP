import 'package:flutter/material.dart';

import 'package:netracare/config/app_theme.dart';

class AppContainer extends StatelessWidget {
  const AppContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.boxShadow,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? colors.surface) : null,
        gradient: gradient,
        border: border,
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}
