import 'package:flutter_test/flutter_test.dart';
import 'package:birth_journal_midwife/models/case.dart';

void main() {
  group('Case Model', () {
    test('fromJson creates Case from valid JSON', () {
      final json = {
        'case_id': '123e4567-e89b-12d3-a456-426614174000',
        'label': 'Test Patient',
        'labor_active': true,
        'postpartum_active': false,
        'last_event_ts': '2025-12-31T10:00:00Z',
        'active_alerts': 2,
      };

      final case_ = Case.fromJson(json);

      expect(case_.caseId, '123e4567-e89b-12d3-a456-426614174000');
      expect(case_.label, 'Test Patient');
      expect(case_.laborActive, true);
      expect(case_.postpartumActive, false);
      expect(case_.activeAlerts, 2);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'case_id': '123e4567-e89b-12d3-a456-426614174000',
        'labor_active': false,
        'postpartum_active': false,
      };

      final case_ = Case.fromJson(json);

      expect(case_.caseId, '123e4567-e89b-12d3-a456-426614174000');
      expect(case_.label, isNull);
      expect(case_.lastEventTs, isNull);
      expect(case_.activeAlerts, 0);
    });

    test('toJson converts Case to JSON', () {
      final case_ = Case(
        caseId: 'test-case-id',
        label: 'Test',
        laborActive: true,
        postpartumActive: false,
        activeAlerts: 1,
      );

      final json = case_.toJson();

      expect(json['case_id'], 'test-case-id');
      expect(json['label'], 'Test');
      expect(json['labor_active'], true);
      expect(json['postpartum_active'], false);
      expect(json['active_alerts'], 1);
    });

    test('isClosed returns true when both modes are false', () {
      final case_ = Case(
        caseId: 'test',
        laborActive: false,
        postpartumActive: false,
      );

      expect(case_.isClosed, true);
    });

    test('isClosed returns false when labor is active', () {
      final case_ = Case(
        caseId: 'test',
        laborActive: true,
        postpartumActive: false,
      );

      expect(case_.isClosed, false);
    });

    test('isClosed returns false when postpartum is active', () {
      final case_ = Case(
        caseId: 'test',
        laborActive: false,
        postpartumActive: true,
      );

      expect(case_.isClosed, false);
    });

    test('displayLabel returns label when present', () {
      final case_ = Case(
        caseId: 'test-id',
        label: 'Patient Name',
        laborActive: false,
        postpartumActive: false,
      );

      expect(case_.displayLabel, 'Patient Name');
    });

    test('displayLabel returns caseId when label is null', () {
      final case_ = Case(
        caseId: 'test-id',
        label: null,
        laborActive: false,
        postpartumActive: false,
      );

      expect(case_.displayLabel, 'test-id');
    });

    test('displayLabel returns caseId when label is empty', () {
      final case_ = Case(
        caseId: 'test-id',
        label: '',
        laborActive: false,
        postpartumActive: false,
      );

      expect(case_.displayLabel, 'test-id');
    });
  });
}
