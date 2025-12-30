import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  @JsonKey(name: 'event_id')
  final String eventId;

  @JsonKey(name: 'case_id')
  final String caseId;

  final String type;
  final DateTime ts;

  @JsonKey(name: 'server_ts')
  final DateTime? serverTs;

  final String? track;
  final String? source;

  @JsonKey(name: 'payload_v', defaultValue: 1)
  final int payloadVersion;

  final Map<String, dynamic> payload;

  Event({
    required this.eventId,
    required this.caseId,
    required this.type,
    required this.ts,
    this.serverTs,
    this.track,
    this.source,
    this.payloadVersion = 1,
    this.payload = const {},
  });

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);
}
