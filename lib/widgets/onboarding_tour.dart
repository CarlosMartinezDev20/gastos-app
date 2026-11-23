import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/motion.dart';
import '../core/utils/onboarding_tour.dart';
import '../models/category.dart';
import '../providers/onboarding_provider.dart';
import '../screens/new_transaction_sheet.dart';
import 'ios_ui.dart';
import 'mascot.dart';

/// Marks a part of the app the first-run tour can highlight. Renders
/// [child] unchanged.
class TourTarget extends StatefulWidget {
  const TourTarget({super.key, required this.spot, required this.child});

  final TourSpot spot;
  final Widget child;

  /// The latest mounted target of each spot (no GlobalKeys: a spot can be
  /// built twice for a moment, e.g. during a page transition).
  static final _mounted = <TourSpot, BuildContext>{};

  /// Where [spot] is on screen, in global coordinates, if it's laid out.
  static Rect? rectOf(TourSpot spot) {
    final context = _mounted[spot];
    if (context == null || !context.mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  @override
  void initState() {
    super.initState();
    TourTarget._mounted[widget.spot] = context;
  }

  @override
  void didUpdateWidget(TourTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spot != widget.spot) {
      _forget(oldWidget.spot);
      TourTarget._mounted[widget.spot] = context;
    }
  }

  @override
  void dispose() {
    _forget(widget.spot);
    super.dispose();
  }

  void _forget(TourSpot spot) {
    if (identical(TourTarget._mounted[spot], context)) {
      TourTarget._mounted.remove(spot);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// How the tour ended. Null when it was dismissed with the system back.
enum TourOutcome { finished, skipped, addMovement }

/// Shows the tour over the whole app (dock included).
Future<TourOutcome?> showOnboardingTour(
  BuildContext context, {
  List<TourStep> steps = onboardingSteps,
}) {
  final duration = Motion.of(context, Motion.medium);
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<TourOutcome>(
      opaque: false,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, _, _) => OnboardingTourOverlay(steps: steps),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Motion.standard,
          reverseCurve: Motion.exit,
        ),
        child: child,
      ),
    ),
  );
}

/// Starts the tour on Inicio for someone new (once per user and device),
/// or when Perfil asked for it again. Renders [child] unchanged.
class OnboardingTourStarter extends ConsumerStatefulWidget {
  const OnboardingTourStarter({
    super.key,
    required this.hasMovements,
    required this.child,
  });

  final bool hasMovements;
  final Widget child;

  @override
  ConsumerState<OnboardingTourStarter> createState() =>
      _OnboardingTourStarterState();
}

class _OnboardingTourStarterState extends ConsumerState<OnboardingTourStarter> {
  /// Lets Inicio's entrance finish, so the highlights land on settled
  /// widgets.
  static const _delay = Duration(milliseconds: 800);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _maybeStart() {
    if (!mounted || (_timer?.isActive ?? false)) return;
    final requested = ref.read(onboardingTourProvider);
    final tour = ref.read(onboardingTourProvider.notifier);
    if (!requested &&
        !shouldAutoStartTour(
          seen: tour.seen,
          hasMovements: widget.hasMovements,
        )) {
      return;
    }
    _timer = Timer(Motion.of(context, _delay), _start);
  }

  Future<void> _start() async {
    if (!mounted) return;
    // A sheet or page covers Inicio: it's offered again next time.
    if (Navigator.of(context, rootNavigator: true).canPop()) return;
    ref.read(onboardingTourProvider.notifier).started();
    final outcome = await showOnboardingTour(context);
    if (outcome == TourOutcome.addMovement && mounted) {
      await showNewTransactionSheet(
        context,
        initialType: TransactionType.expense,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onboardingTourProvider, (_, requested) {
      if (requested) _maybeStart();
    });
    return widget.child;
  }
}

/// The tour itself: the screen dims except for the step's spot, and Michi
/// explains it in a card beside it.
class OnboardingTourOverlay extends StatefulWidget {
  const OnboardingTourOverlay({super.key, this.steps = onboardingSteps});

  final List<TourStep> steps;

  @override
  State<OnboardingTourOverlay> createState() => _OnboardingTourOverlayState();
}

class _OnboardingTourOverlayState extends State<OnboardingTourOverlay>
    with SingleTickerProviderStateMixin {
  /// Room around the highlighted widget.
  static const _holePadding = 6.0;

  /// The steps shown (indexes into the steps): those whose spot was on
  /// Inicio when the tour started. Fixed then, because scrolling to a spot
  /// can unbuild another one for a while.
  late final List<int> _shown;
  var _at = 0;
  Rect? _hole;
  Size? _size;

  /// The scroll moved to reveal a spot, and where it was before.
  ScrollPosition? _scrolled;
  double _scrolledFrom = 0;

  /// A ring that ripples out of the spot twice when it's highlighted.
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  TourStep get _step => widget.steps[_shown[_at]];

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _shown = tourStepsOnScreen(
      widget.steps,
      (spot) => TourTarget.rectOf(spot) != null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rotation or a resized window moves the spot.
    final size = MediaQuery.sizeOf(context);
    if (_size != null && _size != size) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
    }
    _size = size;
  }

