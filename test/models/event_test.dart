import 'package:flutter_test/flutter_test.dart';
import 'package:birth_journal_midwife/models/event.dart';

void main() {
  group('Event Model', () {
    test('fromJson creates Event from valid JSON', () {
      final json = {
        'event_id': '123e4567-e89b-12d3-a456-426614174000',
        'case_id': 'case-123',
        'type': 'contraction_start',
        'ts': '2025-12-31T10:00:00.000Z',
        'server_ts': '2025-12-31T10:00:01.000Z',
        'track': 'labor',
        'source': 'woman',
        'payload_v': 1,
        'payload': {'local_seq': 1},
      };

      final event = Event.fromJson(json);

      expect(event.eventId, '123e4567-e89b-12d3-a456-426614174000');
      expect(event.caseId, 'case-123');
      expect(event.type, 'contraction_start');
      expect(event.track, 'labor');
      expect(event.source, 'woman');
      expect(event.payloadVersion, 1);
      expect(event.payload['local_seq'], 1);
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{
        'event_id': 'event-123',
        'case_id': 'case-123',
        'type': 'note',
        'ts': '2025-12-31T10:00:00.000Z',
        'payload': <String, dynamic>{},
      };

      final event = Event.fromJson(json);

      expect(event.eventId, 'event-123');
      expect(event.serverTs, isNull);
      expect(event.track, isNull);
      expect(event.source, isNull);
      expect(event.payloadVersion, 1); // default value
    });

    test('toJson converts Event to JSON', () {
      final event = Event(
        eventId: 'test-event',
        caseId: 'test-case',
        type: 'labor_event',
        ts: DateTime.utc(2025, 12, 31, 10, 0, 0),
        track: 'labor',
        source: 'woman',
        payloadVersion: 1,
        payload: {'kind': 'bleeding', 'severity': 'high'},
      );

      final json = event.toJson();

      expect(json['event_id'], 'test-event');
      expect(json['case_id'], 'test-case');
      expect(json['type'], 'labor_event');
      expect(json['track'], 'labor');
      expect(json['source'], 'woman');
      expect(json['payload_v'], 1);
      expect(json['payload']['kind'], 'bleeding');
      expect(json['payload']['severity'], 'high');
    });

    test('Event constructor with defaults', () {
      final event = Event(
        eventId: 'test',
        caseId: 'case',
        type: 'note',
        ts: DateTime.now(),
      );

      expect(event.payloadVersion, 1);
      expect(event.payload, const {});
      expect(event.serverTs, isNull);
      expect(event.track, isNull);
      expect(event.source, isNull);
    });

    test('Event parses ISO 8601 timestamp correctly', () {
      final json = <String, dynamic>{
        'event_id': 'event-123',
        'case_id': 'case-123',
        'type': 'test',
        'ts': '2025-06-15T14:30:45.123Z',
        'payload': <String, dynamic>{},
      };

      final event = Event.fromJson(json);

      expect(event.ts.year, 2025);
      expect(event.ts.month, 6);
      expect(event.ts.day, 15);
      expect(event.ts.hour, 14);
      expect(event.ts.minute, 30);
    });
  });
}
