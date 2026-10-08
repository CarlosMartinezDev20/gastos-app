import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/home_layout.dart';
import '../core/utils/phone_widget.dart';
import '../providers/finance_providers.dart';
import '../widgets/app_shell.dart';
import '../widgets/app_states.dart';
import '../widgets/home_cards.dart';
import '../widgets/ios_ui.dart';
import '../widgets/mascot.dart';
import '../widgets/phone_widget_preview.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/transaction_tile.dart';
import 'preview_support.dart';

@AppPreview(name: 'Estados de ánimo', group: 'Michi', size: Size(560, 170))
Widget mascotMoods() => Padding(
  padding: const EdgeInsets.all(12),
  child: Wrap(
    spacing: 8,
    children: [
      for (final mood in MascotMood.values)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Mascot(mood: mood, size: 96, onTap: () {}),
            Text(mood.name, style: const TextStyle(fontSize: 12)),
          ],
        ),
    ],
  ),
);

@AppPreview(name: 'Dock', group: 'Navegación', size: Size(420, 110))
Widget dock() => Align(
  alignment: Alignment.bottomCenter,
  child: AppDock(location: '/home', onAdd: () {}),
);

@AppPreview(
  name: 'Selector segmentado',
  group: 'Controles',
  size: Size(390, 80),
)
Widget segmentedTabs() =>
    const Padding(padding: EdgeInsets.all(16), child: _SegmentedDemo());

class _SegmentedDemo extends StatefulWidget {
  const _SegmentedDemo();

  @override
  State<_SegmentedDemo> createState() => _SegmentedDemoState();
}

class _SegmentedDemoState extends State<_SegmentedDemo> {
  String _selected = 'Semana';

  @override
  Widget build(BuildContext context) => SegmentedTabs(
    segments: const {'Semana': 'Semana', 'Mes': 'Mes', 'Año': 'Año'},
    selected: _selected,
    onChanged: (value) => setState(() => _selected = value),
  );
}

@AppPreview(name: 'Botones', group: 'Controles', size: Size(390, 240))
Widget buttons() => Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          CircleButton(
            icon: CupertinoIcons.moon,
            tooltip: 'Circular',
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          CircleButton(
            icon: CupertinoIcons.add,
            tooltip: 'Circular relleno',
            filled: true,
            onPressed: () {},
          ),
        ],
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: () {}, child: const Text('Guardar gasto')),
      const SizedBox(height: 12),
      PillCta(label: 'Comenzar', onPressed: () {}),
    ],
  ),
);

@AppPreview(name: 'Tarjetas bento', group: 'Tarjetas', size: Size(390, 260))
Widget bentoCards() => Builder(
  builder: (context) {
    final palette = context.palette;
    Widget tile(String label, Color bg, Color fg) => Expanded(
      child: BentoCard(
        color: bg,
        child: Text(
          label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              tile('ink', palette.ink, palette.onInk),
              const SizedBox(width: 12),
              tile('mint', palette.mint, palette.onMint),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              tile('blush', palette.blush, palette.onBlush),
              const SizedBox(width: 12),
              tile('lilac', palette.lilac, palette.onLilac),
            ],
          ),
          const SizedBox(height: 12),
          const SectionHeader(title: 'Sección', action: 'Ver todo'),
        ],
      ),
    );
  },
);

@AppPreview(name: 'Movimientos', group: 'Listas', size: Size(390, 340))
Widget transactionTiles() => Padding(
  padding: const EdgeInsets.all(16),
  child: BentoCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Column(
      children: [
        for (final (i, t) in previewTransactions.indexed) ...[
          if (i > 0) const Divider(indent: 58),
          TransactionTile(transaction: t),
        ],
      ],
    ),
  ),
);

@AppPreview(name: 'Estado vacío', group: 'Estados', size: Size(390, 260))
Widget emptyState() => const AppEmptyState(
  title: 'Sin movimientos',
  subtitle: 'Registra tu primer ingreso o gasto.',
);

