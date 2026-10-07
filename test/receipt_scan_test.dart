import 'package:appgastos/core/utils/receipt_scan.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

const food = Category(
  id: 'food',
  name: 'Comida',
  icon: 'lunch_dining',
  type: TransactionType.expense,
  isDefault: true,
);
const health = Category(
  id: 'health',
  name: 'Salud',
  icon: 'medical_services',
  type: TransactionType.expense,
  isDefault: true,
);
const gym = Category(
  id: 'gym',
  name: 'Gimnasio',
  icon: 'fitness_center',
  type: TransactionType.expense,
  isDefault: false,
);
const salary = Category(
  id: 'work',
  name: 'Trabajo',
  icon: 'work',
  type: TransactionType.income,
  isDefault: true,
);

/// A label-value pair for an EMVCo payload.
String emv(String tag, String value) =>
    '$tag${value.length.toString().padLeft(2, '0')}$value';

void main() {
  group('parseQrPayload', () {
    test("reads Hacienda's invoice QR: code and date, no amount", () {
      final draft = parseQrPayload(
        'https://admin.factura.gob.sv/consultaPublica?ambiente=01'
        '&codGen=9f3a1c2b-0d4e-4f5a-8b6c-7d8e9f0a1b2c&fechaEmi=2026-10-02',
      )!;
      expect(draft.source, ScanSource.invoice);
      expect(draft.reference, '9F3A1C2B-0D4E-4F5A-8B6C-7D8E9F0A1B2C');
      expect(draft.date, DateTime(2026, 10, 2));
      expect(draft.amount, isNull);
      expect(draft.invoiceUrl!.host, 'admin.factura.gob.sv');
    });

    test('reads a merchant payment QR (EMVCo)', () {
      final payload = [
        emv('00', '01'),
        emv('01', '12'),
        emv('53', '840'),
        emv('54', '12.75'),
        emv('58', 'SV'),
        emv('59', 'PUPUSERIA LA ESQUINA'),
        emv('60', 'SAN SALVADOR'),
        '6304ABCD',
      ].join();
      final draft = parseQrPayload(payload)!;
      expect(draft.source, ScanSource.paymentQr);
      expect(draft.amount, 12.75);
      expect(draft.merchant, 'Pupuseria La Esquina');
    });

    test('ignores codes with nothing for an expense', () {
      expect(parseQrPayload('https://example.com/promo'), isNull);
      expect(parseQrPayload('WIFI:S:Casa;T:WPA;P:secreto;;'), isNull);
      expect(
        parseQrPayload('https://admin.factura.gob.sv/consultaPublica'),
        isNull,
      );
      expect(parseQrPayload('000201'), isNull);
    });
  });

  group('parseReceiptText', () {
    test('finds the total, not the subtotal or the item count', () {
      final draft = parseReceiptText('''
SUPER SELECTOS
Sucursal Escalón
NIT 0614-123456-001-2
FACTURA CONSUMIDOR FINAL
Fecha: 02/10/2026 14:31
LECHE 1L            1.25
PAN DULCE           2.10
SUBTOTAL            3.35
TOTAL ARTICULOS 2
TOTAL              \$3.35
EFECTIVO           5.00
CAMBIO             1.65
''');
      expect(draft.amount, 3.35);
      expect(draft.merchant, 'Super Selectos');
      expect(draft.date, DateTime(2026, 10, 2));
    });

    test('takes the amount from the next line on narrow tickets', () {
      final draft = parseReceiptText('''
Farmacia San Nicolás
TOTAL A PAGAR
\$1,234.50
Código de generación: 9F3A1C2B-0D4E-4F5A-8B6C-7D8E9F0A1B2C
''');
      expect(draft.amount, 1234.50);
      expect(draft.reference, '9F3A1C2B-0D4E-4F5A-8B6C-7D8E9F0A1B2C');
      expect(draft.merchant, 'Farmacia San Nicolás');
    });

    test('handles unreadable text without inventing data', () {
      final draft = parseReceiptText('~~ ## 12 ##\n|||');
      expect(draft.isEmpty, isTrue);
    });

    test('rejects impossible dates', () {
      expect(parseReceiptText('Fecha 31/02/2026').date, isNull);
      expect(parseReceiptText('2026-10-05').date, DateTime(2026, 10, 5));
      expect(parseReceiptText('5-10-26').date, DateTime(2026, 10, 5));
    });
  });

  group('receiptRows', () {
    /// A recognized line from [x1] to [x2], centered at [cy], on a photo
    /// tilted by [slope] (pixels down per pixel right).
    OcrLine line(
      String text,
      double x1,
      double x2,
      double cy, {
      double slope = 0,
      double height = 16,
    }) {
      final mid = (x1 + x2) / 2;
      double y(double x) => cy + slope * (x - mid);
      return OcrLine(text, [
        (x: x1, y: y(x1) - height / 2),
        (x: x2, y: y(x2) - height / 2),
        (x: x2, y: y(x2) + height / 2),
        (x: x1, y: y(x1) + height / 2),
      ]);
    }

    // A pharmacy ticket as ML Kit returns it: the left column's block, then
    // the right column's (the amounts), on a photo tilted ~1.7°.
    const slope = -.029;
    List<OcrLine> pharmacyTicket() => [
      line('FARMACIAS', 480, 645, 497, slope: slope),
      line('TE ALCANZA PARA MAS', 525, 610, 521, slope: slope, height: 8),
      line('RECUERDA QUE PUEDES HACER TUS', 432, 732, 551, slope: slope),
      line('PEDIDOS LLAMANDO AL CALLCENTER:', 427, 765, 573, slope: slope),
      line('2450-4373.', 548, 628, 595, slope: slope),
      line('COMPROBANTE DE VENTA', 450, 692, 627, slope: slope),
      line('REF. FA3026 0031298', 488, 675, 649, slope: slope),
      line('CLIENTE:', 425, 505, 680, slope: slope),
      line('CLIENTE EJEMPLO', 437, 600, 700, slope: slope),
      line('DIRECCION:', 437, 527, 746, slope: slope),
      line('CALLE EJEMPLO', 435, 600, 775, slope: slope),
      line('COD. DESCRIPCION CANT. PRECIO', 442, 680, 829, slope: slope),
      line('3935 MATRICARIA POLVO 6 CIAS', 447, 660, 857, slope: slope),
      line('CANTIDAD 1', 465, 617, 880, slope: slope),
      line('TOTAL US\$...', 487, 612, 929, slope: slope),
      line('SON: TRES Y 40/100', 450, 600, 980, slope: slope),
      line('2/10/2026 15:54:36', 455, 600, 1027, slope: slope),
      line('manuel7', 452, 498, 1060, slope: slope),
      // Right column.
      line('SR', 668, 708, 493, slope: slope, height: 30),
      line('VALOR', 708, 752, 826, slope: slope),
      line('3.40', 703, 742, 873, slope: slope),
      line('3.40', 700, 748, 919, slope: slope),
    ];

    test('puts the total back on its row and reads the ticket', () {
      final rows = receiptRows(pharmacyTicket());
      expect(rows, contains('TOTAL US\$...  3.40'));
      final draft = parseReceiptText(rows);
      expect(draft.amount, 3.40);
      expect(draft.merchant, 'Farmacias SR');
      expect(draft.date, DateTime(2026, 10, 2));
      expect(
        suggestCategoryId(draft.merchant, const [], [food, health]),
        'health',
      );
    });

    test('reads what ML Kit returned for a real pharmacy ticket', () {
      // Rows as logged on the phone (customer name and address replaced).
      final draft = parseReceiptText('''
FARMACIAS SR
TE ALCAN ZA PARA MAS
RECUERDA QUE PUEDES HACER TUS
PEDIDOS LLAMANDO AL CALLCENTER:
2450-4373.
COMPROBANTE DE VENTA
REF. FA3026 0031298
CLIENTE:
NOMBRE DE EJEMPLO
DIRECCION:
CALLE DE EJEMPLO
COD. DESCRIPCIÓN CANT PRECIO  VAL OR
3935  MATRICARIA POLVO 6 CIAS
CANTIDAD  1
TOTAL US\$..  3.40
SON: TES YA0 | 100
2/10/2026 15:54:30
manuel7''');
      expect(draft.amount, 3.40);
      expect(draft.merchant, 'Farmacias SR');
      expect(draft.date, DateTime(2026, 10, 2));
    });

    test('undoes a stronger tilt before grouping rows', () {
      // ~6°: across 300 px the amount sits 31 px above its label.
      final rows = receiptRows([
        line('SUBTOTAL', 100, 220, 400, slope: -.105),
        line('9.99', 380, 430, 371, slope: -.105),
        line('TOTAL', 100, 180, 440, slope: -.105),
        line('12.50', 380, 440, 408, slope: -.105),
        line('GRACIAS POR SU COMPRA', 100, 420, 490, slope: -.105),
      ]);
      expect(rows.split('\n'), [
        'SUBTOTAL  9.99',
        'TOTAL  12.50',
        'GRACIAS POR SU COMPRA',
      ]);
      expect(parseReceiptText(rows).amount, 12.5);
    });

    test('reads a card voucher by its sale amount', () {
      expect(
        parseReceiptText(
          'BAC CREDOMATIC\nCOMPROBANTE DE VENTA\n'
          'VENTA  US\$ 25.00\nAPROBADA',
        ).amount,
        25.0,
      );
    });
  });

  test('parseMoney reads both decimal styles', () {
    expect(parseMoney('1,234.56'), 1234.56);
    expect(parseMoney('1.234,56'), 1234.56);
    expect(parseMoney('12,50'), 12.5);
  });

  group('suggestCategoryId', () {
    Transaction tx(String title, Category category) => Transaction(
      id: title,
      title: title,
      amount: 1,
      type: category.type,
      date: DateTime(2026, 10, 1),
      category: category,
    );

    test('prefers what was used before with the same merchant', () {
      final history = [
        tx('Selectos Escalón', health),
        tx('Super Selectos', health),
        tx('Selectos', food),
      ];
      expect(
        suggestCategoryId('Super Selectos', history, [food, health]),
        'health',
      );
    });

    test('falls back to hints in the name, then own categories', () {
      expect(
        suggestCategoryId('Farmacia Económica', const [], [food, health]),
        'health',
      );
      expect(
        suggestCategoryId('Pollo Campero', const [], [food, health]),
        'food',
      );
      expect(
        suggestCategoryId('Gimnasio Fit', const [], [food, gym, salary]),
        'gym',
      );
      expect(suggestCategoryId('Xyz Corp', const [], [food]), isNull);
      expect(suggestCategoryId(null, const [], [food]), isNull);
    });
  });
}
