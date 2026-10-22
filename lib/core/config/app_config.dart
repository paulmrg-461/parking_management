class AppConfig {
  const AppConfig({
    required this.appName,
    required this.apiBaseUrl,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
  });

  final String appName;
  final String apiBaseUrl;

  /// Self-hosted Supabase API gateway (e.g. `http://10.0.2.2:8001` on the
  /// Android emulator). Empty = keep the transitional FastAPI PIN login.
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get supabaseAuthEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const String _defaultApiBaseUrl = 'http://localhost:8000';

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      appName: String.fromEnvironment(
        'APP_NAME',
        defaultValue: 'Parking Management',
      ),
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: _defaultApiBaseUrl,
      ),
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }
}
