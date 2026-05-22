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
  });

  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final String icon;
  final String bgColor;
  final String iconColor;
  final double progressPercent;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
    id: json['id'] as String,
    name: json['name'] as String,
    targetAmount: (json['targetAmount'] as num).toDouble(),
    savedAmount: (json['savedAmount'] as num).toDouble(),
    icon: json['icon'] as String,
    bgColor: json['bgColor'] as String,
    iconColor: json['iconColor'] as String,
    progressPercent: (json['progressPercent'] as num).toDouble(),
  );
}
