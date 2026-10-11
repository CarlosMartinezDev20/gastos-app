import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../core/utils/formatters.dart';

/// Bottom padding for a tab page's scroll view: the shell lets content run
/// behind the floating dock (Scaffold.extendBody), so the last item needs
/// room to scroll clear of it.
double dockClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 28;

/// Bottom padding that follows the keyboard. The inset changes on every frame
/// of the keyboard animation; only this padding updates, [child] isn't
/// rebuilt (a form reading the inset itself would rebuild whole each frame).
class KeyboardInset extends StatelessWidget {
  const KeyboardInset({super.key, this.extra = 0, required this.child});

  /// Space kept above the keyboard (or the screen bottom when it's hidden).
  final double extra;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(context).bottom + extra,
    ),
    child: child,
  );
}

/// Builds once when the keyboard shows or hides, not on every frame of its
/// animation (as reading MediaQuery's view insets would).
class KeyboardVisibilityBuilder extends StatefulWidget {
  const KeyboardVisibilityBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool visible) builder;

  @override
  State<KeyboardVisibilityBuilder> createState() =>
      _KeyboardVisibilityBuilderState();
}

class _KeyboardVisibilityBuilderState extends State<KeyboardVisibilityBuilder>
    with WidgetsBindingObserver {
  bool _visible = false;

  bool get _keyboardVisible => View.of(context).viewInsets.bottom > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = _keyboardVisible;
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final visible = _keyboardVisible;
    if (visible != _visible) setState(() => _visible = visible);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _visible);
}

/// While another route (a sheet, a full-screen page) covers this one, its
/// animations pause and it ignores the keyboard: typing in a sheet would
/// otherwise re-layout and repaint the page underneath on every frame.
class PauseWhenCovered extends StatelessWidget {
  const PauseWhenCovered({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final covered = !(ModalRoute.isCurrentOf(context) ?? true);
    final media = MediaQuery.of(context);
    return TickerMode(
      enabled: !covered,
      child: MediaQuery(
        data: covered ? media.removeViewInsets(removeBottom: true) : media,
        child: child,
      ),
    );
  }
}

/// Gives a field focus once its route has finished its entrance, so the
/// keyboard doesn't slide up while the sheet or page is still animating in.
class EntranceAutofocus extends StatefulWidget {
  const EntranceAutofocus({
    super.key,
    this.enabled = true,
    required this.builder,
  });

  final bool enabled;
  final Widget Function(BuildContext context, FocusNode focusNode) builder;

  @override
  State<EntranceAutofocus> createState() => _EntranceAutofocusState();
}

class _EntranceAutofocusState extends State<EntranceAutofocus> {
  final _focusNode = FocusNode();
  Animation<double>? _entrance;
  var _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.enabled || _scheduled) return;
    _scheduled = true;
    final entrance = ModalRoute.of(context)?.animation;
    if (entrance == null || entrance.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus());
      return;
    }
    _entrance = entrance..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted) _focus();
  }

  void _focus() {
    _entrance?.removeStatusListener(_onStatus);
    if (mounted) _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _entrance?.removeStatusListener(_onStatus);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _focusNode);
}

