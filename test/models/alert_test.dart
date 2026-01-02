import 'package:flutter_test/flutter_test.dart';
import 'package:birth_journal_midwife/models/alert.dart';
import 'package:birth_journal_midwife/models/event.dart';

void main() {
  group('AlertExplain', () {
    test('fromJson creates AlertExplain from valid JSON', () {
      final json = {
        'rule_version': 'ruleset-0.1',
        'window_minutes': 60,
        'summary': 'Test summary',
      };

      final explain = AlertExplain.fromJson(json);

      expect(explain.ruleVersion, 'ruleset-0.1');
      expect(explain.windowMinutes, 60);
      expect(explain.summary, 'Test summary');
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final explain = AlertExplain.fromJson(json);

      expect(explain.ruleVersion, '');
      expect(explain.windowMinutes, 0);
      expect(explain.summary, '');
    });

    test('fromJson handles string window_minutes', () {
      final json = {
        'rule_version': 'v1',
        'window_minutes': '30',
        'summary': 'Test',
      };

      final explain = AlertExplain.fromJson(json);

      expect(explain.windowMinutes, 30);
    });
  });

  group('Alert', () {
    test('creates Alert with required fields', () {
      final event = Event(
        eventId: 'alert-123',
        caseId: 'case-456',
        type: 'alert_triggered',
        ts: DateTime.utc(2025, 12, 31, 10, 0, 0),
        payload: {
          'alert_code': 'MILESTONE_511',
          'severity': 'warning',
        },
      );

      final alert = Alert(
        event: event,
        alertCode: 'MILESTONE_511',
        severity: 'warning',
        explain: AlertExplain(
          ruleVersion: 'v1',
          windowMinutes: 60,
          summary: 'Test alert',
        ),
      );

      expect(alert.event.eventId, 'alert-123');
      expect(alert.alertCode, 'MILESTONE_511');
      expect(alert.severity, 'warning');
      expect(alert.explain.summary, 'Test alert');
    });

    test('isActive returns true for alert_triggered events', () {
      final event = Event(
        eventId: 'alert-123',
        caseId: 'case-456',
        type: 'alert_triggered',
        ts: DateTime.now(),
      );

      final alert = Alert(
        event: event,
        alertCode: 'TEST',
        severity: 'info',
        explain: AlertExplain(
          ruleVersion: 'v1',
          windowMinutes: 0,
          summary: '',
        ),
      );

      expect(alert.isActive, true);
    });

    test('isActive returns false for non-alert_triggered events', () {
      final event = Event(
        eventId: 'ack-123',
        caseId: 'case-456',
        type: 'alert_ack',
        ts: DateTime.now(),
      );

      final alert = Alert(
        event: event,
        alertCode: 'TEST',
        severity: 'info',
        explain: AlertExplain(
          ruleVersion: 'v1',
          windowMinutes: 0,
          summary: '',
        ),
      );

      expect(alert.isActive, false);
    });
  });

  group('AlertSeverity enum', () {
    test('contains expected values', () {
      expect(AlertSeverity.values, contains(AlertSeverity.info));
      expect(AlertSeverity.values, contains(AlertSeverity.warning));
      expect(AlertSeverity.values, contains(AlertSeverity.urgent));
    });
  });

  group('AlertCode enum', () {
    test('contains expected values', () {
      expect(AlertCode.values, contains(AlertCode.milestone511));
      expect(AlertCode.values, contains(AlertCode.milestone311));
      expect(AlertCode.values, contains(AlertCode.regression));
      expect(AlertCode.values, contains(AlertCode.abnormalGap));
      expect(AlertCode.values, contains(AlertCode.heavyBleeding));
    });
  });
}
