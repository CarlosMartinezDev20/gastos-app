import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../models/payment_method.dart';
import '../screens/payment_method_sheet.dart';
import 'wallet_card.dart';

/// The wallet's methods as chips (tap the selected one to clear it), and a
/// chip to add one without leaving the form; it comes back selected.
class PaymentMethodPicker extends StatelessWidget {
  const PaymentMethodPicker({
    super.key,
    required this.methods,
    required this.selected,
    required this.onChanged,
    this.allowAdd = true,
  });

  final List<PaymentMethod> methods;
  final String? selected;
  final ValueChanged<String?> onChanged;

  /// Show the chip that adds a method without leaving the form.
  final bool allowAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final method in methods)
          ChoiceChip(
            avatar: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Keeps a black card's dot visible on a dark chip.
                border: Border.all(color: context.palette.hairline),
                gradient: LinearGradient(
                  colors: walletCardStyle(method.color).colors,
                ),
              ),
            ),
            label: Text(method.shortLabel),
            selected: selected == method.id,
            onSelected: (on) => onChanged(on ? method.id : null),
          ),
        if (allowAdd)
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: Text(
              methods.isEmpty ? 'Agregar tarjeta o efectivo' : 'Agregar',
            ),
            tooltip: 'Agregar método de pago',
            onPressed: () async {
              final created = await showPaymentMethodSheet(context);
              if (created != null) onChanged(created.id);
            },
          ),
      ],
    );
  }
}
