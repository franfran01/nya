import 'package:flutter/material.dart';

const kBg = Color(0xFF0E0F13);
const kSurface = Color(0xFF1A1C23);
const kAccent = Color(0xFFFF5A36);
const kTextDim = Color(0xFF9AA0AE);

/// true en pantallas anchas (TV / tablet): más márgenes y tarjetas más grandes.
bool isLargeScreen(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kAccent,
      brightness: Brightness.dark,
      surface: kSurface,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(backgroundColor: kBg, elevation: 0, centerTitle: false),
    focusColor: kAccent.withValues(alpha: 0.25),
    textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccent, width: 2),
      ),
    ),
  );
}
