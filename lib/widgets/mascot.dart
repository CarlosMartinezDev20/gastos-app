import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/utils/mascot_insights.dart';

export '../core/utils/mascot_insights.dart' show MascotMood, MascotTip;

const mascotName = 'Michi';

/// Michi, the kitten mascot. Drawn in code (no assets).
///
/// While idle it breathes, blinks, twitches an ear, sways its tail and looks
/// around (or follows the mouse pointer), and every few seconds does
/// something on its own: yawns, grooms a paw, looks around or stretches.
/// Taps cycle a jump with hearts, a purring wiggle and a paw wave; a long
/// press pets it (it purrs, blushes and floats hearts). Its eyes, ears,
/// mouth and tail follow [mood]; it pops in when it appears or its mood
/// changes, with confetti when it becomes excited.
///
/// Forms can steer it: [gaze] points its eyes (e.g. at the text being typed)
/// and [coverEyes] makes it hide its eyes behind its paws, peeking through
/// one paw when [peek] is set (a password being shown).
class Mascot extends StatefulWidget {
  const Mascot({
    super.key,
    this.mood = MascotMood.happy,
    this.size = 96,
    this.onTap,
    this.gaze,
    this.coverEyes = false,
    this.peek = false,
  });

  /// Looping animations never settle, so widget tests turn them off.
  static bool animate = true;

  /// Picks the spontaneous actions; tests can make it predictable.
  @visibleForTesting
  static math.Random random = math.Random();

  final MascotMood mood;
  final double size;
  final VoidCallback? onTap;

  /// Where to look, from (-1, -1) top-left to (1, 1) bottom-right. Overrides
  /// the mouse pointer while set.
  final Offset? gaze;
  final bool coverEyes;
  final bool peek;

  @override
  State<Mascot> createState() => _MascotState();
}

enum _Reaction { jump, wiggle, wave }

