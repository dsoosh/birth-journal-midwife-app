// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
  eventId: json['event_id'] as String,
  caseId: json['case_id'] as String,
  type: json['type'] as String,
  ts: DateTime.parse(json['ts'] as String),
  serverTs: json['server_ts'] == null
      ? null
      : DateTime.parse(json['server_ts'] as String),
  track: json['track'] as String?,
  source: json['source'] as String?,
  payloadVersion: (json['payload_v'] as num?)?.toInt() ?? 1,
  payload: json['payload'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$EventToJson(Event instance) => <String, dynamic>{
  'event_id': instance.eventId,
  'case_id': instance.caseId,
  'type': instance.type,
  'ts': instance.ts.toIso8601String(),
  'server_ts': instance.serverTs?.toIso8601String(),
  'track': instance.track,
  'source': instance.source,
  'payload_v': instance.payloadVersion,
  'payload': instance.payload,
};
