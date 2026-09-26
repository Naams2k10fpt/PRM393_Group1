import 'package:flutter/material.dart';

class KahootColors {
  // Arena Cyberpunk Dark Theme
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color darkBackground = Color(0xFF020617); // Slate 950
  static const Color cardBackground = Color(0xFF1E293B); // Slate 800
  
  // Option A - Ruby Crimson
  static const Color red = Color(0xFFE11D48);
  // Option B - Cobalt Blue
  static const Color blue = Color(0xFF2563EB);
  // Option C - Amber Gold
  static const Color yellow = Color(0xFFD97706);
  // Option D - Emerald Green
  static const Color green = Color(0xFF059669);

  static const List<Color> answerColors = [
    red,
    blue,
    yellow,
    green,
  ];

  static const List<LinearGradient> answerGradients = [
    LinearGradient(
      colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF10B981), Color(0xFF047857)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  static const List<String> answerShapes = [
    'A',
    'B',
    'C',
    'D',
  ];
}

