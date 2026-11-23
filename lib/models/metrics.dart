class CategoryExpense {
  const CategoryExpense({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.total,
    required this.percentage,
  });

  final String categoryId;
  final String categoryName;
  final String icon;
  final double total;
  final double percentage;

  factory CategoryExpense.fromJson(Map<String, dynamic> json) =>
      CategoryExpense(
        categoryId: json['categoryId'] as String,
        categoryName: json['categoryName'] as String,
        icon: json['icon'] as String,
        total: (json['total'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class SavingsEfficiency {
  const SavingsEfficiency({
    required this.totalIncome,
    required this.totalSaved,
    required this.efficiencyPercent,
  });

  final double totalIncome;
  final double totalSaved;
  final double efficiencyPercent;

  /// Only goal contributions count as saved (money left in the balance
  /// doesn't), so the copy talks about goals, not about saving in general.
  String get message {
    if (totalIncome == 0) return 'Registra ingresos para ver cuánto apartas.';
    if (efficiencyPercent >= 25) return 'Excelente: apartas buena parte.';
    if (efficiencyPercent >= 10) {
      return 'Vas bien, tus metas están tomando forma.';
    }
    if (totalSaved == 0) {
      return 'Aparta parte de tu balance en una meta y lo verás aquí.';
    }
    return 'Pequeños aportes constantes suben este porcentaje.';
  }

  factory SavingsEfficiency.fromJson(Map<String, dynamic> json) =>
      SavingsEfficiency(
        totalIncome: (json['totalIncome'] as num).toDouble(),
        totalSaved: (json['totalSaved'] as num).toDouble(),
        efficiencyPercent: (json['efficiencyPercent'] as num).toDouble(),
      );
}
