import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../models/category.dart';
import '../providers/finance_providers.dart';
import '../widgets/app_states.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/ios_ui.dart';
import '../widgets/mascot.dart';
import 'category_sheet.dart';

/// Lists the system and the user's categories per type; the user's own can
/// be created, edited and deleted.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  TransactionType _type = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(categoriesProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.paddingOf(context).bottom + 28,
                ),
                children: [
                  Row(
                    children: [
                      CircleButton(
                        icon: CupertinoIcons.chevron_left,
                        tooltip: 'Volver',
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/profile'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LargeTitle(
                    title: 'Categorías',
                    subtitle: 'Ordena tus gastos e ingresos a tu manera',
                    trailing: [
                      CircleButton(
                        icon: CupertinoIcons.add,
                        tooltip: 'Nueva categoría',
                        filled: true,
                        onPressed: () =>
                            showCategorySheet(context, type: _type),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SegmentedTabs<TransactionType>(
                    selected: _type,
                    onChanged: (value) => setState(() => _type = value),
                    segments: const {
                      TransactionType.expense: 'Gastos',
                      TransactionType.income: 'Ingresos',
                    },
                  ),
                  const SizedBox(height: 20),
                  categories.when(
                    loading: () =>
                        const SizedBox(height: 320, child: AppShimmer()),
                    error: (error, _) => AppErrorState(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(categoriesProvider),
                    ),
                    data: (items) => _CategoryLists(
                      // Rebuild the entrance animation per segment.
                      key: ValueKey(_type),
                      type: _type,
                      items: items.where((c) => c.type == _type).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryLists extends StatelessWidget {
  const _CategoryLists({super.key, required this.type, required this.items});

  final TransactionType type;
  final List<Category> items;

  @override
  Widget build(BuildContext context) {
    final own = items.where((c) => c.editable).toList();
    final system = items.where((c) => !c.editable).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: SectionHeader(
            title: 'Tus categorías',
            trailingText: own.isEmpty ? null : '${own.length}',
          ),
        ),
        const SizedBox(height: 6),
        if (own.isEmpty)
          FadeSlideIn(index: 1, child: _EmptyOwn(type: type))
        else
          FadeSlideIn(
            index: 1,
            child: BentoCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (i, category) in own.indexed) ...[
                    if (i > 0) const Divider(indent: 72, height: 1),
                    _CategoryRow(
                      category: category,
                      onTap: () =>
                          showCategorySheet(context, category: category),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 26),
        FadeSlideIn(
          index: 2,
          child: Row(
            children: [
              const Expanded(child: SectionHeader(title: 'Del sistema')),
              Icon(
                CupertinoIcons.lock_fill,
                size: 14,
                color: context.palette.muted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        FadeSlideIn(
          index: 3,
          child: BentoCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, category) in system.indexed) ...[
                  if (i > 0) const Divider(indent: 72, height: 1),
                  _CategoryRow(category: category),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, this.onTap});

  final Category category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (tile, onTile) = categoryColors(palette, category.type);
    final count = category.transactionCount;
    return ListTile(
      onTap: onTap,
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          // System categories use a quiet tile so the user's own stand out.
          color: category.editable
              ? tile
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          iconFromApi(category.icon),
          size: 22,
          color: category.editable ? onTile : palette.muted,
        ),
      ),
      title: Text(
        category.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        count == 0
            ? 'Sin movimientos'
            : '$count ${count == 1 ? 'movimiento' : 'movimientos'}',
        style: TextStyle(color: palette.muted),
      ),
      trailing: onTap == null
          ? null
          : Icon(CupertinoIcons.chevron_right, size: 16, color: palette.muted),
    );
  }
}

class _EmptyOwn extends StatelessWidget {
  const _EmptyOwn({required this.type});

  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return BentoCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              const Mascot(mood: MascotMood.happy, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aún no tienes categorías propias',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type == TransactionType.expense
                          ? 'Crea una para gastos como gimnasio o mascotas.'
                          : 'Crea una para ingresos como becas o ventas.',
                      style: TextStyle(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            onPressed: () => showCategorySheet(context, type: type),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Crear categoría'),
          ),
        ],
      ),
    );
  }
}
