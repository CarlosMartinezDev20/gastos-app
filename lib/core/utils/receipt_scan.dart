import 'dart:math' as math;

import '../../models/category.dart';
import '../../models/transaction.dart';

/// Where a scanned draft came from.
enum ScanSource {
  /// El Salvador's electronic invoice (DTE) QR: a link to Hacienda's public
  /// lookup with the generation code and date; no amount or merchant.
  invoice,

  /// A merchant-presented payment QR (EMVCo): merchant and maybe amount.
  paymentQr,

  /// Text read from a photo of the receipt.
  receiptText,
}

/// What a scan could tell about an expense. Every field may be missing; the
/// movement form is always shown to confirm or complete it.
class ScanDraft {
  const ScanDraft({
    required this.source,
    this.amount,
    this.merchant,
    this.date,
    this.reference,
    this.invoiceUrl,
  });

  final ScanSource source;
  final double? amount;
  final String? merchant;
  final DateTime? date;

  /// The invoice's generation code (saved as the movement's reference).
  final String? reference;

  /// Hacienda's public page for the invoice.
  final Uri? invoiceUrl;

  /// Nothing worth prefilling.
  bool get isEmpty =>
      amount == null && merchant == null && date == null && reference == null;

  ScanDraft merge(ScanDraft other) => ScanDraft(
    source: source,
    amount: amount ?? other.amount,
    merchant: merchant ?? other.merchant,
    date: date ?? other.date,
    reference: reference ?? other.reference,
    invoiceUrl: invoiceUrl ?? other.invoiceUrl,
  );
}

final _uuid = RegExp(
  r'\b[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\b',
  caseSensitive: false,
);

/// Reads a QR's text. Returns null when it holds nothing useful for an
/// expense (a plain link, a Wi-Fi code…).
ScanDraft? parseQrPayload(String raw) {
  final text = raw.trim();
  final uri = Uri.tryParse(text);
  if (uri != null && uri.host.endsWith('factura.gob.sv')) {
    final code = uri.queryParameters['codGen'];
    if (code == null || code.isEmpty) return null;
    return ScanDraft(
      source: ScanSource.invoice,
      reference: code.toUpperCase(),
      date: DateTime.tryParse(uri.queryParameters['fechaEmi'] ?? ''),
      invoiceUrl: uri,
    );
  }
  if (text.startsWith('000201')) return _parseEmv(text);
  return null;
}

/// EMVCo merchant-presented QR: two-digit tag, two-digit length, value.
/// 54 = amount, 59 = merchant name, 60 = city.
ScanDraft? _parseEmv(String text) {
  final fields = <String, String>{};
  var i = 0;
  while (i + 4 <= text.length) {
    final tag = text.substring(i, i + 2);
    final length = int.tryParse(text.substring(i + 2, i + 4));
    if (length == null || i + 4 + length > text.length) break;
    fields[tag] = text.substring(i + 4, i + 4 + length);
    i += 4 + length;
  }
  final name = fields['59']?.trim();
  final draft = ScanDraft(
    source: ScanSource.paymentQr,
    amount: double.tryParse(fields['54'] ?? ''),
    merchant: name == null || name.isEmpty ? null : _titleCase(name),
  );
  return draft.isEmpty ? null : draft;
}

/// A line recognized on a photo, with its corners (top-left, top-right,
/// bottom-right, bottom-left) in image pixels; the box may be tilted.
class OcrLine {
  const OcrLine(this.text, this.corners);

  final String text;
  final List<({double x, double y})> corners;
}

