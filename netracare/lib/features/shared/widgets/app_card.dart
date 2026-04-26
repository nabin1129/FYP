import 'package:flutter/material.dart';

import 'package:netracare/config/app_theme.dart';
import 'app_container.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spaceMD),
    this.margin,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.radius,
    this.useElevatedShadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Gradient? gradient;
  final BoxBorder? border;
  final double? radius;
  final bool useElevatedShadow;

  @override
  Widget build(BuildContext context) {
    return AppContainer(
      margin: margin,
      padding: padding,
      backgroundColor: backgroundColor,
      gradient: gradient,
      border: border,
      borderRadius: BorderRadius.circular(radius ?? AppTheme.radiusLarge),
      boxShadow: useElevatedShadow
          ? AppTheme.adaptiveElevatedShadow(context)
          : AppTheme.adaptiveCardShadow(context),
      child: child,
    );
  }
}