@AppPreview(name: 'Burbuja de Michi', group: 'Michi', size: Size(390, 200))
Widget speechBubble() => Builder(
  builder: (context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Mascot(mood: MascotMood.happy, size: 72),
          const SizedBox(height: 10),
          SpeechBubble(
            color: palette.ink,
            tailUpAt: .9,
            child: Text(
              '¡Miau! Vas muy bien: gastaste el 48% de tus ingresos.',
              style: TextStyle(color: palette.onInk),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 1,
            child: BentoCard(
              color: palette.mint,
              onTap: () {},
              child: Text(
                'Tarjeta con entrada animada',
                style: TextStyle(color: palette.onMint),
              ),
            ),
          ),
        ],
      ),
    );
  },
);

@AppPreview(name: 'Cabecera', group: 'Controles', size: Size(390, 110))
Widget largeTitle() => const Padding(
  padding: EdgeInsets.all(16),
  child: LargeTitle(
    title: 'Metas',
    subtitle: 'Ahorra para lo que de verdad quieres',
    trailing: [_DayNightDemo()],
  ),
);

class _DayNightDemo extends StatefulWidget {
  const _DayNightDemo();

  @override
  State<_DayNightDemo> createState() => _DayNightDemoState();
}

class _DayNightDemoState extends State<_DayNightDemo> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) => DayNightButton(
    value: _dark,
    onChanged: (value) => setState(() => _dark = value),
  );
}

@AppPreview(name: 'Widgets de Inicio', group: 'Inicio', size: Size(390, 900))
Widget homeCards() {
  final data = previewDashboard();
  Widget card(
    HomeWidgetType type,
    HomeWidgetSize size,
    HomeWidgetStyle style,
  ) => HomeCard(config: HomeWidgetConfig(type, size, style), data: data);
  return ProviderScope(
    overrides: [budgetsProvider.overrideWith((ref) async => const [])],
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: card(
                    HomeWidgetType.week,
                    HomeWidgetSize.compact,
                    HomeWidgetStyle.lilac,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: card(
                    HomeWidgetType.goals,
                    HomeWidgetSize.compact,
                    HomeWidgetStyle.aurora,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          card(
            HomeWidgetType.cashflow,
            HomeWidgetSize.wide,
            HomeWidgetStyle.ink,
          ),
          const SizedBox(height: 12),
          card(HomeWidgetType.goals, HomeWidgetSize.wide, HomeWidgetStyle.mint),
          const SizedBox(height: 12),
          card(
            HomeWidgetType.quickAdd,
            HomeWidgetSize.wide,
            HomeWidgetStyle.accent,
          ),
        ],
      ),
    ),
  );
}

@AppPreview(name: 'Widget del teléfono', group: 'Inicio', size: Size(390, 420))
Widget phoneWidgets() => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      for (final (i, theme) in PhoneWidgetTheme.values.indexed)
        PhoneWidgetPreview(
          payload: phoneWidgetPayload(
            previewDashboard(),
            content: PhoneWidgetContent.values[i % 3],
            theme: theme,
            balanceHidden: false,
            now: DateTime.now(),
          ),
        ),
    ],
  ),
);

@AppPreview(name: 'Monto animado', group: 'Controles', size: Size(390, 140))
Widget animatedAmounts() => const _AmountDemo();

/// Tap to change the amount and watch it glide to the new value.
class _AmountDemo extends StatefulWidget {
  const _AmountDemo();

  @override
  State<_AmountDemo> createState() => _AmountDemoState();
}

class _AmountDemoState extends State<_AmountDemo> {
  var _value = 782.15;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _value = _value > 500 ? 137.85 : 782.15),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: AnimatedAmount(
        _value,
        style: Theme.of(context).textTheme.displaySmall,
      ),
    ),
  );
}