/// Puts recognized lines back into the receipt's printed rows. OCR returns
/// them by blocks (a column of labels, then a column of amounts), so
/// "TOTAL" and its "3.40" can end up far apart in the text; grouping by
/// height, after undoing the photo's tilt, brings them back to one row.
String receiptRows(List<OcrLine> lines) {
  final boxes = lines.where((l) => l.corners.length == 4).toList();
  if (boxes.isEmpty) return lines.map((l) => l.text).join('\n');

  double dist(({double x, double y}) a, ({double x, double y}) b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  // The photo's tilt: the median slope of the long lines' top edges.
  final slopes = [
    for (final l in boxes)
      if (dist(l.corners[0], l.corners[1]) >=
          2 * dist(l.corners[0], l.corners[3]))
        math.atan2(
          l.corners[1].y - l.corners[0].y,
          l.corners[1].x - l.corners[0].x,
        ),
  ]..sort();
  final tilt = slopes.isEmpty ? 0.0 : slopes[slopes.length ~/ 2];
  final cos = math.cos(-tilt);
  final sin = math.sin(-tilt);

  final placed = [
    for (final l in boxes)
      (
        text: l.text,
        // Center and left edge, rotated so the receipt's rows are level.
        y:
            l.corners
                .map((p) => p.x * sin + p.y * cos)
                .reduce((a, b) => a + b) /
            4,
        left: l.corners.map((p) => p.x * cos - p.y * sin).reduce(math.min),
        height:
            (dist(l.corners[0], l.corners[3]) +
                dist(l.corners[1], l.corners[2])) /
            2,
      ),
  ]..sort((a, b) => a.y.compareTo(b.y));

  final rows = <List<({String text, double y, double left, double height})>>[];
  for (final line in placed) {
    final row = rows.lastOrNull;
    if (row != null) {
      final rowY = row.map((l) => l.y).reduce((a, b) => a + b) / row.length;
      final rowHeight = row.map((l) => l.height).reduce(math.max);
      if ((line.y - rowY).abs() <= .6 * math.max(rowHeight, line.height)) {
        row.add(line);
        continue;
      }
    }
    rows.add([line]);
  }
  return rows
      .map(
        (row) => (row..sort((a, b) => a.left.compareTo(b.left)))
            .map((l) => l.text)
            .join('  '),
      )
      .join('\n');
}

final _money = RegExp(r'\$?\s*(\d{1,3}(?:[.,]\d{3})*[.,]\d{2}|\d+[.,]\d{2})');
final _dateDmy = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4}|\d{2})\b');
final _dateIso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

/// Lines that hold the amount to pay, strongest first.
/// Lines that hold the amount to pay, strongest first. [nextLine]: on
/// narrow tickets the amount may be printed on the line below.
final _totalLabels = [
  (RegExp(r'total\s*(a\s*)?pagar', caseSensitive: false), nextLine: true),
  (RegExp(r'monto\s*total', caseSensitive: false), nextLine: true),
  (RegExp(r'\btotal\b', caseSensitive: false), nextLine: true),
  // Card terminal vouchers.
  (RegExp(r'\b(importe|monto)\b', caseSensitive: false), nextLine: true),
  (RegExp(r'\bventa\b', caseSensitive: false), nextLine: false),
];

/// "TOTAL" lines that aren't the amount to pay.
final _notTheTotal = RegExp(
  r'sub\s*-?\s*total|total\s*(de\s*)?(art[ií]culos|items|productos|unidades)|'
  r'total\s*(gravad|exent|no\s*sujet|descuent|iva)',
  caseSensitive: false,
);

/// Words of headers and legal lines, never the merchant's name.
final _notMerchant = RegExp(
  r'factura|ticket|comprobante|consumidor|cr[eé]dito fiscal|documento|'
  r'tributario|\bnit\b|\bnrc\b|\bdte\b|fecha|hora|caja|cajero|sucursal|'
  r'direcci[oó]n|tel[eé]fono|\btel\b|cliente|resoluci[oó]n|serie|'
  r'c[oó]digo|n[uú]mero|giro|www\.|https?:|@',
  caseSensitive: false,
);

/// Reads the text recognized on a receipt photo: the amount to pay, the
/// merchant (its first meaningful line), the date and an invoice code.
ScanDraft parseReceiptText(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  return ScanDraft(
    source: ScanSource.receiptText,
    amount: _findTotal(lines),
    merchant: _findMerchant(lines),
    date: _findDate(text),
    reference: _uuid.firstMatch(text)?.group(0)?.toUpperCase(),
  );
}

double? _amountIn(String line) {
  final matches = _money.allMatches(line).toList();
  if (matches.isEmpty) return null;
  return parseMoney(matches.last.group(1)!);
}

/// "1,234.56", "1.234,56", "12.50" or "12,50" as a number.
double? parseMoney(String value) {
  final lastDot = value.lastIndexOf('.');
  final lastComma = value.lastIndexOf(',');
  final decimal = lastDot > lastComma ? '.' : ',';
  final thousands = decimal == '.' ? ',' : '.';
  return double.tryParse(
    value.replaceAll(thousands, '').replaceAll(decimal, '.'),
  );
}

double? _findTotal(List<String> lines) {
  for (final (label, :nextLine) in _totalLabels) {
    // The last matching line: totals come after subtotals.
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (!label.hasMatch(line) || _notTheTotal.hasMatch(line)) continue;
      final amount =
          _amountIn(line) ??
          (nextLine && i + 1 < lines.length ? _amountIn(lines[i + 1]) : null);
      if (amount != null && amount > 0) return amount;
    }
  }
  return null;
}

