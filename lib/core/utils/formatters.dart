import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final money = NumberFormat.currency(locale: 'es_US', symbol: r'$');
  static final shortDate = DateFormat('dd MMM', 'es');
  static final fullDate = DateFormat('dd/MM/yyyy', 'es');
  static final dayMonthYear = DateFormat('d MMM y', 'es');
  static final monthYear = DateFormat('MMMM y', 'es');

  static String compactMoney(num value) => money.format(value);

  /// Short amounts for chart axes: "$20", "$2.50", "$1.5k".
  static String axisMoney(num value) {
    if (value >= 1000) {
      final thousands = value / 1000;
      return '\$${thousands == thousands.roundToDouble() ? thousands.toStringAsFixed(0) : thousands.toStringAsFixed(1)}k';
    }
    return value == value.roundToDouble()
        ? '\$${value.toStringAsFixed(0)}'
        : '\$${value.toStringAsFixed(2)}';
  }

  static String dateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${start.day}–${DateFormat('d MMM y', 'es').format(end)}';
    }
    final pattern = start.year == end.year ? 'd MMM' : 'd MMM y';
    return '${DateFormat(pattern, 'es').format(start)} – '
        '${DateFormat('d MMM y', 'es').format(end)}';
  }

  /// "Hoy", "Ayer", "Martes 22 de septiembre" this year, or
  /// "22 de septiembre 2025" before.
  static String dayLabel(DateTime date, {DateTime? now}) {
    now ??= DateTime.now();
    // Calendar days in UTC, so a daylight-saving change can't shift them.
    final day = DateTime.utc(date.year, date.month, date.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    final pattern = date.year == now.year
        ? "EEEE d 'de' MMMM"
        : "d 'de' MMMM y";
    return toBeginningOfSentenceCase(DateFormat(pattern, 'es').format(date));
  }
}