/// iOS-style collapsing title: once the page scrolls past its large title,
/// a slim bar with the title (and a back button when [onBack] is given)
/// fades in over the content. It only rebuilds when crossing [threshold].
class CollapsingTitle extends StatefulWidget {
  const CollapsingTitle({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.threshold = 64,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;

  /// Scroll offset where the large title has gone.
  final double threshold;

  @override
  State<CollapsingTitle> createState() => _CollapsingTitleState();
}

class _CollapsingTitleState extends State<CollapsingTitle> {
  var _collapsed = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      final collapsed = notification.metrics.pixels > widget.threshold;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final background = Theme.of(context).scaffoldBackgroundColor;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_collapsed,
              child: AnimatedOpacity(
                opacity: _collapsed ? 1 : 0,
                duration: Motion.of(context, Motion.fast),
                curve: Motion.standard,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // Opaque enough to read over the content, no blur
                    // (cheap to paint).
                    color: background.withValues(alpha: .96),
                    border: Border(bottom: BorderSide(color: palette.hairline)),
                  ),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: widget.onBack == null || !_collapsed
                              ? null
                              : IconButton(
                                  tooltip: 'Atrás',
                                  onPressed: widget.onBack,
                                  icon: const Icon(CupertinoIcons.chevron_left),
                                ),
                        ),
                        // Only while shown: hidden, it would repeat the
                        // large title for screen readers (and finders).
                        Expanded(
                          child: !_collapsed
                              ? const SizedBox.shrink()
                              : Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                        ),
                        const SizedBox(width: 56),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS large title with optional subtitle and trailing actions.
class LargeTitle extends StatelessWidget {
  const LargeTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  letterSpacing: -1,
                  height: 1.15,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: context.palette.muted, fontSize: 14),
                ),
            ],
          ),
        ),
        for (final widget in trailing) ...[const SizedBox(width: 8), widget],
      ],
    );
  }
}

/// Rounded-square outlined icon button for headers.
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Filled with the pill color (primary action) instead of outlined.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: filled ? palette.pill : palette.card,
        foregroundColor: filled
            ? palette.onPill
            : Theme.of(context).colorScheme.onSurface,
        side: filled ? null : BorderSide(color: palette.hairline),
      ),
    );
  }
}

/// Rounded tile used for bento layouts. Tappable when [onTap] is set, with
/// an iOS-style press-down scale. [gradient] paints over [color].
class BentoCard extends StatefulWidget {
  const BentoCard({
    super.key,
    required this.child,
    this.color,
    this.gradient,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.border = false,
    this.radius = 22,
  });

  final Widget child;
  final Color? color;
  final Gradient? gradient;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool border;
  final double radius;

  @override
  State<BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<BentoCard> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(widget.radius),
      side: widget.border
          ? BorderSide(color: context.palette.hairline)
          : BorderSide.none,
    );
    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (widget.gradient != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(gradient: widget.gradient),
        child: content,
      );
    }
    final card = Material(
      color: widget.color ?? context.palette.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: widget.onTap == null
          ? content
          : InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (pressed) =>
                  setState(() => _pressed = pressed),
              child: content,
            ),
    );
    if (widget.onTap == null) return card;
    return AnimatedScale(
      scale: _pressed ? .97 : 1,
      duration: Motion.of(context, Motion.fast),
      curve: Motion.standard,
      child: card,
    );
  }
}

/// Fades and slides its child up once, when it first appears. Use [index]
/// to stagger the items of a page.
/// Money that counts up to its value when it appears and glides to the new
/// one when it changes (after saving a movement, a payment…). Tabular
/// figures keep the width steady while the digits roll.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount(
    this.value, {
    super.key,
    this.style,
    this.format = Formatters.compactMoney,
  });

  final double value;
  final TextStyle? style;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final style = (this.style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      label: format(value),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: Motion.of(context, Motion.emphasis),
        curve: Motion.standard,
        builder: (context, shown, _) => Text(format(shown), style: style),
      ),
    );
  }
}

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  // Items past Motion.maxStaggered arrive with the last staggered one, so a
  // long page still settles quickly.
  late final _delay =
      Motion.stagger * math.min(widget.index, Motion.maxStaggered);
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.slow + _delay,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay.inMilliseconds / _controller.duration!.inMilliseconds,
      1,
      curve: Motion.standard,
    ),
  );
  late final _offset = Tween(
    begin: const Offset(0, .06),
    end: Offset.zero,
  ).animate(_curve);
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Transitions repaint without rebuilding the child each frame.
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// Rounded speech bubble with a small tail pointing at the mascot: out of
/// the right edge, or up from the top edge at [tailUpAt] (0–1 of the width).
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.child,
    required this.color,
    this.tailUpAt,
  });

  final Widget child;
  final Color color;

  final double? tailUpAt;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(color: color, tailUpAt: tailUpAt),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: child,
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.color, required this.tailUpAt});

  final Color color;
  final double? tailUpAt;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      paint,
    );
    final Path tail;
    if (tailUpAt case final at?) {
      final x = (size.width * at).clamp(16.0, size.width - 16);
      tail = Path()
        ..moveTo(x - 10, 1)
        ..quadraticBezierTo(x - 1, -1, x + 2, -9)
        ..quadraticBezierTo(x + 4, -1, x + 10, 1)
        ..close();
    } else {
      tail = Path()
        ..moveTo(size.width - 1, 10)
        ..quadraticBezierTo(size.width + 1, 3, size.width + 9, 0)
        ..quadraticBezierTo(size.width + 2, 10, size.width - 1, 22)
        ..close();
    }
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tailUpAt != tailUpAt;
}

