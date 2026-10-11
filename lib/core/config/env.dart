/// Where the app connects. Defaults are the production environment; local
/// development overrides them with `--dart-define`, e.g.
/// `--dart-define=API_BASE_URL=http://localhost:3001`.
///
/// Only public values belong here: the Supabase publishable key is meant
/// for clients (it grants nothing the API and RLS don't allow). Secret keys
/// never go in the app.
class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://appgastos-api.onrender.com',
  );

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gxgjbcywdsiguxfblyof.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_LtFjDnmHrx61_L3s4j4yLA_4fIfh4bB',
  );
}
