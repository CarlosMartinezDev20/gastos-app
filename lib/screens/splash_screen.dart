import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_palette.dart';
import '../providers/auth_provider.dart';
import '../widgets/mascot.dart';

/// Shown while the stored session is being checked on startup.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The saved session couldn't be opened yet (no connection, server).
    final error = ref.watch(sessionRestoreErrorProvider);
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -.2),
            radius: .9,
            colors: [
              palette.accent.withValues(alpha: .35),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Mascot(mood: MascotMood.excited, size: 150),
                const Gap(16),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
                const Gap(4),
                Text(
                  '$mascotName cuida tus ahorros',
                  style: TextStyle(color: palette.muted),
                ),
                const Gap(24),
                if (error == null)
                  SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.primary,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            error.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurface),
                          ),
                          const Gap(16),
                          FilledButton(
                            onPressed: () => ref
                                .read(authControllerProvider.notifier)
                                .retryRestore(),
                            child: const Text('Reintentar'),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(authControllerProvider.notifier)
                                .logout(),
                            child: const Text('Cerrar sesión'),
                          ),
                        ],
                      ),
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
