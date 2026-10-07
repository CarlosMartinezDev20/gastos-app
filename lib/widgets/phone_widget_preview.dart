import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/utils/phone_widget.dart';
import 'animated_progress.dart';

/// How the phone's home-screen widget looks with [payload], drawn like the
/// native one (Android `widget_finance.xml`, iOS `FinanceWidget.swift`).
class PhoneWidgetPreview extends StatelessWidget {
  const PhoneWidgetPreview({super.key, required this.payload});

  final PhoneWidgetPayload payload;

  /// A 2×2 widget on a typical phone.
  static const side = 168.0;

  @override
  Widget build(BuildContext context) {
    final theme = payload.theme;
    final fg = Color(theme.foreground);
    final muted = Color(theme.muted);
    final highlight = Color(theme.highlight);
    return Semantics(
      label: 'Vista previa del widget: ${payload.title}, ${payload.amount}',
      excludeSemantics: true,
      child: Container(
        width: side,
        constraints: const BoxConstraints(minHeight: side),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(theme.background),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.money_dollar_circle, size: 16, color: fg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    payload.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                payload.amount,
                style: TextStyle(
                  color: fg,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                ),
              ),
            ),
            Text(
              payload.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            if (payload.progress case final progress?)
              AnimatedProgressBar(
                value: progress / 100,
                height: 8,
                color: highlight,
                trackColor: fg.withValues(alpha: .12),
              )
            else if (payload.bars.isNotEmpty)
              SizedBox(
                height: 30,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, bar) in payload.bars.indexed)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FractionallySizedBox(
                            heightFactor: bar.clamp(.1, 1),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: i == payload.bars.length - 1
                                    ? highlight
                                    : fg.withValues(alpha: .22),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
