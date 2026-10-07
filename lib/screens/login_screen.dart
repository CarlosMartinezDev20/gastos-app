import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_palette.dart';
import '../providers/auth_provider.dart';
import '../widgets/ios_ui.dart';
import '../widgets/mascot.dart';
import '../core/theme/motion.dart';

/// Wider than this, the welcome and the form sit side by side.
const _splitMinWidth = 900.0;
const _heroAspectRatio = 1.3;
const _heroMinHeight = 190.0;

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The auth sheet covers this page: its Michi and entrances pause.
    return PauseWhenCovered(
      child: Scaffold(
        // On phones the form is a sheet with its own keyboard padding; resizing
        // the page behind it would only reflow the welcome under the scrim.
        resizeToAvoidBottomInset:
            MediaQuery.sizeOf(context).width >= _splitMinWidth,
        body: Stack(
          children: [
            const Positioned.fill(child: _Backdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= _splitMinWidth) {
                    return Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(40),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: const _Welcome(showActions: false),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(40),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: FadeSlideIn(
                                  index: 2,
                                  child: _FormCard(child: const AuthForm()),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  const padding = EdgeInsets.fromLTRB(20, 8, 20, 24);
                  final width = math.min(
                    constraints.maxWidth - padding.horizontal,
                    480.0,
                  );
                  return SingleChildScrollView(
                    padding: padding,
                    child: Center(
                      // At least as tall as the screen; Michi's card takes
                      // the room left, so the page only scrolls when even
                      // its smallest size doesn't fit.
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 480,
                          minHeight: math.max(
                            0,
                            constraints.maxHeight - padding.vertical,
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: _Welcome(
                            showActions: true,
                            heroMaxHeight: width / _heroAspectRatio,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft colored glows behind the page.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final background = Theme.of(context).scaffoldBackgroundColor;
    Widget glow(Color color, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: .55), color.withValues(alpha: 0)],
        ),
      ),
    );
    return IgnorePointer(
      child: ColoredBox(
        color: background,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(top: -160, left: -120, child: glow(palette.accent, 460)),
            Positioned(top: 120, right: -160, child: glow(palette.lilac, 420)),
            Positioned(bottom: -180, left: 40, child: glow(palette.mint, 420)),
          ],
        ),
      ),
    );
  }
}

/// White card holding the form, with a soft shadow.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .35 : .08),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: BentoCard(
        border: true,
        radius: 32,
        color: palette.card,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: child,
      ),
    );
  }
}

