import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { light, dark, system }

// Provider for theme service
final themeServiceProvider = ChangeNotifierProvider<ThemeService>((ref) {
  return ThemeService();
});

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  AppThemeMode _themeMode = AppThemeMode.system;
  
  AppThemeMode get themeMode => _themeMode;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);
    if (saved != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

// App Color Palette - Centralized colors for consistency
class AppColors {
  // Primary Brand Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  
  // Semantic Colors (same for both themes)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF06B6D4);
  
  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);
  static const Color lightDivider = Color(0xFFF1F5F9);
  static const Color lightInputFill = Color(0xFFF8FAFC);
  
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color darkDivider = Color(0xFF334155);
  static const Color darkInputFill = Color(0xFF1E293B);
}

// Theme Data Definitions
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.lightBackground,
      fontFamily: 'Outfit',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.secondaryBlue,
        surface: AppColors.lightSurface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        displayMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        displaySmall: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        headlineLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        headlineMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        headlineSmall: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        titleLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        titleMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        titleSmall: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        bodyLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        bodySmall: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextSecondary),
        labelLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary),
        labelMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextSecondary),
        labelSmall: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextTertiary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightInputFill,
        hintStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextTertiary),
        labelStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightTextPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightTextPrimary,
          side: const BorderSide(color: AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.lightTextPrimary,
        foregroundColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        modalElevation: 8,
        modalBarrierColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.lightTextSecondary, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: 'Outfit',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryBlue,
        secondary: AppColors.secondaryBlue,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkTextPrimary,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        displayMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        displaySmall: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        headlineLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        headlineMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        headlineSmall: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        titleLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        titleMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        titleSmall: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        bodyLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        bodySmall: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextSecondary),
        labelLarge: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary),
        labelMedium: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextSecondary),
        labelSmall: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextTertiary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInputFill,
        hintStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextTertiary),
        labelStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondaryBlue,
          textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        modalElevation: 8,
        modalBarrierColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.darkTextSecondary, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// Extension for easy theme-aware color access
extension ThemeColorExtension on BuildContext {
  // Convenience getters
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  
  // Background colors
  Color get scaffoldBg => isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get cardBg => isDark ? AppColors.darkCard : AppColors.lightCard;
  Color get surfaceBg => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  
  // Text colors
  Color get textPrimary => isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary => isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textTertiary => isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
  
  // Border & Divider
  Color get borderColor => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get dividerColor => isDark ? AppColors.darkDivider : AppColors.lightDivider;
  
  // Input
  Color get inputFill => isDark ? AppColors.darkInputFill : AppColors.lightInputFill;
  
  // Primary
  Color get primary => AppColors.primaryBlue;
  Color get primaryLight => AppColors.primaryBlue.withOpacity(0.1);
}
