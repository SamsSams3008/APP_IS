import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta: tema claro (fondos claros) y tema oscuro (slate + teal).
class AppTheme {
  AppTheme._();

  // --- Tema oscuro
  static const Color _bg = Color(0xFF0F1419);
  static const Color _surface = Color(0xFF1A2129);
  static const Color _surfaceVariant = Color(0xFF252D36);
  static const Color _primary = Color(0xFF0D9488);
  static const Color _primaryVariant = Color(0xFF14B8A6);
  static const Color _accent = Color(0xFFF59E0B);
  static const Color _onBg = Color(0xFFE2E8F0);
  static const Color _onSurfaceVariant = Color(0xFF94A3B8);
  static const Color _error = Color(0xFFF87171);

  // --- Tema claro
  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color _lightOnBg = Color(0xFF0F172A);
  static const Color _lightOnSurfaceVariant = Color(0xFF64748B);

  /// Tema claro: fondos claros, texto oscuro, acentos teal.
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: _primary.withValues(alpha: 0.15),
        onPrimaryContainer: const Color(0xFF0F766E),
        secondary: _primaryVariant,
        onSecondary: Colors.white,
        tertiary: _accent,
        onTertiary: _lightBg,
        surface: _lightSurface,
        onSurface: _lightOnBg,
        surfaceContainerHighest: _lightSurfaceVariant,
        onSurfaceVariant: _lightOnSurfaceVariant,
        error: _error,
        onError: Colors.white,
        outline: _lightOnSurfaceVariant.withValues(alpha: 0.6),
      ),
      scaffoldBackgroundColor: _lightBg,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: _lightSurface,
        foregroundColor: _lightOnBg,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightOnBg,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: _lightSurface,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _lightSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: _lightOnSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurfaceVariant,
        selectedColor: _primary.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: _lightOnBg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerColor: _lightOnSurfaceVariant.withValues(alpha: 0.4),
    );
  }

  /// Tema oscuro: slate + teal.
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: _primary.withValues(alpha: 0.2),
        onPrimaryContainer: _primaryVariant,
        secondary: _primaryVariant,
        onSecondary: Colors.white,
        tertiary: _accent,
        onTertiary: _bg,
        surface: _surface,
        onSurface: _onBg,
        surfaceContainerHighest: _surfaceVariant,
        onSurfaceVariant: _onSurfaceVariant,
        error: _error,
        onError: Colors.white,
        outline: _onSurfaceVariant.withValues(alpha: 0.5),
      ),
      scaffoldBackgroundColor: _bg,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 8,
        backgroundColor: _surface,
        foregroundColor: _onBg,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _onBg,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: _surface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: _onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceVariant,
        selectedColor: _primary.withValues(alpha: 0.3),
        labelStyle: const TextStyle(color: _onBg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerColor: _onSurfaceVariant.withValues(alpha: 0.3),
    );
  }
}
