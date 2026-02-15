/// App environment configuration.
/// In production, these should come from dart-define or a .env file.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nhuixqohuoqjaijgthpf.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5odWl4cW9odW9xamFpamd0aHBmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNzYzNTgsImV4cCI6MjA4Njc1MjM1OH0.hmUBC2jLyr5-r418X0vfHsxa7VVdQOBrKFb-gyp0OoA',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3002/api', // Android emulator → localhost
  );
}
