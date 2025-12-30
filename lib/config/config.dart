/// Configuration management for the Flutter app.
/// 
/// Environment-specific backend URLs and settings.
/// Pass API_BASE_URL via --dart-define for your backend location.

class Config {
  /// Backend API base URL
  /// 
  /// For local development:
  /// - Android emulator: http://10.0.2.2:8000
  /// - iOS simulator: http://localhost:8000
  /// - Web: http://localhost:8000
  /// - Physical device: http://<your-machine-ip>:8000
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  /// Full API URL (already includes /api/v1 prefix)
  static String get apiUrl => _apiBaseUrl;

  /// App name
  static const String appName = 'Położne – Midwife Tools';

  /// App version
  static const String appVersion = '0.1.0';
}
