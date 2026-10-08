import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../providers/auth_provider.dart';
import '../widgets/ios_ui.dart';

/// Asks for the current password and a new one. The API signs out every
/// other device; this one keeps its session.
Future<void> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const _ChangePasswordSheet(),
  );
}

/// Deletes the account and everything in it, after the password and a
/// last confirmation.
Future<void> showDeleteAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const _DeleteAccountSheet(),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Contraseña actualizada. Cerramos tu sesión en otros equipos.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return KeyboardInset(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cambiar contraseña',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Por seguridad, cerraremos tu sesión en los demás equipos.',
                  style: TextStyle(color: palette.muted),
                ),
                const SizedBox(height: 16),
                EntranceAutofocus(
                  builder: (context, focusNode) => _PasswordField(
                    controller: _current,
                    focusNode: focusNode,
                    label: 'Contraseña actual',
                    autofill: AutofillHints.password,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Escribe tu contraseña actual'
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _next,
                  label: 'Nueva contraseña',
                  autofill: AutofillHints.newPassword,
                  validator: (v) => v == null || v.length < 8
                      ? 'Mínimo 8 caracteres'
                      : v.length > 72
                      ? 'Máximo 72 caracteres'
                      : v == _current.text
                      ? 'Debe ser distinta de la actual'
                      : null,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _repeat,
                  label: 'Repite la nueva contraseña',
                  autofill: AutofillHints.newPassword,
                  done: true,
                  onSubmitted: _save,
                  validator: (v) =>
                      v != _next.text ? 'Las contraseñas no coinciden' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorNote(_error!),
                ],
                const SizedBox(height: 20),
                PillCta(
                  label: 'Cambiar contraseña',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting || !_formKey.currentState!.validate()) return;
    final confirmed = await confirmAction(
      context,
      title: '¿Eliminar tu cuenta?',
      message: 'Se borrarán todos tus datos y no podrás recuperarlos.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      await ref.read(authRepositoryProvider).deleteAccount(_password.text);
      // Close the sheet before signing out sends the router to /login.
      navigator.pop();
      await auth.logout();
      messenger.showSnackBar(
        const SnackBar(content: Text('Tu cuenta fue eliminada')),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final danger = Theme.of(context).colorScheme.error;
    return KeyboardInset(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Eliminar cuenta',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Se borran para siempre tus movimientos, metas, presupuestos, '
                'tarjetas, suscripciones y categorías propias. Si quieres '
                'conservar tus movimientos, expórtalos antes desde Historial.',
                style: TextStyle(color: palette.muted),
              ),
              const SizedBox(height: 16),
              _PasswordField(
                controller: _password,
                label: 'Tu contraseña',
                autofill: AutofillHints.password,
                done: true,
                onSubmitted: _delete,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Escribe tu contraseña' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorNote(_error!),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: danger,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: _deleting ? null : _delete,
                icon: _deleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CupertinoIcons.trash),
                label: const Text('Eliminar mi cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.autofill,
    required this.validator,
    this.focusNode,
    this.done = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String autofill;
  final FormFieldValidator<String> validator;
  final FocusNode? focusNode;
  final bool done;
  final VoidCallback? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: !_visible,
      maxLength: 72,
      buildCounter: _noCounter,
      autofillHints: [widget.autofill],
      textInputAction: widget.done
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(CupertinoIcons.lock),
        suffixIcon: IconButton(
          tooltip: _visible ? 'Ocultar contraseña' : 'Ver contraseña',
          onPressed: () => setState(() => _visible = !_visible),
          icon: Icon(_visible ? CupertinoIcons.eye_slash : CupertinoIcons.eye),
        ),
      ),
      validator: widget.validator,
    );
  }

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.blush,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(color: palette.onBlush, fontWeight: FontWeight.w600),
      ),
    );
  }
}
