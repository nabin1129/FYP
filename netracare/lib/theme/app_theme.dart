import 'package:flutter/material.dart';

import 'accessibility_modes.dart';
import 'color_schemes.dart';

class AppTheme {
  AppTheme._();

  // Legacy color tokens kept for compatibility during migration.
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color accent = Color(0xFF6366F1);
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Colors.white;
  static const Color surfaceLight = Color(0xFFF9FAFB);
  static const Color surfaceMuted = Color(0xFFF3F4F6);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textSubtle = Color(0xFF4B5563);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
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
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color testIconBackground = Color(0xFFEEF2FF);
  static const Color testIconColor = Color(0xFF4F46E5);
  static const Color testDark = Color(0xFF1A1A2E);
  static const Color warningDark = Color(0xFF92400E);
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

  static ThemeData lightTheme(ThemeSettings settings) {
    return _buildTheme(brightness: Brightness.light, settings: settings);
  }

  static ThemeData darkTheme(ThemeSettings settings) {
    return _buildTheme(brightness: Brightness.dark, settings: settings);
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ThemeSettings settings,
  }) {
    final colors = AppPaletteResolver.resolve(
      brightness: brightness,
      accessibilityMode: settings.accessibilityMode,
    );

    final baseScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
    );

    final colorScheme = baseScheme.copyWith(
      primary: colors.primary,
      onPrimary: Colors.white,
      secondary: colors.accent,
      onSecondary: Colors.white,
      error: colors.error,
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      outline: colors.border,
      shadow: Colors.black.withValues(
        alpha: brightness == Brightness.dark ? 0.3 : 0.12,
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.border),
    );

    final textTheme = Typography.material2021().black.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colors.background,
      dividerColor: colors.divider,
      splashFactory: InkRipple.splashFactory,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceLight,
        hintStyle: TextStyle(color: colors.textLight),
        labelStyle: TextStyle(color: colors.textSecondary),
        prefixIconColor: colors.textLight,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        disabledBorder: inputBorder,
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colors.primary.withValues(alpha: 0.35)
              : colors.surfaceMuted;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? Colors.white
                : colors.textPrimary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? colors.primary
                : colors.surface;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1),
    );
  }

  // Legacy layout and typography tokens kept stable for gradual migration.
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusCircular = 50.0;

  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;

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

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 15,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> adaptiveCardShadow(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.24 : 0.08,
      ),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> adaptiveElevatedShadow(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.32 : 0.12,
      ),
      blurRadius: 15,
      offset: const Offset(0, 4),
    ),
  ];

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