Future<void> _openAuthSheet(BuildContext context, {bool register = false}) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => KeyboardInset(
      extra: 24,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: AuthForm(initialRegister: register, inSheet: true),
      ),
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.showActions, this.heroMaxHeight});

  /// On phones the form opens in a sheet from these buttons.
  final bool showActions;

  /// When set, the hero card shrinks (down to [_heroMinHeight]) to fit the
  /// height the parent gives; it needs an [IntrinsicHeight] above.
  final double? heroMaxHeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.pill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.money_dollar,
                  color: palette.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppConstants.appName,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (showActions)
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: const StadiumBorder(),
                    textStyle: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => _openAuthSheet(context),
                  child: const Text('Entrar'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (heroMaxHeight case final maxHeight?)
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: _heroMinHeight,
                maxHeight: math.max(_heroMinHeight, maxHeight),
              ),
              // A Stack of only positioned children has no intrinsic height,
              // so IntrinsicHeight counts the card at its minimum.
              child: const Stack(
                children: [
                  Positioned.fill(
                    child: FadeSlideIn(index: 1, child: _HeroIllustration()),
                  ),
                ],
              ),
            ),
          )
        else
          const FadeSlideIn(index: 1, child: _HeroIllustration()),
        const SizedBox(height: 26),
        FadeSlideIn(
          index: 2,
          child: Text(
            'Tu dinero, claro.\nTus metas, cerca.',
            style: text.displaySmall?.copyWith(fontSize: 34, height: 1.08),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 3,
          child: Text(
            'Registra ingresos y gastos en segundos, mira a dónde va tu dinero '
            'y ahorra para lo que de verdad quieres. $mascotName te acompaña.',
            style: text.bodyLarge?.copyWith(color: palette.muted, height: 1.4),
          ),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          index: 4,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeatureChip(
                icon: CupertinoIcons.doc_text,
                label: 'Gastos al día',
                color: palette.blush,
                onColor: palette.onBlush,
              ),
              _FeatureChip(
                icon: CupertinoIcons.flag,
                label: 'Metas de ahorro',
                color: palette.lilac,
                onColor: palette.onLilac,
              ),
              _FeatureChip(
                icon: CupertinoIcons.chart_bar,
                label: 'Análisis',
                color: palette.mint,
                onColor: palette.onMint,
              ),
            ],
          ),
        ),
        if (showActions) ...[
          const SizedBox(height: 28),
          FadeSlideIn(
            index: 5,
            child: PillCta(
              label: 'Comenzar',
              onPressed: () => _openAuthSheet(context),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('¿Nuevo aquí?', style: TextStyle(color: palette.muted)),
              TextButton(
                onPressed: () => _openAuthSheet(context, register: true),
                child: const Text('Crea tu cuenta'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: onColor,
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: onColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Michi in the middle of a gradient card, surrounded by floating app
/// pieces (an income, an expense and a goal).
class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return AspectRatio(
      aspectRatio: _heroAspectRatio,
      child: BentoCard(
        color: palette.accent,
        radius: 32,
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _LoopPainter(palette.onAccent)),
              ),
              // Michi stays interactive; the floating pieces are decoration.
              Align(
                alignment: const Alignment(0, .35),
                child: Mascot(
                  mood: MascotMood.happy,
                  size: (c.maxHeight * .62).clamp(80.0, 200.0),
                  onTap: () {},
                ),
              ),
              ExcludeSemantics(
                child: Stack(
                  children: [
                    Positioned(
                      left: 16,
                      top: 16,
                      child: FadeSlideIn(
                        index: 3,
                        child: _MiniPill(
                          color: palette.ink,
                          onColor: palette.accent,
                          icon: CupertinoIcons.arrow_down,
                          label: r'+$300.00',
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: c.maxHeight * .26,
                      child: FadeSlideIn(
                        index: 4,
                        child: _MiniPill(
                          color: palette.blush,
                          onColor: palette.onBlush,
                          icon: CupertinoIcons.arrow_up,
                          label: r'−$8.50',
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      width: (c.maxWidth * .34).clamp(110.0, 170.0),
                      child: FadeSlideIn(
                        index: 5,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Meta · Laptop',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall?.copyWith(
                                  color: palette.muted,
                                ),
                              ),
                              Text(
                                '62%',
                                style: text.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: LinearProgressIndicator(
                                  value: .62,
                                  minHeight: 5,
                                  color: palette.chartIncome,
                                  backgroundColor: palette.hairline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.color,
    required this.onColor,
    required this.icon,
    required this.label,
  });

  final Color color;
  final Color onColor;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: onColor,
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: onColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Dotted orbit lines behind Michi.
class _LoopPainter extends CustomPainter {
  const _LoopPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final center = Offset(size.width / 2, size.height * .62);
    for (final r in [.28, .42, .58]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * r * 2,
          height: size.height * r * 1.3,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LoopPainter oldDelegate) => oldDelegate.color != color;
}

/// Login / sign-up form. Errors are shown inline so they stay visible in a sheet.
class AuthForm extends ConsumerStatefulWidget {
  const AuthForm({
    super.key,
    this.initialRegister = false,
    this.inSheet = false,
  });

  final bool initialRegister;
  final bool inSheet;

  @override
  ConsumerState<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _register = widget.initialRegister;
  bool _loading = false;
  bool _passwordVisible = false;
  String? _error;

  // Michi watches the fields: it follows what you type and covers its eyes
  // while you write the password. Only its header rebuilds on each key.
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  late final _watched = Listenable.merge([
    _name,
    _email,
    _nameFocus,
    _emailFocus,
    _passwordFocus,
  ]);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Offset? get _gaze {
    final field = _emailFocus.hasFocus
        ? _email
        : _nameFocus.hasFocus
        ? _name
        : null;
    if (field == null) return null;
    final progress = (field.text.length / 28).clamp(0.0, 1.0);
    return Offset(-.8 + progress * 1.6, .8);
  }

  (MascotMood, String) get _michi {
    if (_loading) return (MascotMood.excited, '¡Revisando…!');
    if (_error != null) {
      return (
        MascotMood.worried,
        'Ups, algo no coincide. ¿Lo intentamos otra vez?',
      );
    }
    if (_passwordFocus.hasFocus) {
      return _passwordVisible
          ? (MascotMood.happy, 'Solo un vistazo…')
          : (MascotMood.happy, 'No miro, ¡lo prometo!');
    }
    if (_emailFocus.hasFocus) {
      return (
        MascotMood.happy,
        _email.text.isEmpty ? '¿Cuál es tu correo?' : 'Mmm… te escucho.',
      );
    }
    if (_nameFocus.hasFocus) return (MascotMood.happy, '¿Cómo te llamas?');
    return _register
        ? (MascotMood.excited, '¡Miau! Vamos a crear tu cuenta.')
        : (MascotMood.happy, '¡Hola! Te extrañaba.');
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (_register) {
        await auth.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
      } else {
        await auth.login(_email.text.trim(), _password.text);
      }
      // The router leaves /login on success; close the sheet if it is still up.
      if (mounted &&
          widget.inSheet &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // With the keyboard up the sheet drops the heading and shrinks
            // Michi so Michi, the fields and the button stay visible together.
            KeyboardVisibilityBuilder(
              builder: (context, keyboardVisible) {
                final compact = widget.inSheet && keyboardVisible;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListenableBuilder(
                      listenable: _watched,
                      builder: (context, _) => _MichiHeader(
                        mood: _michi.$1,
                        message: _michi.$2,
                        gaze: _gaze,
                        coverEyes: _passwordFocus.hasFocus,
                        peek: _passwordVisible,
                        compact: compact,
                      ),
                    ),
                    AnimatedSize(
                      duration: Motion.of(context, Motion.medium),
                      curve: Motion.standard,
                      alignment: Alignment.topCenter,
                      child: compact
                          ? const SizedBox(width: double.infinity, height: 10)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 14),
                                Text(
                                  _register
                                      ? 'Crea tu cuenta'
                                      : 'Bienvenido de nuevo',
                                  style: text.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _register
                                      ? 'Empieza a ordenar tus finanzas hoy.'
                                      : 'Entra para ver tu balance y tus metas.',
                                  style: TextStyle(color: palette.muted),
                                ),
                                const SizedBox(height: 18),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
            SegmentedTabs<bool>(
              segments: const {false: 'Iniciar sesión', true: 'Registrarme'},
              selected: _register,
              onChanged: (value) {
                if (_loading) return;
                setState(() {
                  _register = value;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 18),
            if (_register) ...[
              TextFormField(
                controller: _name,
                focusNode: _nameFocus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(CupertinoIcons.person),
                  counterText: '',
                ),
                maxLength: 60,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe tu nombre' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _email,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(CupertinoIcons.mail),
              ),
              validator: (v) =>
                  v == null ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())
                  ? 'Escribe un correo válido'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              focusNode: _passwordFocus,
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
              autofillHints: [
                _register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(CupertinoIcons.lock),
                suffixIcon: IconButton(
                  tooltip: _passwordVisible
                      ? 'Ocultar contraseña'
                      : 'Ver contraseña',
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  icon: Icon(
                    _passwordVisible
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.eye,
                  ),
                ),
              ),
              validator: (v) =>
                  // New accounts need 8; older ones may still sign in.
                  v == null || v.isEmpty
                  ? 'Escribe tu contraseña'
                  : _register && v.length < 8
                  ? 'Mínimo 8 caracteres'
                  : null,
            ),
            AnimatedSize(
              duration: Motion.of(context, Motion.medium),
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.blush,
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                              _error!,
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
            const SizedBox(height: 20),
            PillCta(
              label: _register ? 'Crear cuenta' : 'Iniciar sesión',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Michi with a speech bubble that reacts to the form.
class _MichiHeader extends StatelessWidget {
  const _MichiHeader({
    required this.mood,
    required this.message,
    required this.gaze,
    required this.coverEyes,
    required this.peek,
    this.compact = false,
  });

  final MascotMood mood;
  final String message;
  final Offset? gaze;
  final bool coverEyes;
  final bool peek;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final animations =
        Mascot.animate && !MediaQuery.disableAnimationsOf(context);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: SpeechBubble(
              color: palette.ink,
              child: AnimatedSwitcher(
                duration: animations ? Motion.medium : Duration.zero,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: .92, end: 1.0).animate(animation),
                    alignment: Alignment.centerRight,
                    child: child,
                  ),
                ),
                child: Text(
                  message,
                  key: ValueKey(message),
                  style: TextStyle(
                    color: palette.onInk,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(end: compact ? 64 : 92),
          duration: animations ? Motion.medium : Duration.zero,
          curve: Motion.standard,
          builder: (context, size, _) => Mascot(
            mood: mood,
            size: size,
            gaze: gaze,
            coverEyes: coverEyes,
            peek: peek,
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
