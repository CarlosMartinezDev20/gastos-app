import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_palette.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_states.dart';
import '../widgets/ios_ui.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/theme_crossfade.dart';

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
        final darkMode = ref.watch(isDarkModeProvider);
        final parts = user.name.trim().split(RegExp(r'\s+'));
        final initials = parts
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0])
            .join()
            .toUpperCase();
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, dockClearance(context)),
          children: [
            LargeTitle(title: 'Perfil', trailing: const [ThemeToggle()]),
            const SizedBox(height: 20),
            BentoCard(
              color: palette.ink,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: palette.accent,
                    child: Text(
                      initials.isEmpty ? 'U' : initials,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: palette.onInk),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(color: palette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar nombre',
                    onPressed: () => _editName(context, ref, user.name),
                    color: palette.onInk,
                    icon: const Icon(CupertinoIcons.pencil),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            InsetGroup(
              header: 'Finanzas',
              children: [
                InsetTile(
                  icon: CupertinoIcons.creditcard_fill,
                  iconColor: const Color(0xFF1E3A8A),
                  title: 'Mi wallet',
                  onTap: () => context.push('/wallet'),
                ),
                InsetTile(
                  icon: CupertinoIcons.square_grid_2x2_fill,
                  iconColor: const Color(0xFF6E8B00),
                  title: 'Categorías',
                  onTap: () => context.push('/categories'),
                ),
                InsetTile(
                  icon: CupertinoIcons.slider_horizontal_3,
                  iconColor: const Color(0xFF7A5AF8),
                  title: 'Calculadora de presupuestos',
                  onTap: () => context.push('/budget-planner'),
                ),
                InsetTile(
                  icon: CupertinoIcons.repeat,
                  iconColor: const Color(0xFF3B82C4),
                  title: 'Movimientos recurrentes',
                  onTap: () => context.push('/recurring'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            InsetGroup(
              header: 'Preferencias',
              children: [
                InsetTile(
                  icon: CupertinoIcons.moon_fill,
                  iconColor: const Color(0xFF6E56CF),
                  title: 'Tema oscuro',
                  trailing: AppSwitch(
                    value: darkMode,
                    onChanged: (value) => ThemeCrossfade.run(
                      context,
                      () => ref
                          .read(themeControllerProvider.notifier)
                          .setDarkMode(value),
                    ),
                  ),
                ),
                InsetTile(
                  icon: CupertinoIcons.money_dollar_circle_fill,
                  iconColor: const Color(0xFF0E8A5F),
                  title: 'Moneda',
                  trailing: Text('USD', style: TextStyle(color: palette.muted)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            InsetGroup(
              children: [
                InsetTile(
                  icon: CupertinoIcons.square_arrow_right,
                  title: 'Cerrar sesión',
                  destructive: true,
                  onTap: () => _confirmLogout(context, ref),
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
