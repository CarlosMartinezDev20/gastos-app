import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final money = NumberFormat.currency(locale: 'es_SV', symbol: r'$');
  static final shortDate = DateFormat('dd MMM', 'es');
  static final fullDate = DateFormat('dd/MM/yyyy', 'es');

  static String compactMoney(num value) => money.format(value);
}
