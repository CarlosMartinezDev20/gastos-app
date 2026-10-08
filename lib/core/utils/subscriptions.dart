import 'dart:ui';

import '../../models/recurring.dart';
import 'formatters.dart';
import 'wallet.dart';

/// A service people subscribe to, drawn as an app-icon-like tile with its
/// colors and its mark (`brandMarks`) or, without one, a monogram.
class SubscriptionService {
  const SubscriptionService(
    this.key,
    this.name,
    this.group,
    this.monogram,
    this.colors, {
    this.frequency = RecurrenceFrequency.monthly,
  });

  /// Stored in the recurring rule's `service`.
  final String key;
  final String name;
  final String group;
  final String monogram;
  final List<Color> colors;

  /// How it is usually billed (the user can change it).
  final RecurrenceFrequency frequency;
}

/// Key for a subscription not in the catalog (the user names it).
const otherServiceKey = 'other';

/// Popular services, in picker order, grouped. Prices aren't included:
/// they vary by country and plan, so the user types theirs.
const subscriptionCatalog = <SubscriptionService>[
  SubscriptionService('chatgpt', 'ChatGPT', 'Inteligencia artificial', 'GPT', [
    Color(0xFF19C37D),
    Color(0xFF0B7A5E),
  ]),
  SubscriptionService('claude', 'Claude', 'Inteligencia artificial', 'C', [
    Color(0xFFE08A67),
    Color(0xFFB85C3D),
  ]),
  SubscriptionService('gemini', 'Gemini', 'Inteligencia artificial', 'G', [
    Color(0xFF4F8EF7),
    Color(0xFF9B72CB),
  ]),
  SubscriptionService(
    'copilot',
    'GitHub Copilot',
    'Inteligencia artificial',
    'GH',
    [Color(0xFF3B4048), Color(0xFF1B1F24)],
  ),
  SubscriptionService(
    'perplexity',
    'Perplexity',
    'Inteligencia artificial',
    'P',
    [Color(0xFF2A9AA6), Color(0xFF13545C)],
  ),
  SubscriptionService('cursor', 'Cursor', 'Inteligencia artificial', 'Cu', [
    Color(0xFF3A3A3C),
    Color(0xFF0A0A0A),
  ]),
  SubscriptionService('spotify', 'Spotify', 'Música', 'S', [
    Color(0xFF1ED760),
    Color(0xFF128A3E),
  ]),
  SubscriptionService('applemusic', 'Apple Music', 'Música', 'AM', [
    Color(0xFFFC5C7D),
    Color(0xFFE0243F),
  ]),
  SubscriptionService('youtube', 'YouTube Premium', 'Música', 'YT', [
    Color(0xFFFF3B4F),
    Color(0xFFC4001D),
  ]),
  SubscriptionService('deezer', 'Deezer', 'Música', 'Dz', [
    Color(0xFFB45CFF),
    Color(0xFF7A1FD1),
  ]),
  SubscriptionService('netflix', 'Netflix', 'Video', 'N', [
    Color(0xFFE50914),
    Color(0xFF7A050B),
  ]),
  SubscriptionService('disney', 'Disney+', 'Video', 'D+', [
    Color(0xFF1F4FE0),
    Color(0xFF0B2580),
  ]),
  SubscriptionService('max', 'HBO Max', 'Video', 'MAX', [
    Color(0xFF5B3CF5),
    Color(0xFF1B0C7A),
  ]),
  SubscriptionService('crunchyroll', 'Crunchyroll', 'Video', 'CR', [
    Color(0xFFFF8A3D),
    Color(0xFFE85000),
  ]),
  SubscriptionService('paramountplus', 'Paramount+', 'Video', 'P+', [
    Color(0xFF3D86FF),
    Color(0xFF0050D6),
  ]),
  SubscriptionService('appletv', 'Apple TV+', 'Video', 'tv', [
    Color(0xFF3A3A3C),
    Color(0xFF111111),
  ]),
  SubscriptionService('prime', 'Prime Video', 'Video', 'P', [
    Color(0xFF1FB6EA),
    Color(0xFF0071A1),
  ]),
  SubscriptionService('icloud', 'iCloud+', 'Nube', 'iC', [
    Color(0xFF5AB0FF),
    Color(0xFF1C6EE0),
  ]),
  SubscriptionService('googleone', 'Google One', 'Nube', '1', [
    Color(0xFF4CC26E),
    Color(0xFF1E7E3A),
  ]),
  SubscriptionService('dropbox', 'Dropbox', 'Nube', 'Db', [
    Color(0xFF3D8BFF),
    Color(0xFF0050D9),
  ]),
  SubscriptionService('xbox', 'Xbox Game Pass', 'Juegos', 'X', [
    Color(0xFF2EA043),
    Color(0xFF0B5A0B),
  ]),
  SubscriptionService('discord', 'Discord Nitro', 'Juegos', 'D', [
    Color(0xFF7983F5),
    Color(0xFF4752C4),
  ]),
  SubscriptionService(
    'playstation',
    'PlayStation Plus',
    'Juegos',
    'PS',
    [Color(0xFF2B8BE6), Color(0xFF003791)],
    frequency: RecurrenceFrequency.yearly,
  ),
  SubscriptionService(
    'nintendo',
    'Nintendo Switch Online',
    'Juegos',
    'N',
    [Color(0xFFFF4554), Color(0xFFC20010)],
    frequency: RecurrenceFrequency.yearly,
  ),
  SubscriptionService('canva', 'Canva', 'Productividad', 'C', [
    Color(0xFF00C4CC),
    Color(0xFF7D2AE8),
  ]),
  SubscriptionService('notion', 'Notion', 'Productividad', 'N', [
    Color(0xFF4A4A4A),
    Color(0xFF111111),
  ]),
  SubscriptionService('figma', 'Figma', 'Productividad', 'F', [
    Color(0xFFFF7262),
    Color(0xFFD93A12),
  ]),
  SubscriptionService(
    'microsoft365',
    'Microsoft 365',
    'Productividad',
    'M',
    [Color(0xFFF2633A), Color(0xFFB7472A)],
    frequency: RecurrenceFrequency.yearly,
  ),
  SubscriptionService('adobe', 'Adobe', 'Productividad', 'A', [
    Color(0xFFFF4B4B),
    Color(0xFFB30000),
  ]),
  SubscriptionService('duolingo', 'Duolingo', 'Productividad', 'D', [
    Color(0xFF7ED957),
    Color(0xFF46A302),
  ], frequency: RecurrenceFrequency.yearly),
  SubscriptionService('gym', 'Gimnasio', 'Otros', 'GYM', [
    Color(0xFFFF9F0A),
    Color(0xFFD9480F),
  ]),
  SubscriptionService('phone', 'Plan de celular', 'Otros', 'TEL', [
    Color(0xFF8E8E93),
    Color(0xFF48484A),
  ]),
];

