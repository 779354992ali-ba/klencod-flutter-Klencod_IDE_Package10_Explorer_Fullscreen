import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central design tokens for Bisho IDE.
class BishoColors {
  const BishoColors._();

  static const Color background = Color(0xFF0B1020);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceHigh = Color(0xFF151C30);
  static const Color surfaceHighest = Color(0xFF1E293B);
  static const Color outline = Color(0xFF263248);
  static const Color primary = Color(0xFF38BDF8);
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color textMuted = Color(0xFF94A3B8);
}

/// Persisted light/dark/system preference shared by the whole app.
class BishoThemeController {
  BishoThemeController._();

  static const String _key = 'bisho_theme_mode';
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (prefs.getString(_key)) {
        case 'light':
          mode.value = ThemeMode.light;
        case 'system':
          mode.value = ThemeMode.system;
        default:
          mode.value = ThemeMode.dark;
      }
    } catch (_) {
      mode.value = ThemeMode.dark;
    }
  }

  static Future<void> set(ThemeMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.name);
    } catch (_) {
      // Preference persistence is best-effort.
    }
  }

  static Future<void> toggle() => set(
        mode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
      );
}

class BishoTheme {
  const BishoTheme._();

  static final ThemeData darkTheme = dark();
  static final ThemeData lightTheme = light();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: BishoColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF0284C7),
      secondary: BishoColors.secondary,
      error: BishoColors.danger,
      surface: const Color(0xFFF8FAFC),
      surfaceContainerHighest: const Color(0xFFE2E8F0),
      surfaceContainerHigh: const Color(0xFFEFF3F8),
      outline: const Color(0xFFCBD5E1),
      outlineVariant: const Color(0xFFCBD5E1),
    );
    final shape12 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      canvasColor: scheme.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF0F172A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 44), shape: shape12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: const Size(64, 44), shape: shape12),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44), shape: shape12),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFCBD5E1),
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: BishoColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: BishoColors.primary,
      onPrimary: const Color(0xFF04202E),
      secondary: BishoColors.secondary,
      error: BishoColors.danger,
      surface: BishoColors.surface,
      surfaceContainerHighest: BishoColors.surfaceHighest,
      surfaceContainerHigh: BishoColors.surfaceHigh,
      outline: BishoColors.outline,
      outlineVariant: BishoColors.outline,
    );

    final shape12 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: BishoColors.background,
      canvasColor: BishoColors.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: BishoColors.surfaceHigh,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: BishoColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: BishoColors.surfaceHighest,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: BishoColors.outline),
        ),
        textStyle: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BishoColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: BishoColors.surfaceHighest,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: shape12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BishoColors.surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BishoColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BishoColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BishoColors.primary, width: 1.6),
        ),
        hintStyle: const TextStyle(color: BishoColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: shape12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: shape12,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: shape12,
          side: const BorderSide(color: BishoColors.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: shape12),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: BishoColors.primary,
        shape: shape12,
      ),
      dividerTheme: const DividerThemeData(
        color: BishoColors.outline,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BishoColors.surfaceHigh,
        side: const BorderSide(color: BishoColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: BishoColors.surfaceHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BishoColors.primary,
      ),
    );
  }
}
