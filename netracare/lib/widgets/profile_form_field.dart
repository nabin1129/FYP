import 'package:flutter/material.dart';

import 'package:netracare/config/app_theme.dart';

class ProfileFormField extends StatelessWidget {
  const ProfileFormField({
    super.key,
    required this.label,
    this.value,
    required this.onChanged,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.hint,
    this.validator,
    this.readOnly = false,
    this.controller,
  });

  final String label;
  final String? value;
  final Function(String) onChanged;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? hint;
  final String? Function(String?)? validator;
  final bool readOnly;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: colors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? value : null,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          readOnly: readOnly,
          decoration: AppTheme.inputDecoration(
            label: '',
            prefixIcon: icon,
          ).copyWith(
            hintText: hint,
            labelText: null,
            fillColor: readOnly ? colors.surfaceMuted : colors.surfaceLight,
          ),
        ),
      ],
    );
  }
}