/// The catalog entry of [key], or null for "other" and unknown keys.
SubscriptionService? serviceFor(String? key) =>
    subscriptionCatalog.where((s) => s.key == key).firstOrNull;

/// Up to three letters from a name: "Mi Gimnasio" → "MG".
String monogramFor(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return w.substring(0, w.length < 2 ? w.length : 2).toUpperCase();
  }
  return words.take(3).map((w) => w[0]).join().toUpperCase();
}

/// Colors for a service outside the catalog, stable for its name.
List<Color> colorsFor(String name) {
  const palettes = [
    [Color(0xFF8E7CF0), Color(0xFF5B48C8)],
    [Color(0xFFFF8A65), Color(0xFFE0533A)],
    [Color(0xFF4DB6AC), Color(0xFF00796B)],
    [Color(0xFFF06292), Color(0xFFC2185B)],
    [Color(0xFF64B5F6), Color(0xFF1E64C8)],
    [Color(0xFFFFB74D), Color(0xFFE08600)],
  ];
  final hash = name.toLowerCase().codeUnits.fold(0, (h, c) => h * 31 + c);
  return palettes[hash.abs() % palettes.length];
}

/// Active subscriptions' cost per month (weekly and yearly normalized).
double monthlySubscriptionCost(List<RecurringRule> subscriptions) =>
    subscriptions
        .where((s) => s.active)
        .fold(0.0, (sum, s) => sum + s.monthlyCost);

/// Active subscriptions by their next charge, soonest first.
List<RecurringRule> upcomingCharges(List<RecurringRule> subscriptions) =>
    subscriptions.where((s) => s.active).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

/// "Cobra hoy", "Mañana", "En 5 días" or "15 oct".
String chargeLabel(DateTime next, {DateTime? now}) {
  final days = daysUntil(next.toLocal(), now ?? DateTime.now());
  if (days <= 0) return 'Cobra hoy';
  if (days == 1) return 'Mañana';
  if (days < 8) return 'En $days días';
  return Formatters.shortDate.format(next.toLocal());
}
