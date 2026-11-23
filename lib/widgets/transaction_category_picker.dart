import 'package:flutter/material.dart';

import '../core/utils/transaction_filter.dart';
import '../models/category.dart';
import 'icon_mapper.dart';

class TransactionCategoryPicker extends StatefulWidget {
  const TransactionCategoryPicker({
    super.key,
    required this.categories,
    required this.selected,
    this.suggestedId,
    this.focusNode,
    required this.accent,
    required this.onChanged,
    required this.onCreate,
  });

  final List<Category> categories;
  final String? selected;
  final String? suggestedId;
  final FocusNode? focusNode;
  final Color accent;
  final ValueChanged<String> onChanged;
  final VoidCallback onCreate;

  @override
  State<TransactionCategoryPicker> createState() =>
      _TransactionCategoryPickerState();
}

class _TransactionCategoryPickerState extends State<TransactionCategoryPicker> {
  bool _expanded = false;
  String _query = '';

  @override
  void didUpdateWidget(TransactionCategoryPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories.firstOrNull?.type !=
        oldWidget.categories.firstOrNull?.type) {
      _expanded = false;
      _query = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranked = [...widget.categories]
      ..sort((a, b) {
        if (a.id == b.id) return 0;
        if (a.id == widget.suggestedId) return -1;
        if (b.id == widget.suggestedId) return 1;
        final count = b.transactionCount.compareTo(a.transactionCount);
        return count != 0 ? count : a.name.compareTo(b.name);
      });
    final visible = _expanded ? ranked : ranked.take(6).toList();
    if (!_expanded &&
        widget.selected != null &&
        !visible.any((c) => c.id == widget.selected)) {
      final selected = ranked.where((c) => c.id == widget.selected);
      if (selected.isNotEmpty) {
        if (visible.length == 6) visible.removeLast();
        visible.add(selected.first);
      }
    }
    final matching = visible
        .where(
          (c) =>
              !_expanded ||
              normalizeText(c.name).contains(normalizeText(_query)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selected == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.suggestedId == null
                  ? 'Selecciona una categoría para este movimiento.'
                  : 'Sugerencia según tu historial. Toca para confirmar.',
            ),
          ),
        if (_expanded && ranked.length > 6)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar categoría',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
        if (matching.isEmpty && _query.isNotEmpty)
          const Text('No hay categorías con ese nombre.'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final category in matching)
              ChoiceChip(
                focusNode: category == matching.first ? widget.focusNode : null,
                avatar: Icon(
                  iconFromApi(category.icon),
                  size: 18,
                  color: widget.selected == category.id ? widget.accent : null,
                ),
                label: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(category.name),
                    if (widget.selected == null &&
                        category.id == widget.suggestedId)
                      Text(
                        'Sugerida',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                  ],
                ),
                selected: widget.selected == category.id,
                onSelected: (_) => widget.onChanged(category.id),
              ),
            ActionChip(
              focusNode: matching.isEmpty ? widget.focusNode : null,
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Nueva'),
              tooltip: 'Nueva categoría',
              onPressed: widget.onCreate,
            ),
          ],
        ),
        if (ranked.length > 6)
          TextButton(
            // Flush with the chips' left edge, still a 44 pt target.
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => setState(() {
              _expanded = !_expanded;
              _query = '';
            }),
            child: Text(
              _expanded ? 'Ver menos' : 'Ver todas (${ranked.length})',
            ),
          ),
      ],
    );
  }
}
