class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.patternhunt.co/api/v1',
  );
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'com.patternhunt://login-callback',
  );

  /// Avoid apex → www redirects; HTTP clients drop Authorization on cross-host redirects.
  static String get normalizedApiBaseUrl {
    final trimmed = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return trimmed.replaceFirst('://patternhunt.co', '://www.patternhunt.co');
  }

  static String get siteUrl => normalizedApiBaseUrl.replaceAll(RegExp(r'/api/v1$'), '');

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY. '
        'Run with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
  }
}
