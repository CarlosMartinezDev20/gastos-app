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

  /// Bottom sheets: in like a state change, out quicker. (With reduced
  /// motion Flutter already runs route controllers 20× faster.)
  static const sheet = AnimationStyle(
    duration: medium,
    reverseDuration: fast,
    curve: standard,
    reverseCurve: exit,
  );

  /// Entering and moving: fast start, gentle stop.
  static const Curve standard = Curves.easeOutCubic;

  /// Leaving: gentle start, fast end.
  static const Curve exit = Curves.easeInCubic;

  /// A small playful overshoot, for selection and pop-ins only.
  static const Curve spring = Curves.easeOutBack;

  /// Whether the user asked the system to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration], or zero when the user asked to reduce motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
