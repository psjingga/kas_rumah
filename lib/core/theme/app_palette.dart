import 'package:flutter/material.dart';

/// Token warna desain "hangat & modern" (lihat `.superdesign/design-system.md`).
///
/// Dipasang sebagai [ThemeExtension] agar widget bisa memakai warna yang tidak
/// ada di [ColorScheme] (latar lembut, warna "soft" untuk ikon, gradasi hero).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.ink,
    required this.inkMuted,
    required this.primary,
    required this.primarySoft,
    required this.heroStart,
    required this.heroEnd,
    required this.income,
    required this.incomeSoft,
    required this.expense,
    required this.expenseSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
    required this.shadow,
  });

  final Color bg;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color ink;
  final Color inkMuted;
  final Color primary;
  final Color primarySoft;
  final Color heroStart;
  final Color heroEnd;
  final Color income;
  final Color incomeSoft;
  final Color expense;
  final Color expenseSoft;
  final Color warning;
  final Color warningSoft;
  final Color info;
  final Color infoSoft;

  /// Bayangan kartu; transparan di mode gelap (kartu memakai garis tepi).
  final Color shadow;

  static const light = AppPalette(
    bg: Color(0xFFFBF6EF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4ECE2),
    border: Color(0xFFEADFD2),
    ink: Color(0xFF2B211A),
    inkMuted: Color(0xFF7A6A5D),
    primary: Color(0xFFE8873A),
    primarySoft: Color(0xFFFCE7D3),
    heroStart: Color(0xFFE8873A),
    heroEnd: Color(0xFFF29A50),
    income: Color(0xFF2F9E6B),
    incomeSoft: Color(0xFFDDF2E7),
    expense: Color(0xFFD9534F),
    expenseSoft: Color(0xFFFBE1DF),
    warning: Color(0xFFE0A100),
    warningSoft: Color(0xFFFFF1C7),
    info: Color(0xFF3A86C8),
    infoSoft: Color(0xFFDDEBF7),
    shadow: Color(0x0F3A2A22),
  );

  static const dark = AppPalette(
    bg: Color(0xFF17120F),
    surface: Color(0xFF221B17),
    surfaceMuted: Color(0xFF2E251F),
    border: Color(0xFF3A2F27),
    ink: Color(0xFFF6EEE6),
    inkMuted: Color(0xFFB4A497),
    primary: Color(0xFFF29A50),
    primarySoft: Color(0xFF4A2F1C),
    heroStart: Color(0xFFB8642A),
    heroEnd: Color(0xFFD07A3C),
    income: Color(0xFF5CC592),
    incomeSoft: Color(0xFF1E3A2C),
    expense: Color(0xFFF08A85),
    expenseSoft: Color(0xFF45231F),
    warning: Color(0xFFF2C14E),
    warningSoft: Color(0xFF453714),
    info: Color(0xFF7DB5E6),
    infoSoft: Color(0xFF1D3245),
    shadow: Color(0x00000000),
  );

  LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroStart, heroEnd],
  );

  /// Bayangan lembut untuk kartu putih (kosong di mode gelap).
  List<BoxShadow> get cardShadow => shadow.a == 0
      ? const []
      : [BoxShadow(color: shadow, blurRadius: 10, offset: const Offset(0, 2))];

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      border: l(border, other.border),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      primary: l(primary, other.primary),
      primarySoft: l(primarySoft, other.primarySoft),
      heroStart: l(heroStart, other.heroStart),
      heroEnd: l(heroEnd, other.heroEnd),
      income: l(income, other.income),
      incomeSoft: l(incomeSoft, other.incomeSoft),
      expense: l(expense, other.expense),
      expenseSoft: l(expenseSoft, other.expenseSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppPalette.dark
          : AppPalette.light);
}
