import 'package:flutter/material.dart';

/// Design tokens for the playful dark "courtroom" look.
/// Deep navy/purple surfaces with purple, pink, yellow and teal accents.
class AppColors {
  const AppColors._();

  static const Color surface = Color(0xFF140F2E);
  static const Color surfaceRaised = Color(0xFF1D1543);
  static const Color surfaceCard = Color(0xFF251B52);
  static const Color primary = Color(0xFFB15CFF);
  static const Color secondary = Color(0xFFFF4D8D);
  static const Color accent = Color(0xFFFFD166);
  static const Color teal = Color(0xFF2ED9C3);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color textPrimary = Color(0xFFF7F3FF);
  static const Color textMuted = Color(0xFFA9A1CC);
  static const Color border = Color(0xFF3A2C6E);
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;
}

/// Accessibility: minimum 48dp touch targets (Android guidance).
class AppSizes {
  const AppSizes._();

  static const double minTouchTarget = 48;
  static const double avatarSm = 36;
  static const double avatarMd = 48;
}