/// Things Michi does on its own while idle.
enum _Action { none, yawn, groom, lookAround, stretch }

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  late final _react = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
    value: 1,
  );
  late final _cover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: widget.coverEyes ? 1 : 0,
  );
  late final _peek = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.peek ? 1 : 0,
  );
  late final _act = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final _pet = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Where the eyes look, smoothed towards [_pointer] on every idle tick.
  final _look = ValueNotifier(Offset.zero);
  Offset? _pointer;

  var _reaction = _Reaction.jump;
  var _action = _Action.none;
  var _taps = 0;

  /// Idle loops left before the next spontaneous action.
  var _loopsToAction = 2;
  var _lastIdle = 0.0;
  var _popFrom = 1.0;
  var _enabled = false;
  var _mounted = false;

  @override
  void initState() {
    super.initState();
    _look.value = widget.gaze ?? Offset.zero;
    _idle.addListener(_followPointer);
    _idle.addListener(_maybeAct);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = Mascot.animate && !MediaQuery.disableAnimationsOf(context);
    final firstTime = !_mounted;
    _mounted = true;
    if (enabled == _enabled) return;
    _enabled = enabled;
    if (enabled) {
      _idle.repeat();
      if (firstTime) _popIn(from: .2);
    } else {
      _idle
        ..stop()
        ..value = 0;
      for (final c in [_react, _act, _pet, _confetti]) {
        c
          ..stop()
          ..value = 0;
      }
      _pop.value = 1;
      _look.value = widget.gaze ?? Offset.zero;
    }
  }

  @override
  void didUpdateWidget(Mascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood && _enabled) {
      _popIn(from: .86);
      if (widget.mood == MascotMood.excited) _confetti.forward(from: 0);
    }
    _toggle(_cover, widget.coverEyes);
    _toggle(_peek, widget.peek);
    if (!_enabled) _look.value = widget.gaze ?? Offset.zero;
  }

  void _toggle(AnimationController controller, bool on) {
    if (!_enabled) {
      controller.value = on ? 1 : 0;
    } else if (on && controller.status != AnimationStatus.forward) {
      controller.forward();
    } else if (!on && controller.status != AnimationStatus.reverse) {
      controller.reverse();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _react.dispose();
    _pop.dispose();
    _cover.dispose();
    _peek.dispose();
    _act.dispose();
    _pet.dispose();
    _confetti.dispose();
    _look.dispose();
    super.dispose();
  }

  void _popIn({required double from}) {
    _popFrom = from;
    _pop.forward(from: 0);
  }

  void _followPointer() {
    final next = Offset.lerp(
      _look.value,
      widget.gaze ?? _pointer ?? Offset.zero,
      .12,
    )!;
    if ((next - _look.value).distanceSquared > 1e-5) _look.value = next;
  }

  /// Counts idle loops and, now and then, starts a spontaneous action that
  /// fits the mood (no timers: it rides on the idle animation).
  void _maybeAct() {
    final t = _idle.value;
    final wrapped = t < _lastIdle;
    _lastIdle = t;
    if (!wrapped || --_loopsToAction > 0) return;
    _loopsToAction = 2 + Mascot.random.nextInt(2);
    final busy =
        _react.isAnimating ||
        _act.isAnimating ||
        _pet.value > 0 ||
        widget.coverEyes ||
        widget.gaze != null;
    if (busy) return;
    final options = switch (widget.mood) {
      MascotMood.sleepy => const [_Action.yawn, _Action.yawn, _Action.stretch],
      MascotMood.worried => const [_Action.lookAround],
      MascotMood.excited => const [_Action.lookAround, _Action.stretch],
      _ => const [
        _Action.yawn,
        _Action.groom,
        _Action.lookAround,
        _Action.stretch,
      ],
    };
    setState(() => _action = options[Mascot.random.nextInt(options.length)]);
    _act.forward(from: 0);
  }

  void _startPetting() {
    if (!_enabled) return;
    _act.stop();
    _act.value = 0;
    _pet.forward();
  }

  void _stopPetting() {
    if (_enabled) _pet.reverse();
  }

  void _hover(PointerEvent event) {
    final half = widget.size / 2;
    final offset = (event.localPosition - Offset(half, half * .9)) / half;
    final distance = offset.distance;
    _pointer = distance > 1 ? offset / distance : offset;
  }

  void _handleTap() {
    if (_enabled) {
      setState(() {
        _reaction = _Reaction.values[_taps % _Reaction.values.length];
        _taps++;
      });
      _act
        ..stop()
        ..value = 0;
      _react.forward(from: 0);
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$mascotName, tu gatito',
      hint: 'Mantén presionado para acariciarlo',
      button: widget.onTap != null,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onHover: _hover,
        onExit: (_) => _pointer = null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          onLongPressStart: (_) => _startPetting(),
          onLongPressEnd: (_) => _stopPetting(),
          onLongPressCancel: _stopPetting,
          child: RepaintBoundary(
            child: SizedBox.square(
              dimension: widget.size,
              child: CustomPaint(
                painter: _KittenPainter(
                  idle: _idle,
                  react: _react,
                  pop: _pop,
                  look: _look,
                  cover: _cover,
                  peek: _peek,
                  act: _act,
                  pet: _pet,
                  confetti: _confetti,
                  popFrom: _popFrom,
                  reaction: _reaction,
                  action: _action,
                  mood: widget.mood,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _tau = 2 * math.pi;

class _KittenPainter extends CustomPainter {
  _KittenPainter({
    required this.idle,
    required this.react,
    required this.pop,
    required this.look,
    required this.cover,
    required this.peek,
    required this.act,
    required this.pet,
    required this.confetti,
    required this.popFrom,
    required this.reaction,
    required this.action,
    required this.mood,
  }) : super(
         repaint: Listenable.merge([
           idle,
           react,
           pop,
           look,
           cover,
           peek,
           act,
           pet,
           confetti,
         ]),
       );

  final Animation<double> idle;
  final Animation<double> react;
  final Animation<double> pop;
  final ValueNotifier<Offset> look;
  final Animation<double> cover;
  final Animation<double> peek;
  final Animation<double> act;
  final Animation<double> pet;
  final Animation<double> confetti;
  final double popFrom;
  final _Reaction reaction;
  final _Action action;
  final MascotMood mood;

  // A ginger tabby with a cream muzzle and a gold coin on its collar.
  static const _fur = Color(0xFFFFB760);
  static const _furLight = Color(0xFFFFDDB0);
  static const _furDark = Color(0xFFF09A45);
  static const _stripe = Color(0xFFDC7B2E);
  static const _cream = Color(0xFFFFF4E4);
  static const _innerEar = Color(0xFFFFA9B6);
  static const _nose = Color(0xFFFF7F98);
  static const _ink = Color(0xFF35251D);
  static const _cheek = Color(0xFFFF8DA5);
  static const _collar = Color(0xFF4FB3A6);
  static const _gold = Color(0xFFFFCC47);
  static const _goldDark = Color(0xFFDDA017);

  // Gradient paints for fixed shapes, built once instead of every frame.
  static const _bodyRect = Rect.fromLTWH(25, 64, 50, 30);
  static const _headRect = Rect.fromLTWH(14, 20, 72, 54);
  static const _bellRect = Rect.fromLTWH(-4.4, -.4, 8.8, 8.8);
  static final _bodyPaint = Paint()
    ..shader = const RadialGradient(
      center: Alignment(-.3, -.6),
      radius: 1,
      colors: [_furLight, _fur, _furDark],
      stops: [0, .5, 1],
    ).createShader(_bodyRect);
  static final _headPaint = Paint()
    ..shader = const RadialGradient(
      center: Alignment(-.35, -.55),
      radius: .95,
      colors: [_furLight, _fur, _furDark],
      stops: [0, .55, 1],
    ).createShader(_headRect);
  static final _bellPaint = Paint()
    ..shader = const RadialGradient(
      center: Alignment(-.4, -.4),
      colors: [Color(0xFFFFF0B8), _gold, _goldDark],
      stops: [0, .45, 1],
    ).createShader(_bellRect);

  @override
  void paint(Canvas canvas, Size size) {
    // Everything is drawn on a 100×100 grid with the ground at y = 94.
    canvas.save();
    canvas.scale(size.shortestSide / 100);

    final t = idle.value;
    final r = react.value;
    final reacting = r > 0 && r < 1;
    final jumping = reacting && reaction == _Reaction.jump;
    final wiggling = reacting && reaction == _Reaction.wiggle;
    final waving = reacting && reaction == _Reaction.wave;
    final a = act.value;
    final acting = !reacting && a > 0 && a < 1 && action != _Action.none;
    // 0 → 1 → 0 over the action, eased so it holds a moment at the peak.
    final e = acting
        ? Curves.easeInOut.transform(math.sin(a * math.pi).clamp(0.0, 1.0))
        : 0.0;
    double acted(_Action which) => action == which ? e : 0;
    final yawn = acted(_Action.yawn);
    final groom = acted(_Action.groom);
    final stretching = acted(_Action.stretch);
    final looking = acted(_Action.lookAround);
    final petting = pet.value;
    final face = reacting ? MascotMood.excited : mood;
    final popScale =
        popFrom + (1 - popFrom) * Curves.elasticOut.transform(pop.value);

    // Idle motion uses whole cycles per loop so it repeats seamlessly.
    final breath = math.sin(t * _tau * 2);
    var stretch = 1 + breath * .018;
    var dy = 0.0;
    var dx = 0.0;
    var tilt = 0.0;
    var headDy = -breath * .6;
    var headTilt = 0.0;
    switch (mood) {
      case MascotMood.excited:
        final hop = math.sin(t * _tau * 4).abs();
        dy = -hop * 3.5;
        stretch = 1 + (hop - .5) * .05;
        headTilt = math.sin(t * _tau * 2) * .06;
      case MascotMood.sleepy:
        stretch = 1 + math.sin(t * _tau) * .03;
        headDy = 2.5 + math.sin(t * _tau) * 1.2;
        headTilt = .12 + math.sin(t * _tau) * .03;
      case MascotMood.worried:
        dx = math.sin(t * _tau * 18) * .5;
        headDy = 1;
      case MascotMood.calm:
        headTilt = math.sin(t * _tau) * .07;
      case MascotMood.happy:
        headTilt = math.sin(t * _tau) * .04;
    }
    // Spontaneous actions and petting layer on top of the idle pose.
    if (acting) {
      dy *= 1 - e;
      stretch += yawn * .05 + stretching * .1;
      headDy -= yawn * 2.5 + stretching * 1.5;
      headTilt =
          headTilt * (1 - e) - groom * .12 + looking * math.sin(a * _tau) * .07;
    }
    if (petting > 0) {
      // Purring: a fine vibration, leaning into the hand.
      dx += math.sin(t * _tau * 48) * .35 * petting;
      headTilt += .12 * petting;
      dy *= 1 - petting;
    }

    if (jumping) {
      // Anticipation crouch, leap with a spin of the head, squash on landing.
      if (r < .16) {
        stretch = 1 - (r / .16) * .14;
      } else if (r < .68) {
        final p = (r - .16) / .52;
        dy = -math.sin(p * math.pi) * 22;
        stretch = 1 + math.sin(p * math.pi) * .1;
        tilt = math.sin(p * _tau) * .1;
        headTilt = -math.sin(p * _tau) * .12;
      } else {
        final p = (r - .68) / .32;
        stretch = 1 - math.sin(p * math.pi) * .12 * (1 - p);
      }
    }
    final envelope = wiggling || waving ? math.sin(r * math.pi) : 0.0;
    if (wiggling) {
      tilt = math.sin(r * math.pi * 6) * .08 * envelope;
      headTilt = math.sin(r * math.pi * 6 + 1) * .14 * envelope;
      stretch = 1 + math.sin(r * math.pi * 12) * .025 * envelope;
    }
    if (waving) headTilt = -.1 * envelope;

    final tailSpeed = switch (mood) {
      MascotMood.excited => 4,
      MascotMood.worried => 8,
      MascotMood.sleepy => 1,
      _ => 2,
    };
    var sway = math.sin(t * _tau * tailSpeed);
    if (mood == MascotMood.worried) sway *= .3;
    if (reacting) sway = math.sin(r * math.pi * 8);
    if (petting > 0) {
      sway = sway * (1 - petting) + math.sin(t * _tau * 6) * petting;
    }

    var bell = math.sin(t * _tau * 2 + 1) * .08;
    if (jumping) bell = math.sin(r * math.pi * 5) * .55 * (1 - r);
    if (wiggling) bell = math.sin(r * math.pi * 6) * .45 * envelope;

    // Arms: covering the eyes, grooming, stretching up or waving.
    final coverLift = Curves.easeOutBack.transform(cover.value);
    final peekValue = Curves.easeOut.transform(peek.value);
    var leftLift = coverLift, rightLift = coverLift;
    var leftTarget = const Offset(36, 47);
    var rightTarget = Offset.lerp(
      const Offset(64, 47),
      const Offset(65, 64),
      peekValue,
    )!;
    if (cover.value == 0) {
      if (groom > 0) {
        leftLift = groom;
        leftTarget = Offset(39 + math.sin(t * _tau * 10) * .8, 68);
      }
      if (stretching > 0) {
        // Paws reach up behind the head, poking out above the ears.
        leftLift = rightLift = stretching;
        leftTarget = const Offset(10, 12);
        rightTarget = const Offset(90, 12);
      }
      if (waving) {
        rightLift = Curves.easeOut.transform(envelope);
        rightTarget = Offset(82 + math.sin(r * math.pi * 8) * 5, 40);
      }
    }

    _paintShadow(canvas, dy, popScale);

    canvas.save();
    canvas.translate(50 + dx, 94 + dy);
    canvas.rotate(tilt);
    canvas.scale(popScale / math.sqrt(stretch), popScale * stretch);
    canvas.translate(-50, -94);

    final tailInFront = mood == MascotMood.sleepy && !reacting && !acting;
    if (!tailInFront) _paintTail(canvas, face, sway, front: false);
    _paintBody(canvas);
    _paintPaws(canvas, left: leftLift == 0, right: rightLift == 0);
    if (tailInFront) _paintTail(canvas, face, sway, front: true);

    // Stretching arms go behind the head; the others in front of it.
    final armsBehind = stretching > 0 && cover.value == 0;
    if (armsBehind) {
      _paintArm(canvas, -1, leftTarget, leftLift);
      _paintArm(canvas, 1, rightTarget, rightLift);
    }

    canvas.save();
    canvas.translate(50, 72 + headDy);
    canvas.rotate(headTilt);
    canvas.translate(-50, -72);
    _paintHead(
      canvas,
      t,
      face,
      contentEyes: petting > .4 || yawn > .3 || groom > .3 || stretching > .35,
      lookOverride: looking > 0 ? Offset(math.sin(a * _tau) * 1.1, -.1) : null,
      yawn: yawn,
      groom: groom,
      blush: .45 + .4 * petting,
    );
    canvas.restore();

    _paintBell(canvas, bell);
    if (!armsBehind) {
      if (leftLift > 0) _paintArm(canvas, -1, leftTarget, leftLift);
      if (rightLift > 0) _paintArm(canvas, 1, rightTarget, rightLift);
    }
    canvas.restore();

    if (face == MascotMood.excited && !reacting && !acting) {
      _paintSparkles(canvas, t);
    }
    if (mood == MascotMood.sleepy && !reacting && !acting) _paintZzz(canvas, t);
    if (mood == MascotMood.worried && !reacting) _paintSweat(canvas, t);
    if (jumping) _paintHearts(canvas, r);
    if (wiggling) _paintNotes(canvas, r);
    if (waving) {
      _star(
        canvas,
        Offset(90, 30 - envelope * 4),
        2 + envelope * 3,
        Paint()..color = const Color(0xFFFFC94D).withValues(alpha: envelope),
      );
    }
    if (petting > 0) _paintPurr(canvas, t, petting);
    final c = confetti.value;
    if (c > 0 && c < 1) _paintConfetti(canvas, c);
    canvas.restore();
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  void _paintShadow(Canvas canvas, double dy, double popScale) {
    final lift = (-dy / 22).clamp(0.0, 1.0);
    final shrink = (1 - lift * .45) * popScale;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(50, 95),
        width: 54 * shrink,
        height: 7 * shrink,
      ),
      Paint()..color = Colors.black.withValues(alpha: .12 * (1 - lift * .5)),
    );
  }

  void _paintTail(
    Canvas canvas,
    MascotMood face,
    double sway, {
    required bool front,
  }) {
    final Path path;
    if (front) {
      // Curled around the paws while napping.
      path = Path()
        ..moveTo(66, 88)
        ..cubicTo(82, 95, 66, 99.5, 42 + sway * 2, 96.5);
    } else {
      final (tipX, tipY) = switch (face) {
        MascotMood.excited => (79 + sway * 9, 30.0),
        MascotMood.worried => (91 + sway * 2, 80.0),
        _ => (86 + sway * 7, 48.0),
      };
      path = Path()
        ..moveTo(64, 86)
        ..cubicTo(84, 93, 93 + sway * 3, (86 + tipY) / 2 + 8, tipX, tipY);
    }
    // A worried kitten puffs up its tail.
    final width = face == MascotMood.worried && !front ? 9.0 : 6.5;
    canvas.drawPath(path, _stroke(_furDark, width));

    final metric = path.computeMetrics().first;
    final ring = Paint()
      ..color = _stripe
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt;
    for (final f in [.5, .66]) {
      final tangent = metric.getTangentForOffset(metric.length * f)!;
      final normal =
          Offset(-tangent.vector.dy, tangent.vector.dx) * width * .45;
      canvas.drawLine(
        tangent.position - normal,
        tangent.position + normal,
        ring,
      );
    }
    canvas.drawPath(
      metric.extractPath(metric.length * .84, metric.length),
      _stroke(_stripe, width),
    );
    // A fluffy tip.
    final tip = metric.getTangentForOffset(metric.length)!.position;
    canvas.drawCircle(tip, width * .62, Paint()..color = _stripe);
  }

  void _paintBody(Canvas canvas) {
    canvas.drawOval(_bodyRect, _bodyPaint);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 84), width: 24, height: 17),
      Paint()..color = _cream,
    );
    final stripe = _stroke(_stripe, 2);
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(50 + side * 24, 76)
          ..quadraticBezierTo(50 + side * 20, 79, 50 + side * 21.5, 83),
        stripe,
      );
    }
    // Collar; the head covers its top edge.
    canvas.drawPath(
      Path()
        ..moveTo(33, 71)
        ..quadraticBezierTo(50, 79, 67, 71),
      _stroke(_collar, 4),
    );
    // Soft shadow the head casts on the body.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 73.5), width: 46, height: 9),
      Paint()
        ..color = Colors.black.withValues(alpha: .07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  void _paintPaws(Canvas canvas, {required bool left, required bool right}) {
    final fill = Paint()..color = _cream;
    final toes = _stroke(_ink.withValues(alpha: .25), 1);
    for (final x in [if (left) 41.0, if (right) 59.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 92), width: 13, height: 8),
        fill,
      );
      canvas.drawLine(Offset(x - 2, 93.6), Offset(x - 2, 95), toes);
      canvas.drawLine(Offset(x + 2, 93.6), Offset(x + 2, 95), toes);
    }
  }

  /// A paw lifted [lift] of the way from the ground to [target] (eyes,
  /// mouth, overhead…), with toe beans once it faces us.
  void _paintArm(Canvas canvas, double side, Offset target, double lift) {
    final rest = Offset(50 + side * 9, 92);
    final paw = Offset.lerp(rest, target, lift)!;
    final shoulder = Offset(50 + side * 12, 74);
    canvas.drawLine(shoulder, paw, _stroke(_fur, 9));
    canvas.drawOval(
      Rect.fromCenter(center: paw, width: 17, height: 14),
      Paint()..color = _cream,
    );
    if (lift > .6) {
      final bean = Paint()..color = _innerEar;
      canvas.drawCircle(paw.translate(0, 1.6), 2.2, bean);
      for (final dx in [-3.8, 0.0, 3.8]) {
        canvas.drawCircle(paw.translate(dx, -2.6), 1.2, bean);
      }
    }
  }

  void _paintBell(Canvas canvas, double swing) {
    canvas.save();
    canvas.translate(50, 75);
    canvas.rotate(swing);
    const center = Offset(0, 4);
    canvas.drawCircle(center, 4.4, _bellPaint);
    canvas.drawLine(
      const Offset(-3.6, 3.4),
      const Offset(3.6, 3.4),
      _stroke(_goldDark, .9),
    );
    canvas.drawCircle(const Offset(0, 5.8), .9, Paint()..color = _goldDark);
    canvas.restore();
  }

  void _paintHead(
    Canvas canvas,
    double t,
    MascotMood face, {
    required bool contentEyes,
    required Offset? lookOverride,
    required double yawn,
    required double groom,
    required double blush,
  }) {
    _paintEars(canvas, t, face, yawn: yawn);

    // Cheek fluff poking out of the round head.
    final fur = Paint()..color = _fur;
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(50 + side * 33, 44)
          ..lineTo(50 + side * 39.5, 53)
          ..lineTo(50 + side * 34, 54)
          ..lineTo(50 + side * 37.5, 60)
          ..lineTo(50 + side * 29, 62)
          ..close(),
        fur,
      );
    }

    canvas.drawOval(_headRect, _headPaint);
    // Rim light along the top-left of the head.
    canvas.drawArc(
      _headRect.deflate(2.2),
      math.pi * 1.08,
      math.pi * .42,
      false,
      _stroke(Colors.white.withValues(alpha: .35), 1.6),
    );

    // Tabby stripes.
    final stripe = _stroke(_stripe, 2.6);
    canvas.drawLine(const Offset(43, 23.5), const Offset(44.5, 29.5), stripe);
    canvas.drawLine(const Offset(50, 21.5), const Offset(50, 29), stripe);
    canvas.drawLine(const Offset(57, 23.5), const Offset(55.5, 29.5), stripe);
    stripe.strokeWidth = 2.2;
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(50 + side * 34.5, 43),
        Offset(50 + side * 29, 44.5),
        stripe,
      );
      canvas.drawLine(
        Offset(50 + side * 34.5, 49),
        Offset(50 + side * 29.5, 49.5),
        stripe,
      );
    }

    // Muzzle and blush.
    final cream = Paint()..color = _cream;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(45.5, 60), width: 14, height: 10.5),
      cream,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(54.5, 60), width: 14, height: 10.5),
      cream,
    );
    // Whisker freckles.
    final freckle = Paint()..color = _stripe.withValues(alpha: .55);
    for (final side in [-1.0, 1.0]) {
      for (final (fx, fy) in [(5.5, 58.8), (7.5, 60.8), (5.8, 62.4)]) {
        canvas.drawCircle(Offset(50 + side * fx, fy), .55, freckle);
      }
    }
    final cheek = Paint()..color = _cheek.withValues(alpha: blush);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(26, 58), width: 11, height: 6.5),
      cheek,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(74, 58), width: 11, height: 6.5),
      cheek,
    );

    _paintEyes(
      canvas,
      t,
      face,
      content: contentEyes,
      lookOverride: lookOverride,
    );
    _paintWhiskers(canvas, t);
    _paintNose(canvas);
    _paintMouth(canvas, t, face, yawn: yawn, groom: groom);
  }

  void _paintEars(
    Canvas canvas,
    double t,
    MascotMood face, {
    required double yawn,
  }) {
    final (angle, drop) = switch (face) {
      MascotMood.worried => (.62, 5.0),
      MascotMood.sleepy => (.34, 2.0),
      MascotMood.excited => (.06, -1.0),
      _ => (.16, 0.0),
    };
    // One quick ear flick per loop.
    final flick = t > .55 && t < .63
        ? math.sin((t - .55) / .08 * _tau) * .3
        : 0.0;
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(50 + side * 21, 27 + drop);
      canvas.rotate(side * (angle + yawn * .25) + (side > 0 ? flick : 0));
      final ear = Path()
        ..moveTo(-12, 8)
        ..lineTo(-3.2, -13.5)
        ..quadraticBezierTo(0, -19.5, 3.2, -13.5)
        ..lineTo(12, 8)
        ..close();
      canvas.drawPath(ear, Paint()..color = _furDark);
      canvas.save();
      canvas.translate(0, 2.5);
      canvas.scale(.56);
      canvas.drawPath(ear, Paint()..color = _innerEar);
      canvas.restore();
      // Fluffy tufts inside the ear.
      final tuft = _stroke(Colors.white.withValues(alpha: .75), .9);
      canvas.drawLine(const Offset(-2.5, 5), const Offset(-.8, -2), tuft);
      canvas.drawLine(const Offset(1.5, 5.5), const Offset(1.8, -.5), tuft);
      canvas.restore();
    }
  }

  /// 1 = open, ~0 = closed. Blinks once, then a double blink, every loop.
  double _openness(double t) {
    var open = 1.0;
    for (final at in [.28, .8, .87]) {
      open = math.min(open, ((t - at).abs() / .025).clamp(.06, 1.0));
    }
    return open;
  }

  /// 1 = open; eases down to 0 and back between t = .4 and .65.
  double _slowBlink(double t) {
    if (t < .4 || t > .65) return 1;
    return (math.cos((t - .4) / .25 * _tau) + 1) / 2;
  }

  void _paintEyes(
    Canvas canvas,
    double t,
    MascotMood face, {
    required bool content,
    required Offset? lookOverride,
  }) {
    const left = Offset(36, 48), right = Offset(64, 48);
    final white = Paint()..color = Colors.white;

    if (content) {
      // Happily closed "‿" eyes: purring, yawning, grooming, stretching.
      final stroke = _stroke(_ink, 2.6);
      for (final c in [left, right]) {
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 5, c.dy - .5)
            ..quadraticBezierTo(c.dx, c.dy + 4, c.dx + 5, c.dy - .5),
          stroke,
        );
      }
      return;
    }
    // Looking around shows the pupils whatever the mood.
    if (lookOverride != null &&
        (face == MascotMood.excited || face == MascotMood.sleepy)) {
      face = MascotMood.happy;
    }

    switch (face) {
      case MascotMood.excited:
        final stroke = _stroke(_ink, 2.8);
        for (final c in [left, right]) {
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - 5, c.dy + 2)
              ..quadraticBezierTo(c.dx, c.dy - 5.5, c.dx + 5, c.dy + 2),
            stroke,
          );
        }
      case MascotMood.sleepy:
        final stroke = _stroke(_ink, 2.4);
        for (final c in [left, right]) {
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - 5, c.dy)
              ..quadraticBezierTo(c.dx, c.dy + 4.5, c.dx + 5, c.dy),
            stroke,
          );
        }
      case MascotMood.happy || MascotMood.calm || MascotMood.worried:
        // Look at the pointer, or glance around while idle.
        final pointer = lookOverride ?? look.value;
        final wander = Offset(
          math.sin(t * _tau) * .6,
          math.sin(t * _tau * 2) * .2,
        );
        final gaze = pointer + wander * (1 - pointer.distance).clamp(0.0, 1.0);
        final shift = Offset(gaze.dx * 2.4, gaze.dy * 1.6);
        // A calm cat "slow blinks": a long, soft close once per loop.
        final open = face == MascotMood.calm
            ? math.min(_openness(t), .35 + .65 * _slowBlink(t))
            : _openness(t);
        final worried = face == MascotMood.worried;
        for (final c in [left, right]) {
          final eye = c + shift;
          final rect = Rect.fromCenter(
            center: eye,
            width: worried ? 10 : 10.5,
            height: 12.5 * open,
          );
          // Deep brown eyes with a warm reflection at the bottom.
          canvas.drawOval(
            rect,
            Paint()
              ..shader = const RadialGradient(
                center: Alignment(0, .45),
                radius: .75,
                colors: [Color(0xFF6E4A35), _ink],
              ).createShader(rect),
          );
          if (open > .5) {
            // Big glossy highlights; teary when worried.
            canvas.drawCircle(
              eye.translate(1.9, -2.6),
              worried ? 2.8 : 2.3,
              white,
            );
            canvas.drawCircle(
              eye.translate(-2, 2.6),
              worried ? 1.5 : 1.1,
              Paint()..color = Colors.white.withValues(alpha: .85),
            );
          }
        }
        if (worried) {
          final brow = _stroke(_ink, 2);
          canvas.drawLine(const Offset(30, 38.5), const Offset(40, 35), brow);
          canvas.drawLine(const Offset(70, 38.5), const Offset(60, 35), brow);
        }
    }
  }

  void _paintWhiskers(Canvas canvas, double t) {
    final whisker = _stroke(_ink.withValues(alpha: .4), 1.1);
    for (final side in [-1.0, 1.0]) {
      final twitch = math.sin(t * _tau * 3 + side) * .6;
      for (final (startY, endY) in [(57.5, 54.0), (59.5, 59.5), (61.5, 65.0)]) {
        canvas.drawLine(
          Offset(50 + side * 12, startY),
          Offset(50 + side * 30, endY + twitch),
          whisker,
        );
      }
    }
  }

  void _paintNose(Canvas canvas) {
    canvas.drawPath(
      Path()
        ..moveTo(47, 54)
        ..lineTo(53, 54)
        ..quadraticBezierTo(53.8, 54.4, 50.7, 57.3)
        ..quadraticBezierTo(50, 57.9, 49.3, 57.3)
        ..quadraticBezierTo(46.2, 54.4, 47, 54)
        ..close(),
      Paint()..color = _nose,
    );
    canvas.drawCircle(
      const Offset(49, 54.8),
      .7,
      Paint()..color = Colors.white.withValues(alpha: .7),
    );
  }

  void _paintMouth(
    Canvas canvas,
    double t,
    MascotMood face, {
    required double yawn,
    required double groom,
  }) {
    final stroke = _stroke(_ink, 1.8);
    Path cat(double w) => Path()
      ..moveTo(50, 57.5)
      ..lineTo(50, 59.2)
      ..moveTo(50 - w, 59.6)
      ..quadraticBezierTo(50 - w / 2, 62.4, 50, 59.2)
      ..quadraticBezierTo(50 + w / 2, 62.4, 50 + w, 59.6);

    if (yawn > .12) {
      // A big round yawn with a curled tongue.
      final mouth = Rect.fromCenter(
        center: Offset(50, 61 + yawn * 2.5),
        width: 5 + yawn * 6,
        height: 3 + yawn * 9,
      );
      canvas.drawOval(mouth, Paint()..color = _ink);
      canvas.save();
      canvas.clipPath(Path()..addOval(mouth));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(50, mouth.bottom - 1.5),
          width: mouth.width * .8,
          height: mouth.height * .45,
        ),
        Paint()..color = _nose,
      );
      canvas.restore();
      return;
    }
    if (groom > .3) {
      // Licking the paw: the tongue darts in and out.
      canvas.drawPath(cat(3.6), stroke);
      final out = (math.sin(t * _tau * 10) * .5 + .5) * groom;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(50, 61.5 + out * 1.6),
          width: 3.6,
          height: 2.4 + out * 2,
        ),
        Paint()..color = _nose,
      );
      return;
    }

    switch (face) {
      case MascotMood.excited:
        canvas.drawLine(const Offset(50, 57.5), const Offset(50, 59.5), stroke);
        final mouth = Path()
          ..moveTo(45, 59.5)
          ..quadraticBezierTo(50, 61.5, 55, 59.5)
          ..quadraticBezierTo(54.5, 67, 50, 67)
          ..quadraticBezierTo(45.5, 67, 45, 59.5)
          ..close();
        canvas.drawPath(mouth, Paint()..color = _ink);
        canvas.save();
        canvas.clipPath(mouth);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(50, 66), width: 6.5, height: 4),
          Paint()..color = _nose,
        );
        canvas.restore();
      case MascotMood.happy:
        canvas.drawPath(cat(4.8), stroke);
      case MascotMood.calm:
        canvas.drawPath(cat(3.8), stroke);
      case MascotMood.worried:
        canvas.drawLine(const Offset(50, 57.5), const Offset(50, 59.5), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(45.5, 62.5)
            ..quadraticBezierTo(47.7, 60.3, 50, 61.8)
            ..quadraticBezierTo(52.3, 63.3, 54.5, 61.2),
          stroke,
        );
      case MascotMood.sleepy:
        canvas.drawPath(cat(3.6), stroke);
        // Nap bubble that grows and shrinks with each breath.
        final grow = math.sin(t * _tau) * .5 + .5;
        final radius = 1.8 + grow * 3.2;
        final center = Offset(53 + radius * .8, 56 - radius * .3);
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = const Color(0xFFBFE6FF).withValues(alpha: .55),
        );
        canvas.drawCircle(
          center,
          radius,
          _stroke(Colors.white.withValues(alpha: .8), .7),
        );
        canvas.drawCircle(
          center.translate(-radius * .35, -radius * .35),
          radius * .22,
          Paint()..color = Colors.white.withValues(alpha: .9),
        );
    }
  }

  void _paintSparkles(Canvas canvas, double t) {
    const spots = [
      Offset(10, 24),
      Offset(90, 14),
      Offset(94, 70),
      Offset(6, 68),
    ];
    final paint = Paint()..color = const Color(0xFFFFC94D);
    for (var i = 0; i < spots.length; i++) {
      final phase = (t * 2 + i / spots.length) % 1;
      _star(canvas, spots[i], 1.5 + math.sin(phase * math.pi) * 3.5, paint);
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r),
      paint,
    );
  }

  void _paintZzz(Canvas canvas, double t) {
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      // A "z" drawn as three strokes (no text layout per frame).
      final at = Offset(74 + p * 14 + math.sin(p * _tau) * 2, 22 - p * 22);
      final w = 4 + p * 5;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy)
          ..lineTo(at.dx + w, at.dy)
          ..lineTo(at.dx, at.dy + w)
          ..lineTo(at.dx + w, at.dy + w),
        _stroke(const Color(0xFF8C7BD6).withValues(alpha: 1 - p), 1.6 + p)
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _paintSweat(Canvas canvas, double t) {
    final p = (t * 2) % 1;
    final y = 26 + p * 8;
    canvas.drawPath(
      Path()
        ..moveTo(82, y)
        ..quadraticBezierTo(78, y + 7, 82, y + 9)
        ..quadraticBezierTo(86, y + 7, 82, y),
      Paint()..color = const Color(0xFF8CC8F2).withValues(alpha: 1 - p * .8),
    );
  }

  void _paintHearts(Canvas canvas, double r) {
    const starts = [Offset(20, 30), Offset(80, 26), Offset(50, 12)];
    for (var i = 0; i < starts.length; i++) {
      final p = ((r - i * .12) / .8).clamp(0.0, 1.0);
      if (p == 0 || p == 1) continue;
      final c = starts[i].translate(math.sin(p * 6 + i) * 3, -p * 22);
      final s = 3.5 + p * 1.5;
      final heart = Path()
        ..moveTo(c.dx, c.dy + s)
        ..cubicTo(
          c.dx - s * 2,
          c.dy - s * .2,
          c.dx - s,
          c.dy - s * 1.6,
          c.dx,
          c.dy - s * .5,
        )
        ..cubicTo(
          c.dx + s,
          c.dy - s * 1.6,
          c.dx + s * 2,
          c.dy - s * .2,
          c.dx,
          c.dy + s,
        );
      canvas.drawPath(
        heart,
        Paint()..color = const Color(0xFFFF5C8A).withValues(alpha: 1 - p),
      );
    }
  }

  void _paintNotes(Canvas canvas, double r) {
    const starts = [Offset(12, 40), Offset(82, 30)];
    for (final (i, start) in starts.indexed) {
      final p = ((r - i * .18) / .8).clamp(0.0, 1.0);
      if (p == 0 || p == 1) continue;
      // An eighth note: head, stem and flag.
      final c = start.translate(math.sin(p * _tau) * 3, -p * 20);
      final color = const Color(0xFF8C7BD6).withValues(alpha: 1 - p);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 5, height: 3.8),
        Paint()..color = color,
      );
      canvas.drawLine(
        c.translate(2.2, 0),
        c.translate(2.2, -9),
        _stroke(color, 1.2),
      );
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + 2.2, c.dy - 9)
          ..quadraticBezierTo(c.dx + 6, c.dy - 7, c.dx + 5, c.dy - 3.5),
        _stroke(color, 1.2),
      );
    }
  }

  /// Petting: hearts floating up and purr lines beside the body.
  void _paintPurr(Canvas canvas, double t, double strength) {
    for (var i = 0; i < 3; i++) {
      final p = (t * 2 + i / 3) % 1;
      final start = [
        const Offset(18, 40),
        const Offset(82, 34),
        const Offset(50, 14),
      ][i];
      _heart(
        canvas,
        start.translate(math.sin(p * _tau + i) * 3, -p * 18),
        2.6 + p * 1.6,
        const Color(0xFFFF5C8A).withValues(alpha: (1 - p) * strength),
      );
    }
    final flicker = .5 + .5 * math.sin(t * _tau * 12);
    final purr = _stroke(
      const Color(0xFFFF8DA5).withValues(alpha: strength * flicker),
      1.4,
    );
    for (final side in [-1.0, 1.0]) {
      for (final gap in [0.0, 3.5]) {
        final x = 50 + side * (29 + gap);
        canvas.drawPath(
          Path()
            ..moveTo(x, 74)
            ..quadraticBezierTo(x + side * 2.5, 79, x, 84),
          purr,
        );
      }
    }
  }

  /// A burst of confetti falling, for when Michi gets excited.
  void _paintConfetti(Canvas canvas, double c) {
    const colors = [
      Color(0xFFC8F04B),
      Color(0xFFFF7F98),
      Color(0xFFFFCC47),
      Color(0xFF9A86CF),
      Color(0xFF4FB3A6),
    ];
    final fade = c < .75 ? 1.0 : 1 - (c - .75) / .25;
    for (var i = 0; i < 16; i++) {
      // Deterministic spread per piece.
      final seed = (i * 37) % 100 / 100;
      final x = 6 + ((i * 53) % 88) + math.sin(c * _tau * 1.5 + i) * 4;
      final y = -6 + c * (70 + seed * 40) + seed * 10;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c * _tau * (1 + seed) + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 3.4, height: 1.8),
          const Radius.circular(.6),
        ),
        Paint()..color = colors[i % colors.length].withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  void _heart(Canvas canvas, Offset c, double s, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy + s)
        ..cubicTo(
          c.dx - s * 2,
          c.dy - s * .2,
          c.dx - s,
          c.dy - s * 1.6,
          c.dx,
          c.dy - s * .5,
        )
        ..cubicTo(
          c.dx + s,
          c.dy - s * 1.6,
          c.dx + s * 2,
          c.dy - s * .2,
          c.dx,
          c.dy + s,
        ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_KittenPainter oldDelegate) =>
      oldDelegate.mood != mood ||
      oldDelegate.reaction != reaction ||
      oldDelegate.action != action ||
      oldDelegate.popFrom != popFrom;
}
