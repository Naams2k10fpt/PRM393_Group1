import 'package:flutter/material.dart';

class KahootColors {
  // Team Theme Tokens (Aliged with Web site.css)
  static const Color background = Color(0xFF0B1120); // Dark luxury slate
  static const Color surface = Color(0xFF111827);    // Card surface
  static const Color elevated = Color(0xFF1C2A3E);   // Elevated components
  static const Color border = Color(0x1FFFFFFF);     // 12% White border
  static const Color borderStrong = Color(0x38FFFFFF);

  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFFA8B8CC);
  static const Color textDim = Color(0xFF6B7E94);

  // Brand Accents
  static const Color accent = Color(0xFF7C6DF8);     // Indigo Violet Accent
  static const Color accentHover = Color(0xFF6B5CE7);
  static const Color cyan = Color(0xFF22D3EE);       // Neon Cyan

  // Functional Status
  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  
  // Option A - Ruby Crimson
  static const Color red = Color(0xFFF43F5E);
  // Option B - Cobalt Blue
  static const Color blue = Color(0xFF3B82F6);
  // Option C - Amber Gold
  static const Color yellow = Color(0xFFF59E0B);
  // Option D - Emerald Green
  static const Color green = Color(0xFF10B981);

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


