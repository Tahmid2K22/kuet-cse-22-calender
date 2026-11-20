import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/event_type.dart';

/// Core palette: a deep green brand with white surfaces.
///
/// Event colours follow the six requested categories. Each category has a
/// soft colour (dots, tinted backgrounds) and a stronger variant (rings, card
/// accents, badge text) so light pastels stay readable on white.
abstract final class AppColors {
  // Brand.
  static const Color primary = Color(0xFF146B45);
  static const Color primaryDark = Color(0xFF0E5235);
  static const Color primaryTint = Color(0xFFE7F4EC);

  static const Color ink = Color(0xFF15251C);
  static const Color inkMuted = Color(0xFF64786B);
  static const Color background = Color(0xFFF6FBF8);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFDDECE3);

  // Event types (sampled from the requested palette).
  static const Color deadline = Color(0xFFF28C8C);
  static const Color exam = Color(0xFFE6D44F);
  static const Color classSession = Color(0xFFC9DDF8);
  static const Color meeting = Color(0xFFC9D1F4);
  static const Color holiday = Color(0xFF4CAF7D);
  static const Color event = Color(0xFFF3C6E3);

  // Stronger variants for rings, accent bars and text.
  static const Color deadlineStrong = Color(0xFFC45555);
  static const Color examStrong = Color(0xFF9C8A12);
  static const Color classSessionStrong = Color(0xFF4C82BE);
  static const Color meetingStrong = Color(0xFF6673C4);
  static const Color holidayStrong = Color(0xFF2F855A);
  static const Color eventStrong = Color(0xFFC06A9E);

  static const Color danger = Color(0xFFB3261E);
  static const Color warning = Color(0xFFB45309);
  static const Color warningTint = Color(0xFFFFF7ED);
}

/// Single source of truth for the event type -> colour mapping.
///
/// Widgets never hard-code a colour per event or per date; they ask this class
/// for the colour of an [EventType]. Unknown sheet types are normalised to
/// [EventType.deadline] in the model layer, so they render red automatically.
abstract final class EventPalette {
  /// Soft colour used for dots and tinted backgrounds.
  static Color colorOf(EventType type) => switch (type) {
    EventType.deadline => AppColors.deadline,
    EventType.exam => AppColors.exam,
    EventType.classSession => AppColors.classSession,
    EventType.meeting => AppColors.meeting,
    EventType.holiday => AppColors.holiday,
    EventType.event => AppColors.event,
  };

  /// High-contrast variant used for accent bars and badge text.
  static Color strongColorOf(EventType type) => switch (type) {
    EventType.deadline => AppColors.deadlineStrong,
    EventType.exam => AppColors.examStrong,
    EventType.classSession => AppColors.classSessionStrong,
    EventType.meeting => AppColors.meetingStrong,
    EventType.holiday => AppColors.holidayStrong,
    EventType.event => AppColors.eventStrong,
  };

  /// Ring/dot colour: the requested colour, deepened just enough to stay
  /// visible on white while keeping the original hue.
  static Color ringColorOf(EventType type) =>
      Color.lerp(colorOf(type), strongColorOf(type), 0.3)!;
}

abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          outlineVariant: AppColors.border,
          error: AppColors.danger,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          letterSpacing: -0.3,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
