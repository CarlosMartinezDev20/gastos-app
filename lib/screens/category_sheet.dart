import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../models/category.dart';
import '../providers/finance_providers.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/ios_ui.dart';
import '../core/theme/motion.dart';

/// Opens the create/edit sheet. Returns the saved category, or null when the
/// sheet is dismissed or the category is deleted.
Future<Category?> showCategorySheet(
  BuildContext context, {
  Category? category,
  TransactionType type = TransactionType.expense,
}) {
  return showModalBottomSheet<Category>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => CategorySheet(category: category, initialType: type),
  );
}

/// Colors of a category's icon tile: lime for income, black for expenses,
/// like the Inicio cards.
(Color, Color) categoryColors(AppPalette palette, TransactionType type) =>
    type == TransactionType.income
    ? (palette.accent, palette.onAccent)
    : (palette.ink, palette.onInk);

class CategorySheet extends ConsumerStatefulWidget {
  const CategorySheet({super.key, this.category, required this.initialType});

  final Category? category;
  final TransactionType initialType;

  @override
  ConsumerState<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<CategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name);
  late TransactionType _type = widget.category?.type ?? widget.initialType;
  late String _icon = widget.category?.icon ?? categoryIconNames.first;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.category != null;

  /// A category in use keeps its type: its movements must match it.
  int get _usage => widget.category?.transactionCount ?? 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(financeRepositoryProvider);
    try {
      final name = _name.text.trim();
      final saved = _editing
          ? await repository.updateCategory(
              widget.category!.id,
              name: name,
              icon: _icon,
              type: _type,
            )
          : await repository.createCategory(
              name: name,
              icon: _icon,
              type: _type,
            );
      ref.invalidate(categoriesProvider);
      refreshFinance(ref);
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: '¿Eliminar "${widget.category!.name}"?',
      message: 'La categoría desaparecerá de tu lista.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(financeRepositoryProvider)
          .deleteCategory(widget.category!.id);
      ref.invalidate(categoriesProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final (tile, onTile) = categoryColors(palette, _type);
    final duration = Motion.of(context, Motion.medium);

    return KeyboardInset(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editing ? 'Editar categoría' : 'Nueva categoría',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 18),
              // Live preview of the category.
              Row(
                children: [
                  AnimatedContainer(
                    duration: duration,
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: tile,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AnimatedSwitcher(
                      duration: duration,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        iconFromApi(_icon),
                        key: ValueKey(_icon),
                        color: onTile,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Only the name follows each key, not the sheet.
                        ListenableBuilder(
                          listenable: _name,
                          builder: (context, _) => Text(
                            _name.text.trim().isEmpty
                                ? 'Nueva categoría'
                                : _name.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge,
                          ),
                        ),
                        Text(
                          _type.label,
                          style: TextStyle(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              EntranceAutofocus(
                enabled: !_editing,
                builder: (context, focusNode) => TextFormField(
                  controller: _name,
                  focusNode: focusNode,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej. Gimnasio',
                    counterText: '',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Escribe un nombre'
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              IgnorePointer(
                ignoring: _usage > 0,
                child: Opacity(
                  opacity: _usage > 0 ? .5 : 1,
                  child: SegmentedTabs<TransactionType>(
                    selected: _type,
                    onChanged: (value) => setState(() => _type = value),
                    segments: const {
                      TransactionType.expense: 'Gasto',
                      TransactionType.income: 'Ingreso',
                    },
                  ),
                ),
              ),
              if (_usage > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Tiene $_usage ${_usage == 1 ? 'movimiento' : 'movimientos'}, '
                  'así que su tipo no puede cambiar.',
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
              const SizedBox(height: 20),
              Text('Ícono', style: text.titleMedium),
              const SizedBox(height: 10),
              _IconGrid(
                selected: _icon,
                onSelected: (icon) => setState(() => _icon = icon),
              ),
              AnimatedSize(
                duration: duration,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.blush,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_circle,
                              color: palette.onBlush,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: palette.onBlush,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              PillCta(
                label: _editing ? 'Guardar cambios' : 'Crear categoría',
                loading: _saving,
                onPressed: _save,
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(CupertinoIcons.trash, size: 18),
                  label: const Text('Eliminar categoría'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final duration = Motion.of(context, Motion.fast);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in categoryIconNames)
          Semantics(
            button: true,
            selected: name == selected,
            label: name,
            child: GestureDetector(
              onTap: () => onSelected(name),
              child: AnimatedContainer(
                duration: duration,
                curve: Motion.standard,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: name == selected
                      ? palette.ink
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  iconFromApi(name),
                  size: 22,
                  color: name == selected ? palette.accent : palette.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
