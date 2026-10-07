import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/theme/motion.dart';

/// Cross-fades the whole app between light and dark. Lerping the theme
/// would rebuild every widget on every frame; instead [ThemeCrossfadeState.run]
/// snapshots the current frame, applies the new theme at once, and fades the
/// snapshot out on top (only an opacity animation).
class ThemeCrossfade extends StatefulWidget {
  const ThemeCrossfade({super.key, required this.child});

  final Widget child;

  /// Runs [change] behind a cross-fade, or directly when there's no
  /// [ThemeCrossfade] above [context].
  static void run(BuildContext context, VoidCallback change) {
    final state = context.findAncestorStateOfType<ThemeCrossfadeState>();
    if (state == null) {
      change();
    } else {
      state.run(change);
    }
  }

  @override
  State<ThemeCrossfade> createState() => ThemeCrossfadeState();
}

class ThemeCrossfadeState extends State<ThemeCrossfade>
    with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final AnimationController _fade;
  late final Animation<double> _opacity;
  ui.Image? _snapshot;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: Motion.slow);
    _opacity = CurvedAnimation(
      parent: ReverseAnimation(_fade),
      curve: Motion.exit,
    );
  }

  void run(VoidCallback change) {
    final boundary =
        _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (Motion.reduced(context) || boundary == null) {
      change();
      return;
    }
    final ui.Image snapshot;
    try {
      snapshot = boundary.toImageSync(
        pixelRatio: View.of(context).devicePixelRatio,
      );
    } catch (_) {
      // Nothing painted yet (or mid-frame): switch without the fade.
      change();
      return;
    }
    _clearSnapshot();
    setState(() => _snapshot = snapshot);
    change();
    _fade.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted) setState(_clearSnapshot);
    });
  }

  void _clearSnapshot() {
    _snapshot?.dispose();
    _snapshot = null;
  }

  @override
  void dispose() {
    _fade.dispose();
    _clearSnapshot();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (snapshot != null)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _opacity,
                child: RawImage(image: snapshot, fit: BoxFit.fill),
              ),
            ),
          ),
      ],
    );
  }
}
