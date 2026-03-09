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

  /// Asserts that required env vars are configured. Call before app init.
  static void assertConfigured() {
    assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL must be set via --dart-define');
    assert(supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY must be set via --dart-define');
    assert(apiBaseUrl.isNotEmpty, 'API_BASE_URL must be set via --dart-define');
  }
}