  /// Scrolls the step's spot into view if it's hidden and measures it; once
  /// more after the frame, when a scroll has been laid out.
  void _locate() {
    if (!mounted) return;
    final spot = _step.spot;
    if (spot == null) {
      setState(() => _hole = null);
      return;
    }
    final rect = TourTarget.rectOf(spot);
    final target = TourTarget._mounted[spot];
    final media = MediaQuery.of(context);
    // The tab pages' slim title bar and the dock cover the edges.
    final hidden =
        rect == null ||
        rect.top < media.padding.top + 56 ||
        rect.bottom > media.size.height - media.padding.bottom - 96;
    final scrollable = target == null ? null : Scrollable.maybeOf(target);
    if (hidden && target != null && scrollable != null) {
      if (_scrolled == null) {
        _scrolled = scrollable.position;
        _scrolledFrom = scrollable.position.pixels;
      }
      Scrollable.ensureVisible(target, alignment: .15);
    }
    setState(() => _hole = _toLocal(rect));
    if (!Motion.reduced(context)) {
      // After the hole has moved there.
      _pulse
        ..value = 0
        ..repeat(count: 2);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _step.spot != spot) return;
      final hole = _toLocal(TourTarget.rectOf(spot));
      if (hole != _hole) setState(() => _hole = hole);
    });
  }

  /// Puts back a scroll [_locate] moved. True if it did.
  bool _restoreScroll() {
    final position = _scrolled;
    _scrolled = null;
    if (position == null || !position.hasPixels) return false;
    position.jumpTo(_scrolledFrom);
    return true;
  }

  Rect? _toLocal(Rect? global) {
    final box = context.findRenderObject();
    if (global == null || box is! RenderBox || !box.hasSize) return global;
    return box.globalToLocal(global.topLeft) & global.size;
  }

  Future<void> _go(int direction) async {
    final next = _at + direction;
    if (next >= _shown.length) return _close(TourOutcome.finished);
    if (next < 0) return;
    HapticFeedback.selectionClick();
    // The spots scrolled away are built again before measuring them.
    if (_restoreScroll()) await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _at = next);
    _locate();
  }

  /// Tapping what's highlighted moves on, as people tend to try.
  void _tapAt(Offset position) {
    final hole = _step.spot == null ? null : _hole;
    if (hole != null && hole.inflate(_holePadding).contains(position)) _go(1);
  }

  void _close(TourOutcome outcome) {
    _restoreScroll();
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final media = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final step = _step;
    final hole = step.spot == null ? null : _hole?.inflate(_holePadding);
    final safe = Rect.fromLTRB(
      media.padding.left + 16,
      media.padding.top + 12,
      media.size.width - media.padding.right - 16,
      media.size.height - media.padding.bottom - 12,
    );
    final placement = tourCardArea(
      safe: safe,
      hole: hole,
      // Large text needs a taller card.
      minRoom: 180 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
    );
    final last = _at == _shown.length - 1;
    final first = _at == 0;

    // The card is centered in its area, at most _TourCard.maxWidth wide.
    final area = placement.area;
    final cardWidth = area.width.clamp(0.0, _TourCard.maxWidth);
    final cardLeft = area.center.dx - cardWidth / 2;
    // Michi stands on the spot's side of the card and looks at it; the
    // card's tail points at it unless the card had to cover it.
    final beside = hole != null && area != safe;
    final michiOnRight = hole != null && hole.center.dx > area.center.dx;
    Offset? gaze;
    if (hole != null) {
      final michiX = michiOnRight
          ? cardLeft + cardWidth - _TourCard.michiInset
          : cardLeft + _TourCard.michiInset;
      final michiY = placement.below
          ? area.top + _TourCard.michiInset
          : area.bottom - _TourCard.michiInset * 2;
      gaze = tourGaze(Offset(michiX, michiY), hole.center);
    }

    final card = _TourCard(
      step: step,
      number: _at + 1,
      total: _shown.length,
      michiOnRight: michiOnRight,
      gaze: gaze,
      tailAt: beside
          ? ((hole.center.dx - cardLeft) / cardWidth).clamp(.1, .9)
          : null,
      tailUp: placement.below,
      actions: [
        TextButton(
          onPressed: () =>
              _close(last ? TourOutcome.finished : TourOutcome.skipped),
          child: Text(last ? 'Más tarde' : 'Omitir'),
        ),
        if (!first)
          TextButton(onPressed: () => _go(-1), child: const Text('Atrás')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: last
              ? () => _close(TourOutcome.addMovement)
              : () => _go(1),
          child: Text(last ? 'Registrar movimiento' : 'Siguiente'),
        ),
      ],
    );

    // Covers the routes below for screen readers; taps outside the card only
    // move on when they land on the highlighted spot (the overlay is hit
    // before anything under it).
    return BlockSemantics(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _tapAt(details.localPosition),
              child: TweenAnimationBuilder<Rect?>(
                // Without a spot the hole closes into the middle.
                tween: RectTween(
                  end:
                      hole ??
                      Rect.fromCenter(
                        center: media.size.center(Offset.zero),
                        width: 0,
                        height: 0,
                      ),
                ),
                duration: Motion.of(context, Motion.slow),
                curve: Motion.standard,
                builder: (context, rect, _) => CustomPaint(
                  painter: _SpotlightPainter(
                    hole: rect,
                    pulse: _pulse,
                    color: Colors.black.withValues(alpha: dark ? .72 : .58),
                    ring: palette.accent,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.medium),
              switchInCurve: Motion.standard,
              switchOutCurve: Motion.exit,
              child: Stack(
                key: ValueKey(_at),
                children: [
                  Positioned.fromRect(
                    rect: area,
                    child: Align(
                      alignment: hole == null
                          ? Alignment.center
                          : placement.below
                          ? Alignment.topCenter
                          : Alignment.bottomCenter,
                      child: card,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Michi and what it says about the step, in a speech card whose tail
/// points at the spot.
class _TourCard extends StatefulWidget {
  const _TourCard({
    required this.step,
    required this.number,
    required this.total,
    required this.actions,
    required this.michiOnRight,
    required this.tailUp,
    this.gaze,
    this.tailAt,
  });

  static const maxWidth = 400.0;
  static const _michiSize = 60.0;

  /// From the card's edge to Michi's center.
  static const michiInset = 16 + _michiSize / 2;

  final TourStep step;
  final int number;
  final int total;
  final List<Widget> actions;
  final bool michiOnRight;
  final Offset? gaze;

  /// Where along the card's width (0–1) the tail points, on the top edge
  /// when [tailUp] and on the bottom otherwise. No tail when null.
  final double? tailAt;
  final bool tailUp;

  @override
  State<_TourCard> createState() => _TourCardState();
}

class _TourCardState extends State<_TourCard>
    with SingleTickerProviderStateMixin {
  /// The body appears letter by letter while Michi "says" it, after its
  /// pop-in.
  late final _typing = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: 300 + 22 * widget.step.body.length.clamp(0, 140),
    ),
  );
  late final _shown = CurvedAnimation(
    parent: _typing,
    curve: const Interval(.12, 1),
  );
  final _michi = MascotController();
  Timer? _cue;
  Timer? _quipTimer;
  String? _quip;
  static var _quips = 0;

  @override
  void initState() {
    super.initState();
    _typing.addStatusListener((_) => setState(() {}));
    // After the pop-in, Michi greets the step.
    _cue = Timer(const Duration(milliseconds: 450), () {
      if (widget.step.celebrate) {
        HapticFeedback.mediumImpact();
        _michi.celebrate();
      } else {
        _michi.react(widget.step.reaction);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _typing.value = 1;
    } else if (_typing.isDismissed) {
      _typing.forward();
    }
  }

  @override
  void dispose() {
    _cue?.cancel();
    _quipTimer?.cancel();
    _shown.dispose();
    _typing.dispose();
    _michi.dispose();
    super.dispose();
  }

  /// A tap on Michi: it reacts (by itself) and says something.
  void _tapMichi() {
    HapticFeedback.lightImpact();
    _typing.value = 1;
    setState(() => _quip = tourQuips[_quips++ % tourQuips.length]);
    _quipTimer?.cancel();
    _quipTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _quip = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final step = widget.step;
    final talking = _typing.isAnimating;
    final michi = ExcludeSemantics(
      child: Mascot(
        size: _TourCard._michiSize,
        mood: step.mood,
        gaze: widget.gaze,
        talking: talking,
        controller: _michi,
        onTap: _tapMichi,
      ),
    );
    final words = Expanded(
      child: Column(
        crossAxisAlignment: widget.michiOnRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            'Paso ${widget.number} de ${widget.total}',
            style: text.labelSmall?.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            step.title,
            style: text.titleMedium,
            textAlign: widget.michiOnRight ? TextAlign.end : TextAlign.start,
          ),
          const SizedBox(height: 4),
          // The whole text is laid out from the start (the rest is
          // transparent), so the card doesn't grow while it types. A tap
          // shows it all at once.
          GestureDetector(
            onTap: () => _typing.value = 1,
            child: Semantics(
              label: step.body,
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _shown,
                  builder: (context, _) {
                    final cut = (step.body.length * _shown.value).round();
                    return Text.rich(
                      TextSpan(
                        style: text.bodyMedium,
                        children: [
                          TextSpan(text: step.body.substring(0, cut)),
                          TextSpan(
                            text: step.body.substring(cut),
                            style: const TextStyle(color: Colors.transparent),
                          ),
                        ],
                      ),
                      textAlign: widget.michiOnRight
                          ? TextAlign.end
                          : TextAlign.start,
                    );
                  },
                ),
              ),
            ),
          ),
          // What Michi says when tapped, in a small bubble of its own.
          AnimatedSize(
            duration: Motion.of(context, Motion.medium),
            curve: Motion.standard,
            alignment: Alignment.topCenter,
            child: _quip == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Semantics(
                      liveRegion: true,
                      child: SpeechBubble(
                        color: palette.mint,
                        tailUpAt: widget.michiOnRight ? .92 : .08,
                        child: Text(
                          _quip!,
                          style: text.bodySmall?.copyWith(
                            color: palette.onMint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );

    final shape = _SpeechCardBorder(
      radius: 24,
      tailAt: widget.tailAt,
      tailUp: widget.tailUp,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _TourCard.maxWidth),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: palette.card,
          shape: shape,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // With large text only the words scroll: the buttons stay.
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.michiOnRight
                          ? [words, const SizedBox(width: 12), michi]
                          : [michi, const SizedBox(width: 12), words],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 8,
                  children: widget.actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A continuous-corner card with a small tail on its top or bottom edge,
/// like a speech bubble pointing at the highlighted spot.
class _SpeechCardBorder extends ShapeBorder {
  const _SpeechCardBorder({
    required this.radius,
    required this.tailAt,
    required this.tailUp,
  });

  final double radius;
  final double? tailAt;
  final bool tailUp;

  static const _tailWidth = 22.0;
  static const _tailHeight = 10.0;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = AppTheme.continuous(
      radius,
    ).getOuterPath(rect, textDirection: textDirection);
    final at = tailAt;
    if (at == null) return body;
    final x = (rect.left + rect.width * at).clamp(
      rect.left + radius + _tailWidth / 2,
      rect.right - radius - _tailWidth / 2,
    );
    final edge = tailUp ? rect.top : rect.bottom;
    final tip = tailUp ? edge - _tailHeight : edge + _tailHeight;
    // Overlaps the body a little so the seam doesn't show.
    final base = tailUp ? edge + 1 : edge - 1;
    final tail = Path()
      ..moveTo(x - _tailWidth / 2, base)
      ..quadraticBezierTo(x - 3, base, x, tip)
      ..quadraticBezierTo(x + 3, base, x + _tailWidth / 2, base)
      ..close();
    return Path.combine(PathOperation.union, body, tail);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) =>
      _SpeechCardBorder(radius: radius * t, tailAt: tailAt, tailUp: tailUp);

  @override
  bool operator ==(Object other) =>
      other is _SpeechCardBorder &&
      other.radius == radius &&
      other.tailAt == tailAt &&
      other.tailUp == tailUp;

  @override
  int get hashCode => Object.hash(radius, tailAt, tailUp);
}

/// Dims everything but [hole], outlined with a thin [ring] that ripples
/// outwards with [pulse].
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.hole,
    required this.pulse,
    required this.color,
    required this.ring,
  }) : super(repaint: pulse);

  final Rect? hole;
  final Animation<double> pulse;
  final Color color;
  final Color ring;

  static RRect _rounded(Rect rect) {
    // Small spots (buttons, tabs) are capsules or circles, like the widgets
    // they surround; cards keep a card's corner.
    final side = rect.shortestSide;
    return RRect.fromRectAndRadius(
      rect,
      Radius.circular(side < 72 ? side / 2 : 28),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final hole = this.hole;
    final visible = hole != null && hole.shortestSide > 8;
    if (hole != null && !hole.isEmpty) path.addRRect(_rounded(hole));
    canvas.drawPath(path, Paint()..color = color);
    if (!visible) return;
    canvas.drawRRect(
      _rounded(hole),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
    final p = pulse.value;
    if (p > 0 && p < 1) {
      final eased = Curves.easeOut.transform(p);
      canvas.drawRRect(
        _rounded(hole.inflate(eased * 14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - eased)
          ..color = ring.withValues(alpha: .8 * (1 - eased)),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.pulse != pulse ||
      oldDelegate.color != color ||
      oldDelegate.ring != ring;
}
