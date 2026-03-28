import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color blancoGlacial = Color(0xFFF8FFFF);
  static const Color purpuraPrimario = Color(0xFF8D72C2);
  static const Color negroAzabache = Color(0xFF010302);
  static const Color grisTecnico = Color(0xFFF4F7F9);
  static const Color lavandaAcento = Color(0xFFF0E6FF);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: blancoGlacial,
      primaryColor: purpuraPrimario,
      colorScheme: ColorScheme.fromSeed(
        seedColor: purpuraPrimario,
        primary: purpuraPrimario,
        secondary: lavandaAcento,
        surface: blancoGlacial,
        onSurface: negroAzabache,
        surfaceContainer: grisTecnico,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: negroAzabache,
        displayColor: negroAzabache,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: blancoGlacial,
        elevation: 0,
        iconTheme: IconThemeData(color: negroAzabache),
        titleTextStyle: TextStyle(color: negroAzabache),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purpuraPrimario,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grisTecnico,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: negroAzabache.withAlpha(150)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }
}
