import 'package:appgastos/core/utils/csv_export.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  test('exports signed amounts, escapes cells and adds a BOM', () {
    final csv = transactionsToCsv([
      Transaction(
        id: '1',
        title: 'Almuerzo, "menú"',
        amount: 8.5,
        type: TransactionType.expense,
        date: DateTime(2026, 9, 22, 12),
        category: food,
      ),
      Transaction(
        id: '2',
        title: 'Tutorías',
        amount: 200,
        type: TransactionType.income,
        date: DateTime(2026, 9, 20, 12),
        category: salary,
      ),
      Transaction(
        id: '3',
        title: 'Retiro: Laptop',
        amount: -20,
        type: TransactionType.expense,
        date: DateTime(2026, 9, 25, 12),
        category: savingsCategory,
        goalId: 'g1',
      ),
    ]);
    expect(csv.startsWith('﻿'), isTrue);
    expect(csv.substring(1).split('\r\n'), [
      'Fecha,Descripción,Categoría,Tipo,Monto',
      '2026-09-22,"Almuerzo, ""menú""",Comida,Gasto,-8.50',
      '2026-09-20,Tutorías,Trabajo,Ingreso,200.00',
      '2026-09-25,Retiro: Laptop,Ahorro,Retiro de meta,20.00',
      '',
    ]);
    expect(csvFileName(DateTime(2026, 10, 3)), 'movimientos-2026-10-03.csv');
  });
}
