import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final money = NumberFormat.currency(locale: 'es_US', symbol: r'$');
  static final shortDate = DateFormat('dd MMM', 'es');
  static final fullDate = DateFormat('dd/MM/yyyy', 'es');

  static String compactMoney(num value) => money.format(value);

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
