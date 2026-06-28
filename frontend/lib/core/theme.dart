import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Mehmoodah Academy Design System – Color Tokens
// ---------------------------------------------------------------------------
class AppColors {
  // Primary
  static const primaryDeepNavy = Color(0xFF1B365D);
  static const accentSoftBlue  = Color(0xFF5C7CFA);

  // Backgrounds
  static const backgroundLight = Color(0xFFFAFBFC);
  static const surfaceWhite    = Color(0xFFFFFFFF);
  static const borderLight     = Color(0xFFE8EDF3);

  // Status
  static const successGreen  = Color(0xFF34C759);
  static const warningOrange = Color(0xFFFF9F43);
  static const dangerRed     = Color(0xFFFF5A5F);

  // Text
  static const textPrimary   = Color(0xFF1B365D);
  static const textSecondary = Color(0xFF6B7A99);
  static const textMuted     = Color(0xFFA0ABBE);

  // Dark mode surfaces
  static const darkBackground = Color(0xFF0F1929);
  static const darkSurface    = Color(0xFF1A2740);
  static const darkBorder     = Color(0xFF243350);
}

// ---------------------------------------------------------------------------
// Shared Text Styles
// ---------------------------------------------------------------------------
class AppTextStyles {
  static const String _fontFamily = 'Inter';

  static const heading1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const heading2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const heading3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  static const caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    letterSpacing: 0.4,
  );
}

// ---------------------------------------------------------------------------
// App Theme
// ---------------------------------------------------------------------------
class AppTheme {
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.backgroundLight,
        colorScheme: const ColorScheme.light(
          primary:   AppColors.primaryDeepNavy,
          secondary: AppColors.accentSoftBlue,
          surface:   AppColors.surfaceWhite,
          error:     AppColors.dangerRed,
          onPrimary:   Colors.white,
          onSecondary: Colors.white,
          onSurface:   AppColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceWhite,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: AppColors.borderLight,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderLight),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentSoftBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: AppTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentSoftBlue,
            textStyle: AppTextStyles.labelLarge,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.backgroundLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accentSoftBlue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.dangerRed),
          ),
          labelStyle: AppTextStyles.bodyMedium,
          hintStyle: AppTextStyles.bodyMedium,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderLight,
          thickness: 1,
          space: 1,
        ),
        textTheme: const TextTheme(
          headlineLarge:  AppTextStyles.heading1,
          headlineMedium: AppTextStyles.heading2,
          headlineSmall:  AppTextStyles.heading3,
          bodyLarge:      AppTextStyles.bodyLarge,
          bodyMedium:     AppTextStyles.bodyMedium,
          bodySmall:      AppTextStyles.bodySmall,
          labelLarge:     AppTextStyles.labelLarge,
          labelSmall:     AppTextStyles.caption,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.darkBackground,
        colorScheme: const ColorScheme.dark(
          primary:   AppColors.accentSoftBlue,
          secondary: AppColors.accentSoftBlue,
          surface:   AppColors.darkSurface,
          error:     AppColors.dangerRed,
          onPrimary:   Colors.white,
          onSecondary: Colors.white,
          onSurface:   Colors.white,
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.darkBorder),
          ),
        ),
      );
}

// Dynamic state management for ThemeMode
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
