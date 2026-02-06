import 'package:flutter/material.dart';

/// Centralized theme configuration for the NetraCare app
/// This ensures consistent colors, spacing, and styling across all pages
class AppTheme {
  // Primary Colors
  static const Color primary = Color(0xFF4F46E5); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);

  // Background Colors
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Colors.white;
  static const Color surfaceLight = Color(0xFFF9FAFB);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Test Card Colors - All tests use the same color scheme
  static const Color testIconBackground = Color(0xFFEEF2FF); // Light indigo
  static const Color testIconColor = Color(0xFF4F46E5); // Primary indigo

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient reportGradient = LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 20.0;

  // Spacing
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;

  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black12.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black12.withOpacity(0.12),
      blurRadius: 15,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Test configuration data
class TestConfig {
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const TestConfig({
    required this.name,
    required this.description,
    required this.icon,
    this.iconColor = AppTheme.testIconColor,
    this.backgroundColor = AppTheme.testIconBackground,
  });
}

/// Predefined test configurations
class AppTests {
  static const TestConfig visualAcuity = TestConfig(
    name: 'Visual Acuity Test',
    description: 'Measures clarity of vision at various distances.',
    icon: Icons.visibility,
  );

  static const TestConfig eyeTracking = TestConfig(
    name: 'Eye Tracking Test',
    description: 'Analyzes eye movement patterns.',
    icon: Icons.remove_red_eye,
  );

  static const TestConfig blinkFatigue = TestConfig(
    name: 'Blink & Fatigue Test',
    description: 'Evaluates blink rate & eye fatigue.',
    icon: Icons.bedtime,
  );

  static const TestConfig pupilReflex = TestConfig(
    name: 'Pupil Reflex Test',
    description: 'Tests eye response to light.',
    icon: Icons.flash_on,
  );

  static const TestConfig colourVision = TestConfig(
    name: 'Colour Vision Test',
    description: 'Detects colour deficiencies.',
    icon: Icons.color_lens,
  );

  static List<TestConfig> get allTests => [
    visualAcuity,
    eyeTracking,
    blinkFatigue,
    pupilReflex,
    colourVision,
  ];
}
