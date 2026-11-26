import 'package:flutter/material.dart';

class AppTheme {
  static const forest = Color(0xFF0B211B);
  static const panel = Color(0xFF14352B);
  static const mint = Color(0xFFB9F5D0);
  static const red = Color(0xFFE34B55);
  static const gold = Color(0xFFE8C77B);
  static const muted = Color(0xFF9BB5A8);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: forest,
    colorScheme: const ColorScheme.dark(
      primary: mint, secondary: red, surface: panel,
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: forest, foregroundColor: Colors.white,
      elevation: 0, centerTitle: false,
    ),
  );
}
