/// Configuration management for the Flutter app.
/// 
/// Environment-specific backend URLs and settings.
/// Update [Config.baseUrl] for your backend location.

class Config {
  /// Backend API base URL
  /// 
  /// For local development:
  /// - Android emulator: http://10.0.2.2:8000
  /// - iOS simulator: http://localhost:8000
  /// - Web: http://localhost:8000
  /// - Physical device: http://<your-machine-ip>:8000
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// API endpoint path prefix
  static const String apiPrefix = '/api/v1';

  /// Full API URL
  static String get apiUrl => '$baseUrl$apiPrefix';

  /// App name
  static const String appName = 'Położne – Midwife Tools';

  /// App version
  static const String appVersion = '0.1.0';
}
