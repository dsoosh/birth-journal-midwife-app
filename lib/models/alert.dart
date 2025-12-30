import 'event.dart';

enum AlertSeverity { info, warning, urgent }

enum AlertCode { milestone511, milestone311, regression, abnormalGap, heavyBleeding }

class Alert {
  final Event event;
  final String alertCode;
  final String severity;
  final AlertExplain explain;

  Alert({
    required this.event,
    required this.alertCode,
    required this.severity,
    required this.explain,
  });

  bool get isActive => event.type == 'alert_triggered';
}

class AlertExplain {
  final String ruleVersion;
  final int windowMinutes;
  final String summary;

  AlertExplain({
    required this.ruleVersion,
    required this.windowMinutes,
    required this.summary,
  });

  factory AlertExplain.fromJson(Map<String, dynamic> json) {
    return AlertExplain(
      ruleVersion: json['rule_version'] ?? '',
      windowMinutes: json['window_minutes'] is int
          ? json['window_minutes'] as int
          : int.tryParse(json['window_minutes']?.toString() ?? '') ?? 0,
      summary: json['summary'] ?? '',
    );
  }
}
