import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/utils/wallet.dart';
import '../models/payment_method.dart';

/// Card art for a wallet method: a gradient and the color on top of it.
/// Fixed in both themes, like a physical card.
class WalletCardStyle {
  const WalletCardStyle(this.label, this.colors, this.foreground);

  final String label;
  final List<Color> colors;
  final Color foreground;
}

/// Card art keys stored in `PaymentMethod.color`, in picker order.
const walletCardStyles = <String, WalletCardStyle>{
  'ink': WalletCardStyle('Negro', [
    Color(0xFF1C1C1E),
    Color(0xFF3A3B3F),
  ], Colors.white),
  'lime': WalletCardStyle('Lima', [
    Color(0xFFD7F56A),
    Color(0xFFA9D63A),
  ], Color(0xFF1A2006)),
  'lilac': WalletCardStyle('Lila', [
    Color(0xFFC9C0FF),
    Color(0xFF9483F0),
  ], Color(0xFF221A4A)),
  'mint': WalletCardStyle('Menta', [
    Color(0xFFB4EDCF),
    Color(0xFF63C99B),
  ], Color(0xFF0E3B28)),
  'blush': WalletCardStyle('Rosa', [
    Color(0xFFFFC2CB),
    Color(0xFFF2849A),
  ], Color(0xFF4A1520)),
  'ocean': WalletCardStyle('Azul', [
    Color(0xFF1E3A8A),
    Color(0xFF3B82F6),
  ], Colors.white),
  'sunset': WalletCardStyle('Naranja', [
    Color(0xFFF97316),
    Color(0xFFE11D48),
  ], Colors.white),
};

WalletCardStyle walletCardStyle(String key) =>
    walletCardStyles[key] ?? walletCardStyles.values.first;

/// A payment method drawn as a card (ID-1 proportions). With [summary] it
/// also shows this period's spending. No card number: only the last four
/// digits.
class WalletCard extends StatelessWidget {
  const WalletCard({super.key, required this.method, this.summary});

  final PaymentMethod method;
  final WalletSummary? summary;

  @override
  Widget build(BuildContext context) {
    final style = walletCardStyle(method.color);
    final fg = style.foreground;
    final faded = fg.withValues(alpha: .72);
    final summary = this.summary;
    return Semantics(
      label: [
        method.name,
        method.kind.label,
        if (method.last4 != null) 'terminada en ${method.last4}',
        if (summary != null)
          'gastado ${Formatters.compactMoney(summary.spent)}',
      ].join(', '),
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1.586,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: style.colors,
            ),
            // A soft glow under the middle, not a hard band below the card.
            boxShadow: [
              BoxShadow(
                color: style.colors.last.withValues(alpha: .35),
                blurRadius: 24,
                spreadRadius: -10,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Two soft rings for depth, like printed card art.
                Positioned(
                  right: -40,
                  top: -60,
                  child: _Ring(color: fg.withValues(alpha: .08), size: 200),
                ),
                Positioned(
                  right: 40,
                  bottom: -90,
                  child: _Ring(color: fg.withValues(alpha: .06), size: 180),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              method.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _BrandMark(method: method, color: fg),
                        ],
                      ),
                      Text(
                        [
                          method.kind.label,
                          if (method.bank != null) method.bank!,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: faded, fontSize: 13),
                      ),
                      const Spacer(),
                      if (method.kind.isCard) ...[
                        const _Chip(),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                method.masked ??
                                    (method.kind.isCard
                                        ? '•••• ••••'
                                        : method.kind.label),
                                style: TextStyle(
                                  color: fg,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (summary != null)
                            // Right-aligned; shrinks instead of overflowing
                            // with large text.
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      summary.periodLabel,
                                      style: TextStyle(
                                        color: faded,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      Formatters.compactMoney(summary.spent),
                                      style: TextStyle(
                                        color: fg,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 28),
    ),
  );
}

/// The card's EMV chip, drawn (no image assets).
class _Chip extends StatelessWidget {
  const _Chip();

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 28,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      gradient: const LinearGradient(
        colors: [Color(0xFFF6DE97), Color(0xFFCFA94F)],
      ),
    ),
    child: CustomPaint(painter: _ChipLines()),
  );
}

class _ChipLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x55594417)
      ..strokeWidth = 1;
    final w = size.width;
    final h = size.height;
    canvas
      ..drawLine(Offset(w * .35, 0), Offset(w * .35, h), paint)
      ..drawLine(Offset(w * .65, 0), Offset(w * .65, h), paint)
      ..drawLine(Offset(0, h / 2), Offset(w * .35, h / 2), paint)
      ..drawLine(Offset(w * .65, h / 2), Offset(w, h / 2), paint);
  }

  @override
  bool shouldRepaint(_ChipLines oldDelegate) => false;
}

/// The network's mark drawn with shapes and text, or the method's icon.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.method, required this.color});

  final PaymentMethod method;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!method.kind.isCard) {
      return Icon(
        method.kind == PaymentMethodKind.cash
            ? CupertinoIcons.money_dollar_circle
            : CupertinoIcons.device_phone_portrait,
        color: color,
        size: 24,
      );
    }
    return switch (method.brand) {
      CardBrand.visa => Text(
        'VISA',
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 1,
        ),
      ),
      CardBrand.mastercard => const SizedBox(
        width: 40,
        height: 26,
        child: Stack(
          children: [
            Positioned(left: 0, child: _Disc(Color(0xFFEB001B))),
            Positioned(right: 0, child: _Disc(Color(0xE6F79E1B))),
          ],
        ),
      ),
      CardBrand.amex => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'AMEX',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      _ => Icon(CupertinoIcons.creditcard, color: color, size: 24),
    };
  }
}

class _Disc extends StatelessWidget {
  const _Disc(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
