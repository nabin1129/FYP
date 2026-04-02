import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';

/// Reusable form field widget for profile settings
class ProfileFormField extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.fontBody,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
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
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppTheme.categoryBlue,
                width: 2,
              ),
            ),
            filled: readOnly,
            fillColor: readOnly ? AppTheme.surfaceMuted : null,
          ),
        ),
      ],
    );
  }
}
