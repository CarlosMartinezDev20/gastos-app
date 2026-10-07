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

  String get message {
    if (totalIncome == 0) return 'Registra ingresos para medir tu eficiencia.';
    if (efficiencyPercent >= 25) return 'Excelente ritmo de ahorro.';
    if (efficiencyPercent >= 10) {
      return 'Vas bien, tu ahorro está tomando forma.';
    }
    if (totalSaved == 0) {
      return 'Aporta a una meta para empezar a medir tu ahorro.';
    }
    return 'Pequeños aportes constantes pueden subir tu eficiencia.';
  }

  factory SavingsEfficiency.fromJson(Map<String, dynamic> json) =>
      SavingsEfficiency(
        totalIncome: (json['totalIncome'] as num).toDouble(),
        totalSaved: (json['totalSaved'] as num).toDouble(),
        efficiencyPercent: (json['efficiencyPercent'] as num).toDouble(),
      );
}
