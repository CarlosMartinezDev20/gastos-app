import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_states.dart';
import '../widgets/soft_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: auth.when(
          loading: () => const AppShimmer(),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.read(authControllerProvider.notifier).load(),
          ),
          data: (user) {
            if (user == null) {
              return const AppEmptyState(
                title: 'Sin sesión',
                subtitle: 'Inicia sesión para ver tu perfil.',
              );
            }
            final darkMode = ref.watch(isDarkModeProvider);
            final initial = user.name.isEmpty ? 'U' : user.name[0];
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 124),
              children: [
                SoftCard(
                  color: AppColors.blush.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? .16
                        : .78,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          initial.toUpperCase(),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                            ),
                            const Gap(4),
                            Text(user.email),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(28),
                SoftCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.dark_mode_outlined),
                        title: const Text('Tema oscuro'),
                        value: darkMode,
                        onChanged: (value) => ref
                            .read(themeControllerProvider.notifier)
                            .setDarkMode(value),
                      ),
                      const Divider(),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.notifications_outlined),
                        title: Text('Recordatorios de pago'),
                        trailing: Switch(value: false, onChanged: null),
                      ),
                      const Divider(),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.payments_outlined),
                        title: Text('Moneda'),
                        trailing: Text('USD'),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.download_outlined),
                        title: const Text('Exportar datos'),
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Exportación lista para conectar en API.',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(20),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
                const Gap(28),
                Center(
                  child: Text(
                    AppConstants.footer,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
