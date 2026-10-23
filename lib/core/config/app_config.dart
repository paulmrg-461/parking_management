class AppConfig {
  const AppConfig({
    required this.appName,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.fcmEnabled = false,
    this.firebaseApiKey = '',
    this.firebaseAppId = '',
    this.firebaseMessagingSenderId = '',
    this.firebaseProjectId = '',
    this.firebaseStorageBucket = '',
    this.fcmVapidKey = '',
  });

  final String appName;

  /// Self-hosted Supabase API gateway (e.g. `http://10.0.2.2:8000` on the
  /// Android emulator).
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Background push is opt-in: it needs a Firebase project and explicit
  /// dart-defines. In-app notifications work without it.
  final bool fcmEnabled;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseMessagingSenderId;
  final String firebaseProjectId;
  final String firebaseStorageBucket;
  final String fcmVapidKey;

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
      fcmEnabled: bool.fromEnvironment('FCM_ENABLED'),
      firebaseApiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      firebaseAppId: String.fromEnvironment('FIREBASE_APP_ID'),
      firebaseMessagingSenderId: String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
      ),
      firebaseProjectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      firebaseStorageBucket: String.fromEnvironment(
        'FIREBASE_STORAGE_BUCKET',
      ),
      fcmVapidKey: String.fromEnvironment('FCM_VAPID_KEY'),
    );
  }
}
