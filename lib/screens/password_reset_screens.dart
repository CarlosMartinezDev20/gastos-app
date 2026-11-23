import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../providers/auth_provider.dart';
import '../widgets/ios_ui.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Asks Supabase Auth to email a reset link. The link opens the app
/// (deep link), which then shows [ResetPasswordScreen].
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  String? _error;

  /// The address the last link went to.
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/login');

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) setState(() => _sentTo = email);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sentTo = _sentTo;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Row(
                    children: [
                      CircleButton(
                        icon: CupertinoIcons.chevron_left,
                        tooltip: 'Volver',
                        onPressed: _back,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const LargeTitle(
                    title: 'Recuperar contraseña',
                    subtitle:
                        'Te enviaremos un enlace para elegir una contraseña nueva.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.send,
                    autofillHints: const [AutofillHints.email],
                    onFieldSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(CupertinoIcons.mail),
                    ),
                    validator: (v) =>
                        v == null || !_emailPattern.hasMatch(v.trim())
                        ? 'Escribe un correo válido'
                        : null,
                  ),
                  FormError(_error),
                  if (sentTo != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.mint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          // Supabase answers the same for unknown emails, so
                          // the message can't promise the account exists.
                          'Si hay una cuenta con $sentTo, te enviamos un '
                          'enlace. Ábrelo en este teléfono para elegir tu '
                          'contraseña nueva. Revisa también la carpeta de spam.',
                          style: TextStyle(
                            color: palette.onMint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  PillCta(
                    label: sentTo == null ? 'Enviar enlace' : 'Enviar de nuevo',
                    loading: _sending,
                    onPressed: _send,
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

/// Opened by a reset link: the session is the link's, so the new password
/// is all Supabase needs.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _visible = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
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
          .completePasswordReset(_password.text);
      messenger.showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibility = IconButton(
      tooltip: _visible ? 'Ocultar contraseña' : 'Ver contraseña',
      onPressed: () => setState(() => _visible = !_visible),
      icon: Icon(_visible ? CupertinoIcons.eye_slash : CupertinoIcons.eye),
    );
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  children: [
                    const LargeTitle(
                      title: 'Contraseña nueva',
                      subtitle: 'Elige la contraseña con la que entrarás.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _password,
                      obscureText: !_visible,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Contraseña nueva',
                        prefixIcon: const Icon(CupertinoIcons.lock),
                        suffixIcon: visibility,
                      ),
                      validator: (v) => v == null || v.length < 8
                          ? 'Mínimo 8 caracteres'
                          : v.length > 72
                          ? 'Máximo 72 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: !_visible,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        labelText: 'Repite la contraseña',
                        prefixIcon: Icon(CupertinoIcons.lock),
                      ),
                      validator: (v) => v != _password.text
                          ? 'Las contraseñas no coinciden'
                          : null,
                    ),
                    FormError(_error),
                    const SizedBox(height: 20),
                    PillCta(
                      label: 'Guardar contraseña',
                      loading: _saving,
                      onPressed: _save,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => ref
                                .read(authControllerProvider.notifier)
                                .logout(),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
