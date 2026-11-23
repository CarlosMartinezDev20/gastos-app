import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../providers/app_lock_provider.dart';
import '../providers/auth_provider.dart';
import 'mascot.dart';

/// Covers the app with [_LockScreen] while [appLockProvider] is locked and
/// someone is signed in, and locks again when the app comes back after
/// [appLockGrace] in the background. The app stays mounted underneath, so
/// unlocking returns to the same page.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _backgroundSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    // The system prompt itself may send the app to the background.
    if (lock.authenticating) return;
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _backgroundSince ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundSince;
        _backgroundSince = null;
        if (since != null && DateTime.now().difference(since) >= appLockGrace) {
          lock.lock();
        }
      case _:
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authControllerProvider).value != null;
    final locked = ref.watch(appLockProvider) && signedIn;
    return Stack(
      children: [
        // Hidden from focus and screen readers while covered.
        ExcludeFocus(
          excluding: locked,
          child: ExcludeSemantics(excluding: locked, child: widget.child),
        ),
        // In at once (nothing may show through), out with a fade.
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: Duration.zero,
            reverseDuration: Motion.of(context, Motion.medium),
            switchOutCurve: Motion.exit,
            child: locked ? const _LockScreen() : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  @override
  void initState() {
    super.initState();
    // Asks right away, as iOS apps do with Face ID.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() => ref.read(appLockProvider.notifier).unlock();

  Future<void> _logout() async {
    ref.read(appLockProvider.notifier).reset();
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final name = ref.watch(authControllerProvider).value?.name;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  // Michi covers its eyes: nothing to see while locked.
                  const Mascot(size: 120, coverEyes: true),
                  const SizedBox(height: 20),
                  Text(
                    'Miaunero está bloqueada',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name == null
                        ? 'Usa tu huella o tu rostro para entrar.'
                        : 'Hola, $name. Usa tu huella o tu rostro para entrar.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _UnlockButton(onPressed: _unlock),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Cerrar sesión'),
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

/// The big round fingerprint/face button.
class _UnlockButton extends StatefulWidget {
  const _UnlockButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_UnlockButton> createState() => _UnlockButtonState();
}

class _UnlockButtonState extends State<_UnlockButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Desbloquear',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? .92 : 1,
          duration: Motion.of(context, Motion.fast),
          curve: Motion.standard,
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? palette.accent : palette.pill,
                ),
                // Face ID on iPhones, the fingerprint on Android.
                child: Icon(
                  defaultTargetPlatform == TargetPlatform.iOS
                      ? Icons.face
                      : Icons.fingerprint,
                  size: 40,
                  color: dark ? palette.onAccent : palette.accent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Desbloquear',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
