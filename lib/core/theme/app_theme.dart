import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Palette {
  const Palette(this.label, this.primary, this.dark, this.pale);
  final String label;
  final Color primary, dark, pale;
}

/// Same five brand colours as the web app (Settings → Appearance).
const kPalettes = <String, Palette>{
  'sleek-blue': Palette(
    'Sleek Blue (Default)',
    Color(0xFF2A4FE0),
    Color(0xFF1D3BB8),
    Color(0xFFE8EDFF),
  ),
  'indigo-violet': Palette(
    'Indigo Violet',
    Color(0xFF7C3AED),
    Color(0xFF5B21B6),
    Color(0xFFF5F3FF),
  ),
  'emerald-green': Palette(
    'Emerald Green',
    Color(0xFF059669),
    Color(0xFF065F46),
    Color(0xFFECFDF5),
  ),
  'rose-red': Palette(
    'Rose Red',
    Color(0xFFDC2626),
    Color(0xFF991B1B),
    Color(0xFFFEF2F2),
  ),
  'warm-amber': Palette(
    'Warm Amber',
    Color(0xFFD97706),
    Color(0xFF92400E),
    Color(0xFFFFFBEB),
  ),
};

/// App colours. Everything is a getter so light/dark mode and the brand
/// colour can change at runtime (see AppearanceController).
class C {
  static bool dark = false;
  static Palette _p = kPalettes['sleek-blue']!;

  static void apply({required bool isDark, required String colorKey}) {
    dark = isDark;
    _p = kPalettes[colorKey] ?? kPalettes['sleek-blue']!;
  }

  static Color get primary => _p.primary;
  static Color get primaryDark => _p.dark;
  static Color get primarySoft => dark ? _p.primary.withOpacity(.20) : _p.pale;
  static Color get bg =>
      dark ? const Color(0xFF0D111D) : const Color(0xFFF5F7FC);
  static Color get card => dark ? const Color(0xFF171C2E) : Colors.white;
  static Color get text =>
      dark ? const Color(0xFFE8ECF8) : const Color(0xFF0F1B3D);
  static Color get muted =>
      dark ? const Color(0xFF9AA5C0) : const Color(0xFF6B7690);
  static Color get border =>
      dark ? const Color(0xFF2A3150) : const Color(0xFFE3E8F3);
  static Color get success =>
      dark ? const Color(0xFF34D399) : const Color(0xFF16A34A);
  static Color get successSoft =>
      dark ? const Color(0xFF34D399).withOpacity(.16) : const Color(0xFFE6F6EC);
  static Color get warning =>
      dark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
  static Color get warningSoft =>
      dark ? const Color(0xFFFBBF24).withOpacity(.16) : const Color(0xFFFFF1E0);
  static Color get danger =>
      dark ? const Color(0xFFF87171) : const Color(0xFFE5484D);
  static Color get dangerSoft =>
      dark ? const Color(0xFFF87171).withOpacity(.16) : const Color(0xFFFDEAEA);
}

ThemeData buildTheme() {
  final dark = C.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: C.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: C.primary,
    surface: C.card,
  );
  OutlineInputBorder b(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.card,
    cardColor: C.card,
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: C.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: C.card,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: C.card,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: b(C.border),
      enabledBorder: b(C.border),
      focusedBorder: b(C.primary),
      hintStyle: TextStyle(color: C.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.primary,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: C.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: C.border,
    dividerTheme: DividerThemeData(color: C.border),
    listTileTheme: ListTileThemeData(textColor: C.text, iconColor: C.primary),
  );
}
