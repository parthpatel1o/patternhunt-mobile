import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF8F6FA);
  static const foreground = Color(0xFF1A1A1A);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFEAE4EF);
  /// Lavender fill only — never use as text/icon/outline on white surfaces.
  static const primary = Color(0xFFF0D7FF);
  static const primaryStrong = Color(0xFFE8C4FF);
  static const primaryForeground = Color(0xFF3D2F4A);
  /// Dark purple for interactive accents on light backgrounds.
  static const accent = Color(0xFF3D2F4A);
  static const accentForeground = Color(0xFFFFFFFF);
  static const destructive = Color(0xFFB85C4A);
  static const muted = Color(0x991A1A1A);
  static const rank1Bg = Color(0xFFEBE0F4);
  static const rank2Bg = Color(0xFFF2EBF9);
  static const rank3Bg = Color(0xFFF8F4FC);
  static const rank1Border = Color(0xFF3D2F4A);
  static const rank2Border = Color(0xFF6B5A7D);
  static const rank3Border = Color(0xFFA898B8);
}

/// Card shadows matching web `globals.css` `--shadow` / `--shadow-rank-*`.
class AppShadows {
  static const _ink = Color(0xFF3D2F4A);

  static List<BoxShadow> get card => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.22),
          blurRadius: 20,
          offset: const Offset(0, 6),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: _ink.withValues(alpha: 0.08),
          blurRadius: 6,
          offset: const Offset(0, 2),
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get rank1 => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.4),
          blurRadius: 32,
          offset: const Offset(0, 12),
          spreadRadius: -8,
        ),
        BoxShadow(
          color: _ink.withValues(alpha: 0.18),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: -3,
        ),
      ];

  static List<BoxShadow> get rank2 => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.34),
          blurRadius: 28,
          offset: const Offset(0, 10),
          spreadRadius: -8,
        ),
        BoxShadow(
          color: _ink.withValues(alpha: 0.14),
          blurRadius: 10,
          offset: const Offset(0, 3),
          spreadRadius: -3,
        ),
      ];

  static List<BoxShadow> get rank3 => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.28),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -7,
        ),
        BoxShadow(
          color: _ink.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(0, 3),
          spreadRadius: -2,
        ),
      ];
}
