import 'package:flutter/material.dart';

/// Semantic surfaces and foregrounds. Read with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.ink,
    required this.onInk,
    required this.inkMuted,
    required this.accent,
    required this.onAccent,
    required this.mint,
    required this.onMint,
    required this.blush,
    required this.onBlush,
    required this.lilac,
    required this.onLilac,
    required this.card,
    required this.thumb,
    required this.hairline,
    required this.muted,
    required this.pill,
    required this.onPill,
    required this.chartIncome,
    required this.chartExpense,
  });

  /// Dark summary surfaces (goals, efficiency, expense card).
  final Color ink;
  final Color onInk;
  final Color inkMuted;

  /// Lime accent for highlights, progress and income; [onAccent] on top.
  final Color accent;
  final Color onAccent;

  /// Income tiles.
  final Color mint;
  final Color onMint;

  /// Expense tiles.
  final Color blush;
  final Color onBlush;

  /// Savings tiles.
  final Color lilac;
  final Color onLilac;

  /// Plain cards on the page background.
  final Color card;

  /// The selected segment of a segmented control: lighter than its track in
  /// both modes (the card color is darker than the track in dark mode).
  final Color thumb;
  final Color hairline;
  final Color muted;

  /// Primary action backgrounds and foregrounds.
  final Color pill;
  final Color onPill;

  /// Cash-flow chart series (checked for color-blind separation and 3:1
  /// contrast against the card in each mode).
  final Color chartIncome;
  final Color chartExpense;

  static const light = AppPalette(
    ink: Color(0xFF1C1C1E),
    onInk: Color(0xFFF7F7F8),
    inkMuted: Color(0xFFA1A1A8),
    accent: Color(0xFFC8F04B),
    onAccent: Color(0xFF1A2006),
    mint: Color(0xFFEDF8CC),
    onMint: Color(0xFF3B5100),
    blush: Color(0xFFFBD9DB),
    onBlush: Color(0xFF773A43),
    lilac: Color(0xFFE2DDFF),
    onLilac: Color(0xFF514578),
    card: Colors.white,
    thumb: Colors.white,
    hairline: Color(0xFFECECEE),
    muted: Color(0xFF64646D),
    pill: Color(0xFF202122),
    onPill: Colors.white,
    chartIncome: Color(0xFF3FA45B),
    chartExpense: Color(0xFF4A93D9),
  );

  static const dark = AppPalette(
    ink: Color(0xFF2A2B2E),
    onInk: Color(0xFFF7F7F8),
    inkMuted: Color(0xFFA1A1A8),
    accent: Color(0xFFC8F04B),
    onAccent: Color(0xFF1A2006),
    mint: Color(0xFF2E3A12),
    onMint: Color(0xFFD7F28A),
    blush: Color(0xFF452E35),
    onBlush: Color(0xFFF1BFC7),
    lilac: Color(0xFF353047),
    onLilac: Color(0xFFD4CBFF),
    card: Color(0xFF212224),
    thumb: Color(0xFF545558),
    hairline: Color(0xFF353638),
    muted: Color(0xFFB4B5BB),
    pill: Color(0xFFEDEEF0),
    onPill: Color(0xFF202122),
    chartIncome: Color(0xFF43A35D),
    chartExpense: Color(0xFF4E97DE),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      ink: c(ink, other.ink),
      onInk: c(onInk, other.onInk),
      inkMuted: c(inkMuted, other.inkMuted),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      mint: c(mint, other.mint),
      onMint: c(onMint, other.onMint),
      blush: c(blush, other.blush),
      onBlush: c(onBlush, other.onBlush),
      lilac: c(lilac, other.lilac),
      onLilac: c(onLilac, other.onLilac),
      card: c(card, other.card),
      thumb: c(thumb, other.thumb),
      hairline: c(hairline, other.hairline),
      muted: c(muted, other.muted),
      pill: c(pill, other.pill),
      onPill: c(onPill, other.onPill),
      chartIncome: c(chartIncome, other.chartIncome),
      chartExpense: c(chartExpense, other.chartExpense),
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
