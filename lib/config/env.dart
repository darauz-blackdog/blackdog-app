/// App environment configuration.
/// All values must come from dart-define or --dart-define-from-file=.env
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Google OAuth — Web Client ID (also used as serverClientId for mobile)
  /// TODO: Replace with your Google Cloud Console Web Client ID
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Google OAuth — iOS Client ID
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// Sentry DSN — empty disables crash reporting.
  static const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// Build mode label sent to Sentry.
  static const sentryEnvironment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: 'production',
  );

  /// SHA-256 SPKI pins for Dio (api.blackdogpanama.com), comma-separated.
  /// Empty disables pinning. ALWAYS supply at least 2 pins (current + backup)
  /// to avoid bricking the app when the certificate rotates.
  ///
  /// Obtain with:
  ///   echo | openssl s_client -servername api.blackdogpanama.com \
  ///     -connect api.blackdogpanama.com:443 2>/dev/null | \
  ///     openssl x509 -pubkey -noout | \
  ///     openssl pkey -pubin -outform der | \
  ///     openssl dgst -sha256 -binary | base64
  static const apiCertPins = String.fromEnvironment(
    'API_CERT_PINS',
    defaultValue: '',
  );

  /// Asserts that required env vars are configured. Call before app init.
  static void assertConfigured() {
    assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL must be set via --dart-define');
    assert(supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY must be set via --dart-define');
    assert(apiBaseUrl.isNotEmpty, 'API_BASE_URL must be set via --dart-define');
    assert(googleWebClientId.isNotEmpty, 'GOOGLE_WEB_CLIENT_ID must be set via --dart-define');
  }
}
