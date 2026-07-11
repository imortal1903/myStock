import 'package:flutter/material.dart';

class ColorPalette {
  final Color bg, surface, primary, primaryDark, accent, secondary, danger, success;
  final Color textPrimary, textSecondary, textMuted, textFaint, textGhost, divider;
  final Color onPrimary, onPrimarySecondary, onPrimaryMuted;

  const ColorPalette({
    required this.bg,
    required this.surface,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.secondary,
    required this.danger,
    required this.success,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.textGhost,
    required this.divider,
    this.onPrimary = const Color(0xFFFFFFFF),
    this.onPrimarySecondary = const Color(0xB3FFFFFF),
    this.onPrimaryMuted = const Color(0x8AFFFFFF),
  });
}

const kDarkPalette = ColorPalette(
  bg:          Color(0xFF0F0F10),
  surface:     Color(0xFF1A1A1D),
  primary:     Color(0xFF2563EB),
  primaryDark: Color(0xFF1D4ED8),
  accent:      Color(0xFF60A5FA),
  secondary:   Color(0xFFF8FAFC),
  danger:      Color(0xFFEF4444),
  success:     Color(0xFF22C55E),
  textPrimary:   Color(0xFFFFFFFF),
  textSecondary: Color(0xB3FFFFFF),
  textMuted:     Color(0x8AFFFFFF),
  textFaint:     Color(0x61FFFFFF),
  textGhost:     Color(0x3DFFFFFF),
  divider:       Color(0x1AFFFFFF),
);

const kLightPalette = ColorPalette(
  bg:          Color(0xFFF8FAFC),
  surface:     Color(0xFFFFFFFF),
  primary:     Color(0xFF2563EB),
  primaryDark: Color(0xFF1D4ED8),
  accent:      Color(0xFF60A5FA),
  secondary:   Color(0xFFF8FAFC),
  danger:      Color(0xFFEF4444),
  success:     Color(0xFF22C55E),
  textPrimary:   Color(0xFF0F0F10),
  textSecondary: Color(0xB30F0F10),
  textMuted:     Color(0x8A0F0F10),
  textFaint:     Color(0x610F0F10),
  textGhost:     Color(0x3D0F0F10),
  divider:       Color(0x1A0F0F10),
);

extension AppColorsX on BuildContext {
  ColorPalette get colors =>
      Theme.of(this).brightness == Brightness.dark ? kDarkPalette : kLightPalette;
}

abstract class DarkBlueColors {
  static const bg          = Color(0xFF0F0F10);
  static const surface     = Color(0xFF1A1A1D);
  static const primary     = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const accent      = Color(0xFF60A5FA);
  static const secondary   = Color(0xFFF8FAFC);
  static const danger      = Color(0xFFEF4444);
  static const success     = Color(0xFF22C55E);
}

abstract class LightBlueColors {
  static const bg          = Color(0xFFF8FAFC);
  static const surface     = Color(0xFFFFFFFF);
  static const primary     = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const accent      = Color(0xFF60A5FA);
  static const secondary   = Color(0xFF0F0F10);
  static const danger      = Color(0xFFEF4444);
  static const success     = Color(0xFF22C55E);
}