/// Small outlined capsule label ("Hoy · 1 oct").
/// Why a form couldn't be saved, inside the form itself: a SnackBar would
/// open under the bottom sheet the form lives in. Grows in and out.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = message;
    return AnimatedSize(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.standard,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.blush,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Semantics(
                liveRegion: true,
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
                        text,
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
    );
  }
}

class PillTag extends StatelessWidget {
  const PillTag({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading with an optional trailing action, as in iOS lists.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.trailingText,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (trailingText != null)
            Text(
              trailingText!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.palette.muted),
            ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// iOS "inset grouped" list section (Settings-style).
class InsetGroup extends StatelessWidget {
  const InsetGroup({super.key, required this.children, this.header});

  final List<Widget> children;
  final String? header;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              header!.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.palette.muted,
                letterSpacing: .4,
              ),
            ),
          ),
        BentoCard(
          padding: EdgeInsets.zero,
          radius: 18,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(indent: 56, height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Row for [InsetGroup] with a tinted leading icon square.
class InsetTile extends StatelessWidget {
  const InsetTile({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : (iconColor ?? scheme.primary);
    return ListTile(
      onTap: onTap,
      minTileHeight: 52,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: destructive ? scheme.error : null,
        ),
      ),
      trailing:
          trailing ??
          (onTap != null && !destructive
              ? Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: context.palette.muted,
                )
              : null),
    );
  }
}

/// Black pill call-to-action with a round accent arrow, as in the reference.
class PillCta extends StatelessWidget {
  const PillCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.pill,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // A light tap, like iOS confirming a primary action.
        onTap: loading || onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.onPill,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.onAccent,
                        ),
                      )
                    : Icon(Icons.arrow_forward, color: palette.onAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS segmented control: grey track with a white sliding thumb.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final values = segments.keys.toList();
    final index = values.indexOf(selected);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          // One thumb slides under the labels, like iOS; a transform
          // (AnimatedSlide moves it by whole segment widths), no layout.
          if (index >= 0)
            Positioned.fill(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: 1 / values.length,
                  heightFactor: 1,
                  child: AnimatedSlide(
                    offset: Offset(
                      Directionality.of(context) == TextDirection.rtl
                          ? -index.toDouble()
                          : index.toDouble(),
                      0,
                    ),
                    duration: Motion.of(context, Motion.medium),
                    curve: Motion.standard,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.thumb,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final value in values)
                Expanded(
                  child: Semantics(
                    selected: value == selected,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (value != selected) HapticFeedback.selectionClick();
                        onChanged(value);
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 38),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Center(
                            child: Text(
                              segments[value]!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: value == selected
                                    ? onSurface
                                    : palette.muted,
                                fontWeight: value == selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// iOS-style switch that works on every platform.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged == null
          ? null
          : (value) {
              HapticFeedback.selectionClick();
              onChanged!(value);
            },
      // The brand's lime, like the other highlights (not the seed green).
      activeTrackColor: context.palette.accent,
    );
  }
}

/// iOS confirmation alert. Returns true when the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
