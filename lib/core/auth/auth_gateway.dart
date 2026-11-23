import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../errors/api_exception.dart';

/// What an Auth link opened in the app did (supabase_flutter reads the
/// deep link and starts the session).
enum AuthLinkEvent {
  /// A password reset link: the user must choose a new password now.
  passwordRecovery,

  /// Signed in from a link (e.g. confirming the email).
  signedIn,
}

/// The account exists but its email isn't confirmed yet (only when email
/// confirmation is on in Supabase Auth).
class EmailNotConfirmedException extends ApiException {
  const EmailNotConfirmedException(this.email)
    : super('Confirma tu correo para entrar. Te enviamos un enlace a $email.');

  final String email;
}

/// The account service (Supabase Auth): signs in and out and hands out the
/// access token the API checks. Tests replace it with a fake.
abstract interface class AuthGateway {
  /// The current session's token, possibly expired (null when signed out).
  String? get accessToken;

  /// A token that is still valid, refreshing the session when it is about
  /// to expire. Falls back to the current one when it can't refresh
  /// (offline), so cached answers can still be found.
  Future<String?> freshAccessToken();

  /// Refreshes the session now (after the API rejected its token). Null
  /// when there is no session or Supabase refused the refresh token: the
  /// session is over. Throws when Supabase can't be reached.
  Future<String?> refreshAccessToken();

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// Checks [current], sets [next] and signs out the other devices.
  Future<void> changePassword({
    required String email,
    required String current,
    required String next,
  });

  /// Forgets the session on this device.
  Future<void> signOut();

  /// Emails a reset link that opens the app ([Env.authRedirectUrl]).
  Future<void> sendPasswordReset(String email);

  /// Sets the password of the session a reset link opened.
  Future<void> setNewPassword(String password);

  /// Sends the confirmation email again.
  Future<void> resendConfirmation(String email);

  /// Auth links opened in the app (reset, confirmation).
  Stream<AuthLinkEvent> get linkEvents;
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._auth);

  final GoTrueClient _auth;

  @override
  String? get accessToken => _auth.currentSession?.accessToken;

  @override
  Future<String?> freshAccessToken() async {
    final session = _auth.currentSession;
    if (session == null || !session.isExpired) return session?.accessToken;
    try {
      return (await _auth.refreshSession()).session?.accessToken;
    } on AuthException catch (error) {
      // Revoked or expired refresh token: the session is over.
      if (error is! AuthRetryableFetchException) return null;
      return session.accessToken;
    } catch (_) {
      return session.accessToken;
    }
  }

  @override
  Future<String?> refreshAccessToken() async {
    if (_auth.currentSession == null) return null;
    try {
      return (await _auth.refreshSession()).session?.accessToken;
    } on AuthRetryableFetchException {
      rethrow;
    } on AuthException {
      return null;
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() async {
        try {
          await _auth.signInWithPassword(email: email, password: password);
        } on AuthApiException catch (error) {
          if (error.code == 'email_not_confirmed') {
            throw EmailNotConfirmedException(email);
          }
          rethrow;
        }
      });

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => _guard(() async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
      emailRedirectTo: Env.authRedirectUrl,
    );
    // Email confirmation on: the account waits for the link.
    if (response.session == null) throw EmailNotConfirmedException(email);
  });

  @override
  Future<void> changePassword({
    required String email,
    required String current,
    required String next,
  }) => _guard(() async {
    if (current == next) {
      throw const ApiException(
        'La nueva contraseña debe ser distinta de la actual',
        statusCode: 400,
      );
    }
    try {
      await _auth.signInWithPassword(email: email, password: current);
    } on AuthApiException catch (error) {
      if (error.code != 'invalid_credentials') rethrow;
      throw const ApiException(
        'La contraseña actual no es correcta',
        statusCode: 400,
      );
    }
    await _auth.updateUser(UserAttributes(password: next));
    await _auth.signOut(scope: SignOutScope.others);
  });

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Offline or already revoked: the local session is cleared anyway.
    }
  }

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _auth.resetPasswordForEmail(email, redirectTo: Env.authRedirectUrl),
  );

  @override
  Future<void> setNewPassword(String password) =>
      _guard(() => _auth.updateUser(UserAttributes(password: password)));

  @override
  Future<void> resendConfirmation(String email) => _guard(
    () => _auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: Env.authRedirectUrl,
    ),
  );

  @override
  Stream<AuthLinkEvent> get linkEvents => _auth.onAuthStateChange
      .map(
        (state) => switch (state.event) {
          AuthChangeEvent.passwordRecovery => AuthLinkEvent.passwordRecovery,
          AuthChangeEvent.signedIn => AuthLinkEvent.signedIn,
          _ => null,
        },
      )
      .where((event) => event != null)
      .cast<AuthLinkEvent>();

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on AuthException catch (error) {
      throw authError(error);
    }
  }
}

/// Supabase Auth errors in the app's language.
ApiException authError(AuthException error) {
  final message = switch (error.code) {
    'invalid_credentials' => 'Correo o contraseña incorrectos',
    'user_already_exists' ||
    'email_exists' => 'Ya existe una cuenta con ese correo',
    'weak_password' => 'La contraseña debe tener al menos 8 caracteres',
    'email_address_invalid' => 'El correo no es válido',
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' => 'Demasiados intentos, espera un momento',
    'email_not_confirmed' => 'Confirma tu correo antes de iniciar sesión',
    'same_password' => 'La nueva contraseña debe ser distinta de la actual',
    'otp_expired' ||
    'flow_state_expired' => 'El enlace expiró. Pide uno nuevo.',
    _ when error is AuthRetryableFetchException =>
      'No se pudo conectar con el servicio de cuentas.',
    _ => error.message,
  };
  final status = int.tryParse(error.statusCode ?? '');
  return ApiException(
    message,
    // Wrong credentials are a form error here, not an expired session.
    statusCode: status == 401 ? 400 : status,
  );
}

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => SupabaseAuthGateway(Supabase.instance.client.auth),
);
