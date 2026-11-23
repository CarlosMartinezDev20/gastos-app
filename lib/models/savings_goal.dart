class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.progressPercent,
    this.targetDate,
  });

  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final String icon;
  final String bgColor;
  final String iconColor;
  final double progressPercent;

  /// The day the user wants to reach it by (local calendar date), if any.
  final DateTime? targetDate;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
    id: json['id'] as String,
    name: json['name'] as String,
    targetAmount: (json['targetAmount'] as num).toDouble(),
    savedAmount: (json['savedAmount'] as num).toDouble(),
    icon: json['icon'] as String,
    bgColor: json['bgColor'] as String,
    iconColor: json['iconColor'] as String,
    progressPercent: (json['progressPercent'] as num).toDouble(),
    targetDate: parseApiDay(json['targetDate'] as String?),
  );
}

/// `YYYY-MM-DD` (a calendar day, no time zone) → that local day.
DateTime? parseApiDay(String? value) {
  if (value == null || value.length < 10) return null;
  final parts = value.substring(0, 10).split('-').map(int.tryParse).toList();
  if (parts.length != 3 || parts.contains(null)) return null;
  return DateTime(parts[0]!, parts[1]!, parts[2]!);
}

/// A local day as the API's `YYYY-MM-DD`.
String apiDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
