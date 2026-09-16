class AppConfig {
  const AppConfig({
    required this.appName,
    required this.apiBaseUrl,
  });

  final String appName;
  final String apiBaseUrl;

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
    );
  }
}
