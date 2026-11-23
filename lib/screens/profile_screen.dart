import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_palette.dart';
import '../providers/app_lock_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/accent_picker.dart';
import '../widgets/app_states.dart';
import '../widgets/ios_ui.dart';
import '../widgets/theme_crossfade.dart';
import '../providers/payment_reminders_provider.dart';
import 'account_sheets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return auth.when(
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
        final palette = context.palette;
        final themeMode = ref.watch(themeControllerProvider);
        final accent = ref.watch(accentControllerProvider);
        final parts = user.name.trim().split(RegExp(r'\s+'));
        final initials = parts
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0])
            .join()
            .toUpperCase();
        // Opened from the avatar on Inicio (no tab of its own): a back
        // button like the other pages opened from there.
        void back() => context.go('/home');
        return CollapsingTitle(
          title: 'Perfil',
          onBack: back,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 12, 20, dockClearance(context)),
            children: [
              Row(
                children: [
                  CircleButton(
                    icon: CupertinoIcons.chevron_left,
                    tooltip: 'Volver',
                    onPressed: back,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const LargeTitle(title: 'Perfil'),
              const SizedBox(height: 20),
              // Centered like the account page of iOS Settings, no card:
              // a big avatar, name and email.
              Center(child: InitialsAvatar(initials: initials, size: 88)),
              const SizedBox(height: 14),
              Text(
                user.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 14),
              Center(
                child: Tooltip(
                  message: 'Editar nombre',
                  excludeFromSemantics: true,
                  child: FilledButton.icon(
                    onPressed: () => _editName(context, ref, user.name),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: palette.card,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(CupertinoIcons.pencil, size: 16),
                    label: const Text('Editar nombre'),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              InsetGroup(
                header: 'Apariencia',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedTabs<ThemeMode>(
                          segments: const {
                            ThemeMode.light: 'Claro',
                            ThemeMode.dark: 'Oscuro',
                            ThemeMode.system: 'Automático',
                          },
                          selected: themeMode,
                          onChanged: (mode) => ThemeCrossfade.run(
                            context,
                            () => ref
                                .read(themeControllerProvider.notifier)
                                .setMode(mode),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AccentPicker(
                          selected: accent,
                          onChanged: (value) => ThemeCrossfade.run(
                            context,
                            () => ref
                                .read(accentControllerProvider.notifier)
                                .set(value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              InsetGroup(
                header: 'Preferencias',
                children: [
                  if (ref.watch(paymentReminderServiceProvider).supported)
                    InsetTile(
                      icon: CupertinoIcons.bell_fill,
                      iconColor: const Color(0xFFE5484D),
                      title: 'Recordatorios de pago',
                      trailing: AppSwitch(
                        value: ref.watch(paymentRemindersEnabledProvider),
                        onChanged: (value) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final on = await ref
                              .read(paymentRemindersEnabledProvider.notifier)
                              .set(value);
                          if (value && !on) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Activa las notificaciones de la app en los '
                                  'ajustes del teléfono.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  if (ref.watch(biometricAuthProvider).supported)
                    InsetTile(
                      icon: Icons.fingerprint,
                      iconColor: const Color(0xFF0A84FF),
                      title: 'Bloqueo con huella o rostro',
                      trailing: AppSwitch(
                        value: ref.watch(appLockEnabledProvider),
                        onChanged: (value) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final on = await ref
                              .read(appLockEnabledProvider.notifier)
                              .set(value);
                          if (value && !on) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se activó. Revisa que tu teléfono tenga '
                                  'huella, rostro o un PIN configurado.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  InsetTile(
                    icon: CupertinoIcons.money_dollar_circle_fill,
                    iconColor: const Color(0xFF0E8A5F),
                    title: 'Moneda',
                    trailing: Text(
                      'USD',
                      style: TextStyle(color: palette.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              InsetGroup(
                header: 'Ayuda',
                children: [
                  InsetTile(
                    icon: CupertinoIcons.sparkles,
                    iconColor: const Color(0xFFFF9F0A),
                    title: 'Ver recorrido de la app',
                    onTap: () {
                      ref.read(onboardingTourProvider.notifier).request();
                      context.go('/home');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              InsetGroup(
                header: 'Cuenta',
                children: [
                  InsetTile(
                    icon: CupertinoIcons.lock_fill,
                    iconColor: const Color(0xFF0A84FF),
                    title: 'Cambiar contraseña',
                    onTap: () => showChangePasswordSheet(context),
                  ),
                  InsetTile(
                    icon: CupertinoIcons.square_arrow_right,
                    title: 'Cerrar sesión',
                    destructive: true,
                    onTap: () => _confirmLogout(context, ref),
                  ),
                  InsetTile(
                    icon: CupertinoIcons.trash,
                    title: 'Eliminar cuenta',
                    destructive: true,
                    onTap: () => showDeleteAccountSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  AppConstants.footer,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: palette.muted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await confirmAction(
    context,
    title: '¿Cerrar sesión?',
    message: 'Tendrás que volver a iniciar sesión para ver tus datos.',
    confirmLabel: 'Cerrar sesión',
  );
  if (confirmed) {
    await ref.read(authControllerProvider.notifier).logout();
  }
}

Future<void> _editName(
  BuildContext context,
  WidgetRef ref,
  String current,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _EditNameDialog(initial: current),
  );
  if (name == null || name == current) return;
  try {
    await ref.read(authControllerProvider.notifier).updateName(name);
    messenger.showSnackBar(const SnackBar(content: Text('Nombre actualizado')));
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tu nombre'),
      content: Form(
        key: _formKey,
        child: EntranceAutofocus(
          builder: (context, focusNode) => TextFormField(
            controller: _controller,
            focusNode: focusNode,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
            onFieldSubmitted: (_) => _submit(),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Escribe tu nombre' : null,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
