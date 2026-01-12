import 'package:flutter/material.dart';

class AppTheme {
  // --- Colors ---
  static const Color primaryBrand = Color(0xFF6D1B1B); // Deep Temple Maroon
  static const Color primaryDark = Color(0xFF420A0A);  // Darker Maroon for gradients
  static const Color primaryAccent = Color(0xFFD4AF37); // Deep Gold
  static const Color background = Color(0xFFFFF9F0);   // Warm Paper/Cream
  
  // FIX: Renamed these back to match your existing screens
  static const Color textOnLight = Color(0xFF2D0E0E); // Dark text for light backgrounds
  static const Color textOnDark = Color(0xFFFFF4D6);  // Light text for dark backgrounds

  // --- Gradients ---
  static const LinearGradient mainGradient = LinearGradient(
    colors: [primaryBrand, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF3E5AB), Color(0xFFD4AF37)], 
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // --- Styles ---
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryBrand,
      scaffoldBackgroundColor: background,
      fontFamily: 'Georgia', 
      colorScheme: ColorScheme.fromSeed(seedColor: primaryBrand),
      
      // Better Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAccent, width: 2),
        ),
      ),

      // Better Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrand,
          foregroundColor: textOnDark, // Using the fixed name here
          elevation: 5,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }
  
  // Custom Card Decoration (Glassy Look)
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.9),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: primaryBrand.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}