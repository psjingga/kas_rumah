import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Radius standar desain (kartu 20, kotak dalam 14, ikon 12, hero 24).
abstract final class AppRadius {
  static const card = 20.0;
  static const hero = 24.0;
  static const box = 14.0;
  static const icon = 12.0;
  static const sheet = 28.0;
}

/// Tema aplikasi "hangat & modern": latar krem, kartu putih membulat,
/// satu aksen oranye madu, font Plus Jakarta Sans.
ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? AppPalette.dark : AppPalette.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: dark ? const Color(0xFF2B1608) : Colors.white,
    primaryContainer: p.primarySoft,
    onPrimaryContainer: dark
        ? const Color(0xFFFCE7D3)
        : const Color(0xFF7A3E0E),
    secondary: p.inkMuted,
    onSecondary: p.surface,
    secondaryContainer: p.primarySoft,
    onSecondaryContainer: dark
        ? const Color(0xFFFCE7D3)
        : const Color(0xFF7A3E0E),
    tertiary: p.info,
    onTertiary: Colors.white,
    tertiaryContainer: p.infoSoft,
    onTertiaryContainer: p.ink,
    error: p.expense,
    onError: Colors.white,
    errorContainer: p.expenseSoft,
    onErrorContainer: dark ? const Color(0xFFFBE1DF) : const Color(0xFF8C2420),
    surface: p.bg,
    onSurface: p.ink,
    onSurfaceVariant: p.inkMuted,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceMuted,
    surfaceContainerHighest: p.surfaceMuted,
    outline: dark ? const Color(0xFF6E6055) : const Color(0xFFB8A898),
    outlineVariant: p.border,
    inverseSurface: p.ink,
    onInverseSurface: p.bg,
    inversePrimary: p.primarySoft,
    shadow: const Color(0xFF3A2A22),
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: p.bg,
  );
  final text = base.textTheme;
  const pill = StadiumBorder();
  RoundedRectangleBorder rounded(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  return base.copyWith(
    extensions: [p],
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      bodySmall: text.bodySmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: p.inkMuted,
      ),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: p.ink,
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      // Datar + garis tepi tipis hangat (bayangan elevation M3 terlalu
      // gelap untuk latar krem).
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: dark ? p.border : const Color(0xFFF1E7DB)),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.box),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.box),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.box),
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.box),
        borderSide: BorderSide(color: p.expense),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.box),
        borderSide: BorderSide(color: p.expense, width: 1.5),
      ),
      labelStyle: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(
        color: p.primary,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: p.inkMuted,
      suffixIconColor: p.inkMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, 48),
        foregroundColor: p.ink,
        side: BorderSide(color: p.border, width: 1.5),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        shape: pill,
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      highlightElevation: 3,
      shape: pill,
      extendedTextStyle: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.primarySoft,
      elevation: 0,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? p.primary : p.inkMuted,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? p.primary : p.inkMuted,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.primary,
      unselectedLabelColor: p.inkMuted,
      indicatorColor: p.primary,
      dividerColor: p.border,
      labelStyle: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w700,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: p.surfaceMuted,
      selectedColor: p.primary,
      secondarySelectedColor: p.primary,
      side: BorderSide.none,
      shape: pill,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w700,
        color: scheme.onPrimary,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(pill),
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : p.ink,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : p.ink,
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : p.inkMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.surfaceMuted,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.border,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primary,
      linearTrackColor: p.surfaceMuted,
      circularTrackColor: p.surfaceMuted,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.inkMuted,
      titleTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: p.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: p.inkMuted,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: p.border,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(AppRadius.hero),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w500,
        color: p.bg,
      ),
      actionTextColor: dark ? p.primary : p.primarySoft,
      shape: rounded(AppRadius.box),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(AppRadius.box),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(AppRadius.hero),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: p.surface,
      shape: rounded(AppRadius.hero),
    ),
  );
}
