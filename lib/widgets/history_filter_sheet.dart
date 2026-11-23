import 'form_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/finance_providers.dart';
import 'app_states.dart';
import 'ios_ui.dart';

typedef HistoryFilterSelection = ({
  String? categoryId,
  String? paymentMethodId,
});

Future<HistoryFilterSelection?> showHistoryFilterSheet(
  BuildContext context, {
  String? categoryId,
  String? paymentMethodId,
}) => showModalBottomSheet<HistoryFilterSelection>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _HistoryFilterSheet(
    categoryId: categoryId,
    paymentMethodId: paymentMethodId,
  ),
);

class _HistoryFilterSheet extends ConsumerStatefulWidget {
  const _HistoryFilterSheet({this.categoryId, this.paymentMethodId});
  final String? categoryId;
  final String? paymentMethodId;

  @override
  ConsumerState<_HistoryFilterSheet> createState() =>
      _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends ConsumerState<_HistoryFilterSheet> {
  late String? _categoryId = widget.categoryId;
  late String? _paymentMethodId = widget.paymentMethodId;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final methods = ref.watch(paymentMethodsProvider);
    if (categories.hasError || methods.hasError) {
      return AppErrorState(
        message: 'No se pudieron cargar las categorías y los métodos de pago.',
        onRetry: () {
          ref.invalidate(categoriesProvider);
          ref.invalidate(paymentMethodsProvider);
        },
      );
    }
    if (!categories.hasValue || !methods.hasValue) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final items = categories.requireValue;
    final payments = methods.requireValue;
    return KeyboardInset(
      extra: MediaQuery.paddingOf(context).bottom + 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FormLayout.inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filtrar movimientos', style: FormLayout.titleStyle(context)),
            const SizedBox(height: FormLayout.sectionGap),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todas las categorías'),
                        ),
                        if (_categoryId != null &&
                            !items.any((c) => c.id == _categoryId))
                          DropdownMenuItem(
                            value: _categoryId,
                            child: const Text('Categoría seleccionada'),
                          ),
                        for (final category in items)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (id) => setState(() => _categoryId = id),
                    ),
                    const SizedBox(height: FormLayout.fieldGap),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethodId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Método de pago',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todos los métodos'),
                        ),
                        if (_paymentMethodId != null &&
                            !payments.any((m) => m.id == _paymentMethodId))
                          DropdownMenuItem(
                            value: _paymentMethodId,
                            child: const Text('Método seleccionado'),
                          ),
                        for (final method in payments)
                          DropdownMenuItem(
                            value: method.id,
                            child: Text(method.shortLabel),
                          ),
                      ],
                      onChanged: (id) => setState(() => _paymentMethodId = id),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: FormLayout.sectionGap),
            FilledButton(
              onPressed: () => Navigator.pop(context, (
                categoryId: _categoryId,
                paymentMethodId: _paymentMethodId,
              )),
              child: const Text('Aplicar filtros'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
