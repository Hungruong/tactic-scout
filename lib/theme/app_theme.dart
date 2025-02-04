import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1E4079), // MLB Blue
        secondary: Color(0xFFBF0D3E), // MLB Red
        surface: Colors.white,
        onPrimary: Colors.white,
      ),
      useMaterial3: true,
      fontFamily: 'Inter',
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
    );
  }
}