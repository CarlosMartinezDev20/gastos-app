// Runs the app's real auth and data classes against PRODUCTION (Supabase
// Auth + the Render API) with a throwaway account that deletes itself at
// the end. Not part of `flutter test` (outside test/); run on demand:
//
//   flutter test test_production/production_smoke_test.dart
//
// Override the targets with --dart-define (see lib/core/config/env.dart).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:appgastos/core/auth/auth_gateway.dart';
import 'package:appgastos/core/auth/secure_session_storage.dart';
import 'package:appgastos/core/config/env.dart';
import 'package:appgastos/core/errors/api_exception.dart';
import 'package:appgastos/core/network/api_client.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/payment_method.dart';
import 'package:appgastos/repositories/auth_repository.dart';
import 'package:appgastos/repositories/finance_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What Supabase.initialize gives the app, minus the plugins.
GoTrueClient newAuthClient() => GoTrueClient(
  url: '${Env.supabaseUrl}/auth/v1',
  headers: {'apikey': Env.supabasePublishableKey},
  autoRefreshToken: false,
  asyncStorage: _MemoryAsyncStorage(),
);

class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> removeItem({required String key}) async => _values.remove(key);
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _values[key] = value;
}

/// The API rejects the first token it is given (as if it expired in
/// flight); everything else is the real gateway.
class _StaleFirstToken implements AuthGateway {
  _StaleFirstToken(this.real);
  final SupabaseAuthGateway real;
  bool stale = true;

  @override
  String? get accessToken => real.accessToken;
  @override
  Future<String?> freshAccessToken() async =>
      stale ? 'x.y.z' : real.freshAccessToken();
  @override
  Future<String?> refreshAccessToken() async {
    stale = false;
    return real.refreshAccessToken();
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      real.signIn(email: email, password: password);
  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => real.signUp(name: name, email: email, password: password);
  @override
  Future<void> changePassword({
    required String email,
    required String current,
    required String next,
  }) => real.changePassword(email: email, current: current, next: next);
  @override
  Future<void> signOut() => real.signOut();
}

// ignore_for_file: invalid_use_of_visible_for_testing_member

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test blocks real HTTP; this test is about the real servers.
  HttpOverrides.global = null;

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'appgastos.e2e.flutter.$stamp@example.com';
  final password = 'Flutter-e2e-${Random.secure().nextInt(1 << 32)}';
  final newPassword = '$password-2';
  final stranger = 'appgastos.e2e.flutter.otro.$stamp@example.com';

  late GoTrueClient authClient;
  late ApiClient api;
  late AuthRepository auth;
  late FinanceRepository finance;
  var currentPassword = password;

  (ApiClient, AuthRepository, FinanceRepository) appWith(AuthGateway g) {
    final api = ApiClient(g);
    final auth = AuthRepository(api, g);
    return (api, auth, FinanceRepository(api, auth));
  }

  setUpAll(() {
    authClient = newAuthClient();
    (api, auth, finance) = appWith(SupabaseAuthGateway(authClient));
  });

  tearDownAll(() async {
    // Whatever happened, the throwaway account goes away.
    for (final (mail, pass) in [
      (email, currentPassword),
      (email, password),
      (stranger, password),
    ]) {
      final client = newAuthClient();
      try {
        await client.signInWithPassword(email: mail, password: pass);
        final (_, repo, _) = appWith(SupabaseAuthGateway(client));
        await repo.deleteAccount(pass);
      } catch (_) {}
    }
  });

  test('production targets', () {
    expect(Env.apiBaseUrl, 'https://appgastos-api.onrender.com');
    expect(Env.supabaseUrl, 'https://gxgjbcywdsiguxfblyof.supabase.co');
    expect(Env.supabasePublishableKey, startsWith('sb_publishable_'));
  });

