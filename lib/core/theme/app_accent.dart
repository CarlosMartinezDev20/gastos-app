import 'package:flutter/painting.dart';

/// The accent the user picks in Perfil → Apariencia. It tints the brand
/// highlights (accent fills, the dock's + and lens, switches, progress,
/// tinted tiles, the phone widget and the launcher icon); income stays green
/// in every accent so it never reads as a goal or an expense.
///
/// The values come from `branding/temas` (OKLCH, same hue as the accent):
/// text on [mintLight]/[mintDark] and on [accent] keeps at least 7:1, and
/// [widgetMuted] at least 4.5:1 on [accent].
enum AppAccent {
  lima(
    apiValue: 'LIME',
    label: 'Lima',
    iconName: null,
    accent: Color(0xFFC8F04B),
    onAccent: Color(0xFF1A2006),
    mintLight: Color(0xFFEDF8CC),
    onMintLight: Color(0xFF3B5100),
    mintDark: Color(0xFF2E3A12),
    onMintDark: Color(0xFFD7F28A),
    widgetHighlightLight: Color(0xFF8DBF1F),
    widgetMuted: Color(0xFF4A5A1C),
  ),
  menta(
    apiValue: 'MINT',
    label: 'Menta',
    iconName: 'Menta',
    accent: Color(0xFF5BE3AE),
    onAccent: Color(0xFF012619),
    mintLight: Color(0xFFD5FAE8),
    onMintLight: Color(0xFF045C40),
    mintDark: Color(0xFF103929),
    onMintDark: Color(0xFF9EF3CD),
    widgetHighlightLight: Color(0xFF19C18C),
    widgetMuted: Color(0xFF1B5D44),
  ),
  cielo(
    apiValue: 'SKY',
    label: 'Cielo',
    iconName: 'Cielo',
    accent: Color(0xFF7CC4FF),
    onAccent: Color(0xFF002139),
    mintLight: Color(0xFFE5F2FE),
    onMintLight: Color(0xFF09517F),
    mintDark: Color(0xFF1D3344),
    onMintDark: Color(0xFFC2E3FF),
    widgetHighlightLight: Color(0xFF60ACE9),
    widgetMuted: Color(0xFF2C4E69),
  ),
  violeta(
    apiValue: 'VIOLET',
    label: 'Violeta',
    iconName: 'Violeta',
    accent: Color(0xFFB7A4FF),
    onAccent: Color(0xFF211939),
    mintLight: Color(0xFFF0EEFF),
    onMintLight: Color(0xFF503E86),
    mintDark: Color(0xFF312B47),
    onMintDark: Color(0xFFDED8FF),
    widgetHighlightLight: Color(0xFFA893F2),
    widgetMuted: Color(0xFF443B65),
  ),
  ambar(
    apiValue: 'AMBER',
    label: 'Ámbar',
    iconName: 'Ambar',
    accent: Color(0xFFFFC53D),
    onAccent: Color(0xFF2A1D01),
    mintLight: Color(0xFFFFEECE),
    onMintLight: Color(0xFF634800),
    mintDark: Color(0xFF3E2D04),
    onMintDark: Color(0xFFFFD98C),
    widgetHighlightLight: Color(0xFFCF9B04),
    widgetMuted: Color(0xFF664B04),
  );

  const AppAccent({
    required this.apiValue,
    required this.label,
    required this.iconName,
    required this.accent,
    required this.onAccent,
    required this.mintLight,
    required this.onMintLight,
    required this.mintDark,
    required this.onMintDark,
    required this.widgetHighlightLight,
    required this.widgetMuted,
  });

  /// The API's value (`User.accent`).
  final String apiValue;
  final String label;

  /// The alternate launcher icon (Android activity-alias suffix, iOS
  /// `AppIcon-<name>`); null is the default icon.
  final String? iconName;

  final Color accent;
  final Color onAccent;
  final Color mintLight;
  final Color onMintLight;
  final Color mintDark;
  final Color onMintDark;

  /// The phone widget's bars on its white theme.
  final Color widgetHighlightLight;

  /// The phone widget's secondary text on [accent].
  final Color widgetMuted;

  static AppAccent fromApi(String? value) =>
      values.firstWhere((a) => a.apiValue == value, orElse: () => lima);

  static AppAccent fromName(String? name) =>
      values.firstWhere((a) => a.name == name, orElse: () => lima);
}
