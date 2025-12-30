import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      print('NotificationService: Android notification permission granted: $granted');
    }

    // Request permissions for iOS
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
    print('NotificationService: Initialized successfully');
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to specific case/event
    print('Notification tapped: ${response.payload}');
  }

  Future<void> showHighSeverityAlert({
    required String caseId,
    required String symptom,
    String? patientName,
  }) async {
    print('NotificationService: Showing HIGH severity alert for $symptom (case: $caseId)');
    
    const androidDetails = AndroidNotificationDetails(
      'high_severity_alerts',
      'High Severity Alerts',
      channelDescription: 'Notifications for high severity patient symptoms',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = patientName != null 
        ? '⚠️ $patientName - High Priority'
        : '⚠️ High Priority Alert';
    
    final body = 'Reported: $symptom';

    print('NotificationService: Notification title: $title, body: $body');
    
    await _notifications.show(
      caseId.hashCode, // Use case ID hash as notification ID
      title,
      body,
      details,
      payload: caseId,
    );
    
    print('NotificationService: Notification shown successfully');
  }

  Future<void> showMediumSeverityAlert({
    required String caseId,
    required String symptom,
    String? patientName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'medium_severity_alerts',
      'Medium Severity Alerts',
      channelDescription: 'Notifications for medium severity patient symptoms',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = patientName != null 
        ? 'ℹ️ $patientName'
        : 'ℹ️ Patient Alert';
    
    final body = 'Reported: $symptom';

    await _notifications.show(
      caseId.hashCode,
      title,
      body,
      details,
      payload: caseId,
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
