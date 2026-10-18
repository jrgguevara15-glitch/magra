import 'package:flutter/material.dart';

/// Colores de MAGRA. Los de macronutrientes vienen del sistema de
/// intercambios del nutricionista (carbohidratos azul, proteínas rosa,
/// lípidos naranja, vegetales verde).
abstract final class MagraColors {
  static const accent = Color(0xFF1F5FC4);
  static const accentDark = Color(0xFF6A9CF0);

  static const carb = Color(0xFF3D6FCF);
  static const protein = Color(0xFFC8475F);
  static const lipid = Color(0xFFCF6A1F);
  static const vegetable = Color(0xFF3C8A3A);

  static const good = Color(0xFF2C7A3F);
  static const warning = Color(0xFFA86A00);
  static const bad = Color(0xFFB8322F);
}

abstract final class MagraTheme {
  static ThemeData light() => _build(
        ColorScheme.fromSeed(
          seedColor: MagraColors.accent,
          primary: MagraColors.accent,
          surface: const Color(0xFFF3F5F8),
        ),
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(
          seedColor: MagraColors.accent,
          brightness: Brightness.dark,
          primary: MagraColors.accentDark,
          surface: const Color(0xFF0D1420),
        ),
      );

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        titleTextStyle: TextStyle(
          color: scheme.primary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 3,
        ),
      ),
    );
  }
}
