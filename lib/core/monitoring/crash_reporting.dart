import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry project DSN, given at build time:
/// `flutter build appbundle --dart-define=SENTRY_DSN=https://…`.
/// Empty (tests, local runs, forks) turns crash reporting off.
const sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Starts Sentry (crashes and uncaught errors) around [runApp], or just runs
/// the app when no DSN was given. Every event and breadcrumb goes through
/// [scrubEvent] / [scrubBreadcrumb] first.
Future<void> runWithCrashReporting(Future<void> Function() runApp) async {
  if (sentryDsn.isEmpty) {
    await runApp();
    return;
  }
  await SentryFlutter.init((options) {
    options
      ..dsn = sentryDsn
      ..environment = kReleaseMode ? 'production' : 'development'
      // No IP address, user or request details attached by the SDK.
      ..sendDefaultPii = false
      // Screens show balances and movements (view hierarchy is off by default).
      ..attachScreenshot = false
      // Errors only, no performance tracing.
      ..tracesSampleRate = 0;
    options.beforeSend = (event, hint) => scrubEvent(event);
    options.beforeBreadcrumb = (breadcrumb, hint) =>
        scrubBreadcrumb(breadcrumb);
  }, appRunner: runApp);
}

final _patterns = <(RegExp, String)>[
  // JWTs: Supabase access tokens, any other signed token.
  (RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*'), '[token]'),
  (RegExp(r'Bearer\s+\S+', caseSensitive: false), 'Bearer [token]'),
  // Supabase keys and refresh tokens.
  (RegExp(r'sb_(secret|publishable)_[A-Za-z0-9_-]+'), '[key]'),
  (
    RegExp(
      r'(refresh_token|access_token|password|passwd|apikey)["=:\s]+[^\s&",}]+',
      caseSensitive: false,
    ),
    r'$1=[redacted]',
  ),
  // Connection strings with credentials.
  (RegExp(r'postgres(ql)?://\S+', caseSensitive: false), '[connection]'),
  (RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), '[email]'),
  // Amounts of money ($12.50, 1,200.00).
  (RegExp(r'\$\s?-?\d[\d.,]*'), r'$[amount]'),
];

/// [text] without tokens, keys, passwords, connection strings, emails or
/// amounts of money.
String scrubText(String text) {
  var result = text;
  for (final (pattern, replacement) in _patterns) {
    result = result.replaceAllMapped(
      pattern,
      (m) => replacement.replaceAllMapped(
        RegExp(r'\$(\d)'),
        (g) => m.group(int.parse(g.group(1)!)) ?? '',
      ),
    );
  }
  return result;
}

/// Only what's needed to fix the error: no request (headers, cookies,
/// body), no user, no extra data or device name, and scrubbed texts.
SentryEvent scrubEvent(SentryEvent event) => SentryEvent(
  eventId: event.eventId,
  timestamp: event.timestamp,
  platform: event.platform,
  logger: event.logger,
  release: event.release,
  dist: event.dist,
  environment: event.environment,
  modules: event.modules,
  message: switch (event.message) {
    final message? => SentryMessage(scrubText(message.formatted)),
    null => null,
  },
  transaction: event.transaction == null
      ? null
      : _scrubPath(event.transaction!),
  throwable: event.throwable,
  level: event.level,
  culprit: event.culprit,
  tags: event.tags,
  fingerprint: event.fingerprint,
  contexts: event.contexts,
  breadcrumbs: event.breadcrumbs
      ?.map(scrubBreadcrumb)
      .whereType<Breadcrumb>()
      .toList(),
  sdk: event.sdk,
  debugMeta: event.debugMeta,
  exceptions: event.exceptions
      ?.map(
        (e) => e.copyWith(value: e.value == null ? null : scrubText(e.value!)),
      )
      .toList(),
  threads: event.threads,
  type: event.type,
);

/// Navigation and UI steps stay; HTTP ones keep only method, status and
/// path (no query: it carries searches and dates); nothing else of `data`.
Breadcrumb? scrubBreadcrumb(Breadcrumb? breadcrumb) {
  if (breadcrumb == null) return null;
  final data = breadcrumb.data;
  Map<String, dynamic>? safe;
  if (breadcrumb.type == 'http' && data != null) {
    safe = {
      if (data['method'] != null) 'method': data['method'],
      if (data['status_code'] != null) 'status_code': data['status_code'],
      if (data['url'] case final String url) 'url': _scrubPath(url),
    };
  } else if (breadcrumb.category == 'navigation' && data != null) {
    safe = {
      for (final key in const ['from', 'to', 'state'])
        if (data[key] case final String value) key: _scrubPath(value),
    };
  }
  return Breadcrumb(
    message: breadcrumb.message == null ? null : scrubText(breadcrumb.message!),
    category: breadcrumb.category,
    data: safe,
    level: breadcrumb.level,
    type: breadcrumb.type,
    timestamp: breadcrumb.timestamp,
  );
}

String _scrubPath(String url) => scrubText(url.split('?').first);
