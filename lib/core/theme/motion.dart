import 'package:flutter/widgets.dart';

/// The app's one motion vocabulary: every transition and animation picks its
/// duration and curve from here, so they feel related. Animate transforms and
/// opacity where possible (they only repaint); layout-driving animations are
/// kept to small boxes.
///
/// Mascot's own character loops (`widgets/mascot.dart`) keep their timings:
/// they're acting, not UI transitions.
abstract final class Motion {
  /// Press feedback, small toggles, a selected chip.
  static const fast = Duration(milliseconds: 150);

  /// State changes inside a page: switches, segments, content swaps, a
  /// section collapsing.
  static const medium = Duration(milliseconds: 250);

  /// Moving between pages and larger elements travelling.
  static const slow = Duration(milliseconds: 350);

  /// One-off reveals of a value (a number counting up, a ring filling).
  static const emphasis = Duration(milliseconds: 700);

  /// Delay between the items of a staggered entrance, and how many items
  /// get one (later items arrive with the last), so an entrance stays short.
  static const stagger = Duration(milliseconds: 50);
  static const maxStaggered = 6;

  /// Bottom sheets rise like iOS sheets: longer, fast at first and settling
  /// softly ([sheetCurve]); out quicker. (With reduced motion Flutter
  /// already runs route controllers 20× faster.)
  static const sheet = AnimationStyle(
    duration: Duration(milliseconds: 420),
    reverseDuration: medium,
    curve: sheetCurve,
    reverseCurve: exit,
  );

  /// The deceleration of iOS sheets and drawers.
  static const Curve sheetCurve = Cubic(.32, .72, 0, 1);

  /// Entering and moving: a strong ease-out, so the motion starts the
  /// instant the user acts and settles softly (the platform's easeOutCubic
  /// is too weak to feel intentional).
  static const Curve standard = Cubic(.23, 1, .32, 1);

  /// For animations played in reverse (route pops, an AnimatedSwitcher's
  /// outgoing child, a ReverseAnimation): [standard] mirrored, so leaving
  /// also starts fast. Never use it on a forward animation (that would be an
  /// ease-in, which feels sluggish).
  static const Curve exit = FlippedCurve(standard);

  /// A slight overshoot (about 2%), for selection and pop-ins only: enough
  /// to feel alive, not bouncy.
  static const Curve spring = Cubic(.25, 1.25, .5, 1);

  /// Whether the user asked the system to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration], or zero when the user asked to reduce motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
