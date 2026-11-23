import 'package:flutter/material.dart';

import 'app_accent.dart';

/// Semantic surfaces and foregrounds. Read with `context.palette`.
///
/// Neutrals follow Apple's system colors (grouped backgrounds, gray fills,
/// separators; true black behind the cards in dark mode); the brand keeps its
/// lime accent, black ink cards and pastel tiles on top of them.
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
    required this.separator,
    required this.muted,
    required this.pill,
    required this.onPill,
    required this.chartIncome,
    required this.chartExpense,
    required this.chartWants,
    required this.positive,
    required this.fill,
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

  /// Borders around cards and controls.
  final Color hairline;

  /// Thin list separators (iOS `separator`), drawn at [separatorWidth].
  final Color separator;
  final Color muted;

  /// Primary action backgrounds and foregrounds.
  final Color pill;
  final Color onPill;

  /// Cash-flow chart series, in the brand's lime and ink: each has 3:1
  /// contrast against the card and they differ in lightness, so they stay
  /// apart for color-blind eyes (light: deep lime vs ink; dark: lime vs grey).
  final Color chartIncome;
  final Color chartExpense;

  /// Third series (the budget split's "gustos"): a lilac with 3:1 against
  /// the card whose hue keeps it apart from the other two.
  final Color chartWants;

  /// Money coming in, as text (amounts in lists): a deep lime on light
  /// backgrounds (4.5:1 on white), the lime itself on dark ones.
  final Color positive;

  /// iOS's tertiary system fill: secondary buttons, search fields and
  /// tracks drawn on a card.
  final Color fill;

  /// An iOS hairline: thinner than one logical pixel.
  static const separatorWidth = .5;

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
    hairline: Color(0xFFE5E5EA),
    separator: Color(0xFFC6C6C8),
    // iOS secondaryLabel, a touch darker to keep 4.5:1 on the grouped grey.
    muted: Color(0xFF6C6C70),
    pill: Color(0xFF202122),
    onPill: Colors.white,
    chartIncome: Color(0xFF6E9600),
    chartExpense: Color(0xFF1C1C1E),
    chartWants: Color(0xFF7C6FD0),
    positive: Color(0xFF3E7A00),
    fill: Color(0x1F767680),
  );

  static const dark = AppPalette(
    ink: Color(0xFF2C2C2E),
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
    card: Color(0xFF1C1C1E),
    thumb: Color(0xFF636366),
    hairline: Color(0xFF2C2C2E),
    separator: Color(0xFF38383A),
    muted: Color(0xFFB4B5BB),
    pill: Color(0xFFEDEEF0),
    onPill: Color(0xFF202122),
    chartIncome: Color(0xFFC8F04B),
    chartExpense: Color(0xFF8E8E93),
    chartWants: Color(0xFFB3A8FF),
    positive: Color(0xFFC8F04B),
    fill: Color(0x3D767680),
  );

  /// This palette tinted with [a]: the accent fills and the mint tiles
  /// follow it; everything else (income green included) stays.
  AppPalette withAccent(AppAccent a, {required bool dark}) => AppPalette(
    ink: ink,
    onInk: onInk,
    inkMuted: inkMuted,
    accent: a.accent,
    onAccent: a.onAccent,
    mint: dark ? a.mintDark : a.mintLight,
    onMint: dark ? a.onMintDark : a.onMintLight,
    blush: blush,
    onBlush: onBlush,
    lilac: lilac,
    onLilac: onLilac,
    card: card,
    thumb: thumb,
    hairline: hairline,
    separator: separator,
    muted: muted,
    pill: pill,
    onPill: onPill,
    chartIncome: chartIncome,
    chartExpense: chartExpense,
    chartWants: chartWants,
    positive: positive,
    fill: fill,
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
      separator: c(separator, other.separator),
      muted: c(muted, other.muted),
      pill: c(pill, other.pill),
      onPill: c(onPill, other.onPill),
      chartIncome: c(chartIncome, other.chartIncome),
      chartExpense: c(chartExpense, other.chartExpense),
      chartWants: c(chartWants, other.chartWants),
      positive: c(positive, other.positive),
      fill: c(fill, other.fill),
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
