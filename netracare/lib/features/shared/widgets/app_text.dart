import 'package:flutter/material.dart';

import 'package:netracare/config/app_theme.dart';

enum AppTextRole { title, subtitle, body, bodySecondary, label, caption }

class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.role = AppTextRole.body,
    this.color,
    this.fontWeight,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String data;
  final AppTextRole role;
  final Color? color;
  final FontWeight? fontWeight;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    final baseStyle = switch (role) {
      AppTextRole.title => textTheme.titleLarge,
      AppTextRole.subtitle => textTheme.titleMedium,
      AppTextRole.body => textTheme.bodyMedium,
      AppTextRole.bodySecondary => textTheme.bodyMedium,
      AppTextRole.label => textTheme.labelLarge,
      AppTextRole.caption => textTheme.bodySmall,
    };

    final resolvedColor = switch (role) {
      AppTextRole.bodySecondary || AppTextRole.caption => colors.textSecondary,
      _ => colors.textPrimary,
    };

    return Text(
      data,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: baseStyle?.copyWith(
        color: color ?? resolvedColor,
        fontWeight: fontWeight,
      ),
    );
  }
}
