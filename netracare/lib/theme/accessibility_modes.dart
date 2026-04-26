import 'package:flutter/material.dart';

enum AccessibilityMode { standard, protanopia, deuteranopia, tritanopia }

extension AccessibilityModeX on AccessibilityMode {
  String get label => switch (this) {
    AccessibilityMode.standard => 'Standard',
    AccessibilityMode.protanopia => 'Protanopia',
    AccessibilityMode.deuteranopia => 'Deuteranopia',
    AccessibilityMode.tritanopia => 'Tritanopia',
  };

  String get description => switch (this) {
    AccessibilityMode.standard => 'Default NetraCare palette.',
    AccessibilityMode.protanopia =>
      'Red-safe palette with stronger blue, gold, and violet separation.',
    AccessibilityMode.deuteranopia =>
      'Green-safe palette with clearer blue, amber, and magenta contrast.',
    AccessibilityMode.tritanopia =>
      'Blue-safe palette with cyan, coral, and plum differentiation.',
  };

  IconData get icon => switch (this) {
    AccessibilityMode.standard => Icons.palette_outlined,
    AccessibilityMode.protanopia => Icons.visibility_outlined,
    AccessibilityMode.deuteranopia => Icons.remove_red_eye_outlined,
    AccessibilityMode.tritanopia => Icons.colorize_outlined,
  };
}

class ThemeSettings {
  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.accessibilityMode = AccessibilityMode.standard,
    this.textScale = 1.0,
  });

  static const minTextScale = 0.9;
  static const maxTextScale = 1.3;

  final ThemeMode themeMode;
  final AccessibilityMode accessibilityMode;
  final double textScale;

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    AccessibilityMode? accessibilityMode,
    double? textScale,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      accessibilityMode: accessibilityMode ?? this.accessibilityMode,
      textScale: (textScale ?? this.textScale).clamp(
        minTextScale,
        maxTextScale,
      ),
    );
  }

  Map<String, Object> toJson() {
    return {
      'themeMode': themeMode.name,
      'accessibilityMode': accessibilityMode.name,
      'textScale': textScale,
    };
  }

  factory ThemeSettings.fromJson(Map<String, Object?> json) {
    return ThemeSettings(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      accessibilityMode: AccessibilityMode.values.firstWhere(
        (mode) => mode.name == json['accessibilityMode'],
        orElse: () => AccessibilityMode.standard,
      ),
      textScale: switch (json['textScale']) {
        final double value => value.clamp(minTextScale, maxTextScale),
        final int value => value.toDouble().clamp(minTextScale, maxTextScale),
        _ => 1.0,
      },
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ThemeSettings &&
        other.themeMode == themeMode &&
        other.accessibilityMode == accessibilityMode &&
        other.textScale == textScale;
  }

  @override
  int get hashCode => Object.hash(themeMode, accessibilityMode, textScale);
}
