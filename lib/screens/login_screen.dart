import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/soft_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _loading = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (_register) {
        await auth.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text.trim(),
        );
      } else {
        await auth.login(_email.text.trim(), _password.text.trim());
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finanzas M3',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'Tu espacio premium para ordenar ingresos, gastos y metas universitarias.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Gap(26),
                  SoftCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (_register) ...[
                            TextFormField(
                              controller: _name,
                              decoration: const InputDecoration(
                                labelText: 'Nombre',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Escribe tu nombre'
                                  : null,
                            ),
                            const Gap(14),
                          ],
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (v) => v == null || !v.contains('@')
                                ? 'Correo válido requerido'
                                : null,
                          ),
                          const Gap(14),
                          TextFormField(
                            controller: _password,
                            obscureText: !_passwordVisible,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _passwordVisible
                                    ? 'Ocultar contraseña'
                                    : 'Ver contraseña',
                                onPressed: () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.length < 6
                                ? 'Mínimo 6 caracteres'
                                : null,
                          ),
                          const Gap(20),
                          FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _register
                                        ? 'Crear cuenta'
                                        : 'Entrar a Finanzas M3',
                                  ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() => _register = !_register),
                            child: Text(
                              _register
                                  ? 'Ya tengo cuenta'
                                  : 'Crear cuenta nueva',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: .08),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