  test('register, profile, logout and login', () async {
    final session = await auth.register(
      name: 'Prueba Flutter',
      email: email,
      password: password,
    );
    expect(session.user.email, email);
    expect(session.user.name, 'Prueba Flutter');

    await auth.logout();
    expect(api.token, isNull);

    await expectLater(
      auth.login(email: email, password: 'incorrecta'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Correo o contraseña incorrectos',
        ),
      ),
    );
    final again = await auth.login(email: email, password: password);
    expect(again.user.email, email);
  });

  test('the session survives closing the app (secure storage)', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final storage = SecureSessionStorage(await SharedPreferences.getInstance());
    await storage.initialize();
    await storage.persistSession(
      jsonEncode(authClient.currentSession!.toJson()),
    );

    // "Reopen": a new client restores what was saved.
    final reopened = newAuthClient();
    await reopened.recoverSession((await storage.accessToken())!);
    final (_, repo, _) = appWith(SupabaseAuthGateway(reopened));
    expect((await repo.profile()).email, email);
  });

  test('refreshing gives a new token the API accepts', () async {
    final gateway = SupabaseAuthGateway(authClient);
    final before = gateway.accessToken;
    final after = await gateway.refreshAccessToken();
    expect(after, isNotNull);
    expect(after, isNot(before));
    expect(await gateway.freshAccessToken(), after, reason: 'still fresh');
    expect((await auth.profile()).email, email);
  });

  test(
    'a token the API rejects is refreshed and the request repeated',
    () async {
      final gateway = _StaleFirstToken(SupabaseAuthGateway(authClient));
      final (_, repo, _) = appWith(gateway);
      expect((await repo.profile()).email, email);
      expect(gateway.stale, isFalse, reason: 'it went through the refresh');
    },
  );

  test('wallet: create and edit a card', () async {
    final card = await finance.createPaymentMethod(
      const PaymentMethodInput(
        name: 'Visa prueba',
        kind: PaymentMethodKind.creditCard,
        color: 'ink',
        brand: CardBrand.visa,
        last4: '4242',
        creditLimit: 500,
        statementDay: 25,
        dueDay: 10,
      ),
    );
    expect(card.last4, '4242');
    final edited = await finance.updatePaymentMethod(
      card.id,
      const PaymentMethodInput(
        name: 'Visa editada',
        kind: PaymentMethodKind.creditCard,
        color: 'ink',
        brand: CardBrand.visa,
        last4: '4242',
        creditLimit: 800,
        statementDay: 25,
        dueDay: 10,
      ),
    );
    expect(edited.name, 'Visa editada');
    expect(edited.creditLimit, 800);
    expect(
      (await finance.paymentMethods()).map((m) => m.name),
      contains('Visa editada'),
    );
  });

  test('movements: create, read, edit, delete; balance and budgets', () async {
    final categories = await finance.categories();
    final food = categories.firstWhere(
      (c) => c.type == TransactionType.expense && c.isDefault,
    );
    final income = categories.firstWhere(
      (c) => c.type == TransactionType.income,
    );
    final card = (await finance.paymentMethods()).first;
    final now = DateTime.now();

    await finance.createTransaction(
      title: 'Salario prueba',
      amount: 1000,
      type: TransactionType.income,
      categoryId: income.id,
      date: now,
    );
    final lunch = await finance.createTransaction(
      title: 'Almuerzo prueba',
      amount: 12.35,
      type: TransactionType.expense,
      categoryId: food.id,
      date: now,
      paymentMethodId: card.id,
    );
    var balance = await finance.balance();
    expect(balance.totalIncome, 1000);
    expect(balance.totalExpense, 12.35);
    expect(balance.balance, 987.65);

    final edited = await finance.updateTransaction(
      lunch.id,
      title: 'Almuerzo editado',
      amount: 20.1,
      type: TransactionType.expense,
      categoryId: food.id,
      date: now,
      paymentMethodId: card.id,
    );
    expect(edited.title, 'Almuerzo editado');
    expect((await finance.balance()).balance, 979.9);

    final page = await finance.transactionPage((
      search: 'almuerzo',
      type: null,
      from: null,
      to: null,
    ));
    expect(page.items.single.title, 'Almuerzo editado');
    expect(page.summary!.expense, 20.1);

    // Card debt comes from the API's totals.
    final method = (await finance.paymentMethods()).firstWhere(
      (m) => m.id == card.id,
    );
    expect(method.chargedTotal, 20.1);

    final monthStart = DateTime(now.year, now.month);
    await finance.setBudget(food.id, 15);
    final budget = (await finance.budgets(monthStart)).single;
    expect(budget.amount, 15);
    expect(budget.spent, 20.1, reason: 'exceeded');
    await finance.deleteBudget(food.id);
    expect(await finance.budgets(monthStart), isEmpty);

    await finance.deleteTransaction(lunch.id);
    balance = await finance.balance();
    expect(balance.balance, 1000);
  });

  test('own categories: create, edit, delete', () async {
    final created = await finance.createCategory(
      name: 'Café prueba',
      icon: 'local_cafe',
      type: TransactionType.expense,
    );
    final edited = await finance.updateCategory(
      created.id,
      name: 'Café editado',
      icon: 'local_cafe',
      type: TransactionType.expense,
    );
    expect(edited.name, 'Café editado');
    await finance.deleteCategory(created.id);
    expect(
      (await finance.categories()).map((c) => c.id),
      isNot(contains(created.id)),
    );
  });

  test('another account sees none of it', () async {
    final client = newAuthClient();
    final (_, otherAuth, otherFinance) = appWith(SupabaseAuthGateway(client));
    await otherAuth.register(name: 'Otra', email: stranger, password: password);
    expect(await otherFinance.transactions(), isEmpty);
    expect(await otherFinance.paymentMethods(), isEmpty);
    expect((await otherFinance.balance()).balance, 0);
    await otherAuth.deleteAccount(password);
  });

  test('password change, then account deletion', () async {
    await expectLater(
      auth.changePassword(current: 'incorrecta', next: newPassword),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
    await auth.changePassword(current: password, next: newPassword);
    currentPassword = newPassword;
    await auth.logout();
    await auth.login(email: email, password: newPassword);

    await expectLater(
      auth.deleteAccount('incorrecta'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
    await auth.deleteAccount(newPassword);
    expect(api.token, isNull);
    await expectLater(
      auth.login(email: email, password: newPassword),
      throwsA(isA<ApiException>()),
    );
  });
}