String? _findMerchant(List<String> lines) {
  for (final line in lines.take(6)) {
    final letters = line.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑáéíóúñ]'), '');
    final digits = line.replaceAll(RegExp(r'\D'), '');
    if (letters.length < 3 || digits.length > letters.length) continue;
    if (_notMerchant.hasMatch(line) || _money.hasMatch(line)) continue;
    // Drop logo marks and stray symbols around the name.
    final name = line
        .replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑáéíóúñ0-9&.\- ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.length >= 3) return _titleCase(name);
  }
  return null;
}

DateTime? _findDate(String text) {
  final iso = _dateIso.firstMatch(text);
  if (iso != null) {
    return _validDate(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  final dmy = _dateDmy.firstMatch(text);
  if (dmy == null) return null;
  var year = int.parse(dmy.group(3)!);
  if (year < 100) year += 2000;
  return _validDate(year, int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
}

DateTime? _validDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  // DateTime rolls 31/02 over to March: reject it.
  return date.month == month ? date : null;
}

/// "FARMACIAS SR" → "Farmacias SR": words without vowels are initials.
String _titleCase(String value) => value
    .split(' ')
    .map(
      (w) =>
          w.isEmpty || !RegExp('[aeiouáéíóú]', caseSensitive: false).hasMatch(w)
          ? w.toUpperCase()
          : w[0].toUpperCase() + w.substring(1).toLowerCase(),
    )
    .join(' ');

/// Words in a merchant's name that point to a system category.
const _categoryHints = <String, List<String>>{
  'Comida': [
    'super',
    'selectos',
    'walmart',
    'despensa',
    'colonia',
    'pricesmart',
    'pollo',
    'campero',
    'pizza',
    'burger',
    'mcdonald',
    'wendy',
    'subway',
    'restaurante',
    'cafe',
    'café',
    'starbucks',
    'pupus',
    'panaderia',
    'panadería',
    'comedor',
    'cafeteria',
    'cafetería',
    'food',
    'kfc',
  ],
  'Transporte': [
    'gasolinera',
    'puma',
    'texaco',
    'uno',
    'shell',
    'combustible',
    'uber',
    'indriver',
    'parqueo',
    'estacionamiento',
    'taxi',
    'bus',
  ],
  'Fotocopias': ['fotocopia', 'copias', 'impresiones', 'librería', 'libreria'],
  'Salud': [
    'farmacia',
    'san nicolas',
    'san nicolás',
    'economica',
    'económica',
    'clinica',
    'clínica',
    'hospital',
    'laboratorio',
    'medic',
    'médic',
  ],
  'Ropa': ['ropa', 'zapater', 'boutique', 'siman', 'simán', 'adoc', 'payless'],
  'Salidas': ['cine', 'cinemark', 'bar', 'disco', 'boliche', 'teatro'],
};

String _fold(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úù]'), 'u');

/// The category to start with for [merchant]: the one used most with the
/// same merchant before, else one hinted by its name, else none.
String? suggestCategoryId(
  String? merchant,
  List<Transaction> history,
  List<Category> categories,
) {
  if (merchant == null) return null;
  final expenseCategories = categories
      .where((c) => c.type == TransactionType.expense)
      .toList();
  final ids = {for (final c in expenseCategories) c.id};
  final name = _fold(merchant);
  final key = name
      .split(' ')
      .firstWhere((w) => w.length >= 4, orElse: () => '');

  if (key.isNotEmpty) {
    final counts = <String, int>{};
    for (final t in history) {
      if (t.type != TransactionType.expense || t.isGoalContribution) continue;
      if (!ids.contains(t.category.id)) continue;
      if (!_fold(t.title).contains(key)) continue;
      counts.update(t.category.id, (n) => n + 1, ifAbsent: () => 1);
    }
    if (counts.isNotEmpty) {
      return (counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;
    }
  }

  for (final MapEntry(key: categoryName, value: hints)
      in _categoryHints.entries) {
    if (!hints.any((h) => RegExp('\\b${_fold(h)}').hasMatch(name))) continue;
    final match = expenseCategories
        .where((c) => _fold(c.name) == _fold(categoryName))
        .firstOrNull;
    if (match != null) return match.id;
  }
  // A user's own category whose name appears in the merchant's.
  return expenseCategories
      .where((c) => !c.isDefault && name.contains(_fold(c.name)))
      .firstOrNull
      ?.id;
}
