import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../core/utils/onboarding_tour.dart';
import '../models/category.dart';
import '../screens/new_transaction_sheet.dart';
import 'ios_ui.dart';
import 'offline_banner.dart';
import 'onboarding_tour.dart';

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

/// Wraps the pages of the tabs other than Inicio (and Perfil): they're
/// reached with go(), so there's nothing to pop and the system back would
/// close the app. It returns to Inicio instead; only Inicio leaves the app.
///
/// It must sit inside the shell's own navigator (around the page, not the
/// shell): with Android's predictive back, that navigator tells the system
/// whether the app handles back from its top route's [PopScope].
class BackToHome extends StatelessWidget {
  const BackToHome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) context.go(_home.path);
    },
    child: child,
  );
}

/// Bottom bar, like iOS 26's tab bar: a capsule floating over the content
/// with four destinations around a "+" action and a gray lens that
/// slides under the selected tab. Perfil opens from the avatar on Inicio.
class AppDock extends StatelessWidget {
  const AppDock({super.key, required this.location, required this.onAdd});

  final String location;
  final VoidCallback onAdd;

  static const _tabs = [_home, _history, _goals, _metrics];
  static const _inset = 6.0;
  static const _addSlot = 64.0;

  /// The tabs the first-run tour points at.
  static final _tourSpots = {
    _history.path: TourSpot.history,
    _goals.path: TourSpot.goals,
    _metrics.path: TourSpot.analysis,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final height = 62.0 + 14.0 * (textScale - 1).clamp(0.0, 2.0);
    final selected = _tabs.indexWhere((tab) => location.startsWith(tab.path));
    final duration = Motion.of(context, Motion.slow);

    Widget item(_Tab tab) {
      final dockItem = _DockItem(
        tab: tab,
        height: height - _inset * 2,
        selected: location.startsWith(tab.path),
        onTap: () {
          if (location.startsWith(tab.path)) return;
          HapticFeedback.selectionClick();
          context.go(tab.path);
        },
      );
      final spot = _tourSpots[tab.path];
      return Expanded(
        child: spot == null
            ? dockItem
            : TourTarget(spot: spot, child: dockItem),
      );
    }

    final bar = LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - _inset * 2 - _addSlot) / 4;
        final left =
            _inset + selected * itemWidth + (selected >= 2 ? _addSlot : 0);
        return Stack(
          children: [
            // Slides with a transform (repaint only, no layout per frame).
            Positioned(
              top: _inset,
              bottom: _inset,
              left: 0,
              width: itemWidth,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: left),
                duration: duration,
                curve: Motion.spring,
                builder: (context, left, lens) =>
                    Transform.translate(offset: Offset(left, 0), child: lens),
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: selected < 0 ? 0 : 1,
                  // A neutral gray lens, like iOS 26's tab bar.
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: palette.fill,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.all(_inset),
                child: Row(
                  children: [
                    item(_home),
                    item(_history),
                    SizedBox(
                      width: _addSlot,
                      child: Align(
                        heightFactor: 1,
                        child: TourTarget(
                          spot: TourSpot.add,
                          child: _AddButton(onPressed: onAdd),
                        ),
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

    // Liquid-glass-like: the page behind is blurred and made more vivid
    // through a translucent fill with a light rim. On the web (costly blur)
    // and with high contrast it's a solid bar instead.
    final glass = false; // EXPERIMENT
    final shape = StadiumBorder(
      side: glass ? BorderSide.none : BorderSide(color: palette.hairline),
    );
    Widget surface = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: glass
            ? palette.card.withValues(alpha: dark ? .55 : .62)
            : palette.card,
      ),
      child: bar,
    );
    if (glass) {
      surface = ClipPath(
        clipper: const ShapeBorderClipper(shape: StadiumBorder()),
        child: BackdropFilter(
          filter: _glassFilter,
          child: CustomPaint(
            // The sheen under the icons, the rim over everything.
            painter: _GlassRimPainter(dark: dark, sheen: true),
            foregroundPainter: _GlassRimPainter(dark: dark),
            child: surface,
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: RepaintBoundary(
              child: Container(
                height: height,
                decoration: ShapeDecoration(
                  shape: shape,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? .45 : .08),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? .25 : .04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: surface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Blur plus extra saturation, so colors behind the glass glow through
  /// instead of turning grey.
  static final _glassFilter = ImageFilter.compose(
    outer: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
    inner: _saturate(1.7),
  );

  static ColorFilter _saturate(double s) {
    const r = .2126, g = .7152, b = .0722;
    return ColorFilter.matrix([
      r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }
}

/// The glass's edge: a thin rim lit from the top left that fades toward the
/// bottom right; with [sheen], a soft light along the top instead.
class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({required this.dark, this.sheen = false});

  final bool dark;
  final bool sheen;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(.5),
      Radius.circular(size.height / 2),
    );
    if (sheen) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Colors.white.withValues(alpha: dark ? .07 : .35),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
      return;
    }
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [
                Colors.white.withValues(alpha: .32),
                Colors.white.withValues(alpha: .06),
                Colors.white.withValues(alpha: .18),
              ]
            : [
                Colors.white.withValues(alpha: .95),
                Colors.white.withValues(alpha: .35),
                Colors.black.withValues(alpha: .08),
              ],
      ).createShader(rect);
    canvas.drawRRect(rrect, rim);
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.sheen != sheen;
}

/// Black circle with a lime "+"; squeezes when pressed.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PressScale(
      scale: .9,
      child: IconButton(
        tooltip: 'Registrar movimiento',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          // Black with a lime "+"; lime with a dark "+" in dark mode,
          // where the pill color is light.
          backgroundColor: dark ? palette.accent : palette.pill,
          foregroundColor: dark ? palette.onAccent : palette.accent,
          fixedSize: const Size.square(50),
          shape: const CircleBorder(),
        ),
        icon: const Icon(CupertinoIcons.add, size: 24),
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
          customBorder: const StadiumBorder(),
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
