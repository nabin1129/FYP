import 'package:flutter/material.dart';

/// Centralized theme configuration for the NetraCare app.
/// Every page MUST use these constants instead of inline hex / fontSize values.
class AppTheme {
  AppTheme._(); // prevent instantiation

  // ─── Primary Colors ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color accent = Color(0xFF6366F1); // Indigo accent

  // ─── Background & Surface ────────────────────────────────────────────────
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Colors.white;
  static const Color surfaceLight = Color(0xFFF9FAFB);

  // ─── Text Colors ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textDark = Color(
    0xFF1F2937,
  ); // darker variant for headings
  static const Color textSubtle = Color(
    0xFF4B5563,
  ); // mid-tone for descriptions

  // ─── Status Colors ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ─── Category Colors (reports / result cards) ────────────────────────────
  static const Color categoryBlue = Color(0xFF3B82F6);
  static const Color categoryBlueBg = Color(0xFFEFF6FF);
  static const Color categoryGreen = Color(0xFF10B981);
  static const Color categoryGreenBg = Color(0xFFECFDF5);
  static const Color categoryPurple = Color(0xFF8B5CF6);
  static const Color categoryPurpleBg = Color(0xFFFAF5FF);
  static const Color categoryOrange = Color(0xFFF97316);
  static const Color categoryOrangeBg = Color(0xFFFFF7ED);
  static const Color categoryIndigo = Color(0xFF6366F1);
  static const Color categoryIndigoBg = Color(0xFFEEF2FF);

  // ─── Utility Colors ──────────────────────────────────────────────────────
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color testIconBackground = Color(0xFFEEF2FF); // Light indigo
  static const Color testIconColor = Color(0xFF4F46E5); // Primary indigo
  static const Color testDark = Color(
    0xFF1A1A2E,
  ); // Dark bg for test running screens
  static const Color warningDark = Color(0xFF92400E); // amber instruction text
  static const Color surfaceMuted = Color(0xFFF3F4F6); // grey-100

  // ─── Extended Status Tints (admin / report cards) ────────────────────────
  static const Color successDark = Color(0xFF059669);
  static const Color successTint = Color(0xFFD1FAE5);
  static const Color successBgLight = Color(0xFFF0FDF4);
  static const Color infoTint = Color(0xFFDBEAFE);
  static const Color overlayBlueLight = Color(0xFFBFDBFE);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);
  static const Color indigoTint = Color(0xFFEDE9FE);
  static const Color errorBg = Color(0xFFFEF2F2);

  // ─── Gradients ───────────────────────────────────────────────────────────
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

  // ─── Border Radius ───────────────────────────────────────────────────────
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusCircular = 50.0;

  // ─── Spacing ─────────────────────────────────────────────────────────────
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;

  // ─── Font Sizes ──────────────────────────────────────────────────────────
  static const double fontXS = 11.0;
  static const double fontSM = 12.0;
  static const double fontBody = 14.0;
  static const double fontLG = 16.0;
  static const double fontXL = 18.0;
  static const double fontXXL = 20.0;
  static const double fontTitle = 22.0;
  static const double fontHeading = 24.0;
  static const double fontDisplay = 36.0;
  static const double fontScore = 48.0;

  // ─── Text Styles ─────────────────────────────────────────────────────────
  static const TextStyle heading1 = TextStyle(
    fontSize: fontHeading,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: fontTitle,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: fontXXL,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const TextStyle titleStyle = TextStyle(
    fontSize: fontLG,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const TextStyle bodyPrimary = TextStyle(
    fontSize: fontBody,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const TextStyle bodySecondary = TextStyle(
    fontSize: fontBody,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  static const TextStyle caption = TextStyle(
    fontSize: fontSM,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontSize: fontSM,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const TextStyle button = TextStyle(
    fontSize: fontLG,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // ─── Shadows ─────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withAlpha(20), // ~0.08 opacity
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withAlpha(31), // ~0.12 opacity
      blurRadius: 15,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── Common Decorations ──────────────────────────────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusMedium),
    boxShadow: cardShadow,
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusMedium),
    boxShadow: elevatedShadow,
  );

  // ─── Common Input Decoration ─────────────────────────────────────────────
  static InputDecoration inputDecoration({
    required String label,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary, fontSize: fontBody),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: textLight)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spaceMD,
        vertical: spaceMD,
      ),
    );
  }

  // ─── Common Button Styles ────────────────────────────────────────────────
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 14),
    backgroundColor: primary,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSmall),
    ),
    textStyle: button,
  );

  static ButtonStyle get outlinedButton => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 14),
    side: const BorderSide(color: primary),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSmall),
    ),
    textStyle: button.copyWith(color: primary),
  );

  // ─── Standard AppBar ─────────────────────────────────────────────────────
  static AppBar standardAppBar({
    required String title,
    List<Widget>? actions,
    Widget? leading,
    bool centerTitle = true,
  }) {
    return AppBar(
      backgroundColor: surface,
      elevation: 1,
      centerTitle: centerTitle,
      title: Text(
        title,
        style: const TextStyle(
          color: textPrimary,
          fontSize: fontXXL,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      leading: leading,
      actions: actions,
    );
  }
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
