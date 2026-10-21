import 'package:flutter/material.dart';

/// Colores de MAGRA, estilo "energía neón": fondo oscuro profundo con
/// acentos lima y violeta eléctrico. Los de macronutrientes conservan la
/// lógica del sistema de intercambios del nutricionista (carbohidratos
/// azul, proteínas rosa, lípidos naranja, vegetales verde), en versión
/// brillante para leerse sobre fondo oscuro.
abstract final class MagraColors {
  static const lime = Color(0xFFB6FF3B);
  static const violet = Color(0xFF7C5CFF);
  static const cyan = Color(0xFF22D3EE);

  /// Color principal (botones, progreso, selección).
  static const accent = lime;

  static const background = Color(0xFF0B0F1A);
  static const surface = Color(0xFF121829);
  static const surfaceHigh = Color(0xFF1A2236);
  static const surfaceHighest = Color(0xFF222B42);
  static const outline = Color(0xFF3A4560);
  static const outlineSoft = Color(0xFF262F47);
  static const text = Color(0xFFEFF3FF);
  static const textSoft = Color(0xFFA3ADC8);

  static const carb = Color(0xFF4D9DFF);
  static const protein = Color(0xFFFF5C9E);
  static const lipid = Color(0xFFFF9F43);
  static const vegetable = Color(0xFF4ADE80);

  static const good = Color(0xFF4ADE80);
  static const warning = Color(0xFFFFB547);
  static const bad = Color(0xFFFF5C7A);

  /// Degradado de marca (wordmark, anillos, botones destacados).
  static const brandGradient = LinearGradient(
    colors: [lime, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class MagraTheme {
  static const _radius = 20.0;

  static ThemeData neon() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: MagraColors.lime,
      onPrimary: MagraColors.background,
      primaryContainer: Color(0xFF2B3A10),
      onPrimaryContainer: MagraColors.lime,
      secondary: MagraColors.violet,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF2A2163),
      onSecondaryContainer: Color(0xFFD9D0FF),
      tertiary: MagraColors.cyan,
      onTertiary: MagraColors.background,
      error: MagraColors.bad,
      onError: MagraColors.background,
      errorContainer: Color(0xFF4A1520),
      onErrorContainer: Color(0xFFFFD6DD),
      surface: MagraColors.background,
      onSurface: MagraColors.text,
      onSurfaceVariant: MagraColors.textSoft,
      surfaceContainerLowest: Color(0xFF080B14),
      surfaceContainerLow: Color(0xFF0F1424),
      surfaceContainer: MagraColors.surface,
      surfaceContainerHigh: MagraColors.surfaceHigh,
      surfaceContainerHighest: MagraColors.surfaceHighest,
      outline: MagraColors.outline,
      outlineVariant: MagraColors.outlineSoft,
      inverseSurface: MagraColors.text,
      onInverseSurface: MagraColors.background,
      inversePrimary: Color(0xFF4F7A00),
      shadow: Colors.black,
      scrim: Colors.black,
    );

    const pill = StadiumBorder();
    final base = ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: MagraColors.background,
    );
    final text = base.textTheme.apply(
      bodyColor: MagraColors.text,
      displayColor: MagraColors.text,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: MagraColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radius)),
          side: BorderSide(color: MagraColors.outlineSoft),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: MagraColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: MagraColors.text,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: pill,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: pill,
          minimumSize: const Size(48, 48),
          foregroundColor: MagraColors.text,
          side: const BorderSide(color: MagraColors.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MagraColors.lime,
          shape: pill,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: MagraColors.textSoft),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(pill),
          side: const WidgetStatePropertyAll(BorderSide(color: MagraColors.outline)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? MagraColors.lime : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? MagraColors.background : MagraColors.text),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        side: const BorderSide(color: MagraColors.outline),
        backgroundColor: MagraColors.surface,
        selectedColor: MagraColors.lime,
        labelStyle: const TextStyle(color: MagraColors.text),
        secondaryLabelStyle: const TextStyle(color: MagraColors.background),
        checkmarkColor: MagraColors.background,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MagraColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MagraColors.outlineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MagraColors.lime, width: 1.5),
        ),
        labelStyle: const TextStyle(color: MagraColors.textSoft),
        hintStyle: const TextStyle(color: MagraColors.outline),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MagraColors.lime,
        linearTrackColor: MagraColors.outlineSoft,
        circularTrackColor: MagraColors.outlineSoft,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: MagraColors.lime,
        thumbColor: MagraColors.lime,
        inactiveTrackColor: MagraColors.outlineSoft,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? MagraColors.lime : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(MagraColors.background),
        side: const BorderSide(color: MagraColors.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F1424),
        surfaceTintColor: Colors.transparent,
        indicatorColor: MagraColors.lime,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? MagraColors.background
                : MagraColors.textSoft)),
        labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MagraColors.text)),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF0F1424),
        indicatorColor: MagraColors.lime,
        selectedIconTheme: IconThemeData(color: MagraColors.background),
        unselectedIconTheme: IconThemeData(color: MagraColors.textSoft),
        selectedLabelTextStyle:
            TextStyle(color: MagraColors.lime, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: MagraColors.textSoft),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: MagraColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MagraColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MagraColors.surfaceHighest,
        contentTextStyle: TextStyle(color: MagraColors.text),
        shape: StadiumBorder(),
      ),
      listTileTheme: const ListTileThemeData(iconColor: MagraColors.textSoft),
      dividerTheme: const DividerThemeData(color: MagraColors.outlineSoft),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
