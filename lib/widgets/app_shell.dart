import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../models/category.dart';
import '../screens/new_transaction_sheet.dart';
import 'ios_ui.dart';
import 'offline_banner.dart';

class _Tab {
  const _Tab(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _home = _Tab(
  '/home',
  'Inicio',
  CupertinoIcons.house,
  CupertinoIcons.house_fill,
);
const _history = _Tab(
  '/transactions',
  'Historial',
  CupertinoIcons.arrow_right_arrow_left,
  CupertinoIcons.arrow_right_arrow_left,
);
const _goals = _Tab(
  '/goals',
  'Metas',
  CupertinoIcons.flag,
  CupertinoIcons.flag_fill,
);
const _metrics = _Tab(
  '/metrics',
  'Análisis',
  CupertinoIcons.chart_pie,
  CupertinoIcons.chart_pie_fill,
);

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    // Sheets and full-screen pages open above the shell: while they do, the
    // tabs pause and don't follow their keyboard.
    return PauseWhenCovered(
      child: Scaffold(
        // Content scrolls behind the dock's rounded corners; pages pad their
        // scroll views with dockClearance().
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: location.startsWith('/home') ? 1080 : 760,
                  ),
                  child: child,
                ),
              ),
              // Over the page, not above it: showing it doesn't reflow.
              const Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: OfflineBanner(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: KeyboardVisibilityBuilder(
          // Hidden for the tabs' own fields; a sheet's keyboard leaves it be
          // (the shell is covered, so relaying it out would be wasted).
          builder: (context, keyboardOpen) =>
              keyboardOpen && (ModalRoute.isCurrentOf(context) ?? true)
              ? const SizedBox.shrink()
              : AppDock(
                  location: location,
                  onAdd: () => showNewTransactionSheet(
                    context,
                    initialType: TransactionType.expense,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Bottom bar: four destinations around a "+" action, with a lime marker
/// that slides to the selected tab. On phones it is anchored to the bottom
/// edge with rounded top corners; on wider screens it floats.
/// Perfil opens from the avatar on Inicio.
class AppDock extends StatelessWidget {
  const AppDock({super.key, required this.location, required this.onAdd});

  final String location;
  final VoidCallback onAdd;

  static const _tabs = [_home, _history, _goals, _metrics];
  static const _sidePadding = 8.0;
  static const _addSlot = 64.0;
  static const _floatingMinWidth = 600.0;
  static const _marker = Size(22, 4);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final height = 64.0 + 14.0 * (textScale - 1).clamp(0.0, 2.0);
    final selected = _tabs.indexWhere((tab) => location.startsWith(tab.path));
    final floating = MediaQuery.sizeOf(context).width >= _floatingMinWidth;
    final duration = Motion.of(context, Motion.slow);

    Widget item(_Tab tab) => Expanded(
      child: _DockItem(
        tab: tab,
        height: height,
        selected: location.startsWith(tab.path),
        onTap: () {
          if (location.startsWith(tab.path)) return;
          HapticFeedback.selectionClick();
          context.go(tab.path);
        },
      ),
    );

    final bar = LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - _sidePadding * 2 - _addSlot) / 4;
        final center =
            _sidePadding +
            (selected + .5) * itemWidth +
            (selected >= 2 ? _addSlot : 0);
        return Stack(
          children: [
            // Slides with a transform (repaint only, no layout per frame).
            Positioned(
              top: 0,
              left: 0,
              width: _marker.width,
              height: _marker.height,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: center - _marker.width / 2),
                duration: duration,
                curve: Motion.standard,
                builder: (context, left, marker) =>
                    Transform.translate(offset: Offset(left, 0), child: marker),
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: selected < 0 ? 0 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
                child: Row(
                  children: [
                    item(_home),
                    item(_history),
                    SizedBox(
                      width: _addSlot,
                      child: Align(
                        heightFactor: 1,
                        child: _AddButton(onPressed: onAdd),
                      ),
                    ),
                    item(_goals),
                    item(_metrics),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: dark ? .35 : .07),
      blurRadius: 24,
      offset: Offset(0, floating ? 8 : -4),
    );

    // Solid (no backdrop blur): blurring the page behind the dock on every
    // scroll frame is expensive, especially on the web.
    if (floating) {
      return SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: RepaintBoundary(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: palette.hairline),
                  boxShadow: [shadow],
                ),
                child: bar,
              ),
            ),
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: palette.hairline)),
          boxShadow: [shadow],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 6),
          child: bar,
        ),
      ),
    );
  }
}

/// Black rounded square with a lime "+"; squeezes and turns when pressed.
class _AddButton extends StatefulWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final duration = Motion.of(context, Motion.fast);
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? .9 : 1,
        duration: duration,
        curve: Motion.standard,
        child: IconButton(
          tooltip: 'Registrar movimiento',
          onPressed: widget.onPressed,
          style: IconButton.styleFrom(
            // Black with a lime "+"; lime with a dark "+" in dark mode,
            // where the pill color is light.
            backgroundColor: dark ? palette.accent : palette.pill,
            foregroundColor: dark ? palette.onAccent : palette.accent,
            fixedSize: const Size.square(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          icon: AnimatedRotation(
            turns: _pressed ? .125 : 0,
            duration: duration,
            curve: Motion.standard,
            child: const Icon(CupertinoIcons.add, size: 24),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.height,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected
        ? Theme.of(context).colorScheme.onSurface
        : palette.muted;
    final duration = Motion.of(context, Motion.medium);
    return Tooltip(
      message: tab.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: palette.hairline.withValues(alpha: .35),
          child: SizedBox(
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The selected icon fills in with a small pop.
                AnimatedScale(
                  scale: selected ? 1.1 : 1,
                  duration: duration,
                  curve: Motion.spring,
                  child: Icon(
                    selected ? tab.selectedIcon : tab.icon,
                    size: 22,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
