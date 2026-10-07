import 'package:appgastos/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  final now = DateTime(2026, 10, 6, 18);

  test('dayLabel names recent days', () {
    expect(Formatters.dayLabel(DateTime(2026, 10, 6, 1), now: now), 'Hoy');
    expect(Formatters.dayLabel(DateTime(2026, 10, 5, 23), now: now), 'Ayer');
  });

  test('dayLabel spells out older days', () {
    expect(
      Formatters.dayLabel(DateTime(2026, 9, 22), now: now),
      'Martes 22 de septiembre',
    );
    expect(
      Formatters.dayLabel(DateTime(2025, 12, 31), now: now),
      '31 de diciembre 2025',
    );
  });
}
