class AppConfig {
  const AppConfig({
    required this.appName,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String appName;

  /// Self-hosted Supabase API gateway (e.g. `http://10.0.2.2:8000` on the
  /// Android emulator).
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get supabaseAuthEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      appName: String.fromEnvironment(
        'APP_NAME',
        defaultValue: 'Parking Management',
      ),
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }
}
