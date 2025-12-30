import 'package:json_annotation/json_annotation.dart';

part 'case.g.dart';

@JsonSerializable()
class Case {
  @JsonKey(name: 'case_id')
  final String caseId;

  /// Midwife-visible label; may be absent in minimal responses.
  final String? label;

  @JsonKey(name: 'labor_active')
  final bool laborActive;

  @JsonKey(name: 'postpartum_active')
  final bool postpartumActive;

  @JsonKey(name: 'last_event_ts')
  final DateTime? lastEventTs;

  @JsonKey(name: 'active_alerts')
  final int activeAlerts;

  Case({
    required this.caseId,
    this.label,
    this.laborActive = false,
    this.postpartumActive = false,
    this.lastEventTs,
    this.activeAlerts = 0,
  });

  factory Case.fromJson(Map<String, dynamic> json) => _$CaseFromJson(json);

  Map<String, dynamic> toJson() => _$CaseToJson(this);

  bool get isClosed => !laborActive && !postpartumActive;

  String get displayLabel => label?.isNotEmpty == true ? label! : caseId;
}
