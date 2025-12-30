// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'case.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Case _$CaseFromJson(Map<String, dynamic> json) => Case(
  caseId: json['case_id'] as String,
  label: json['label'] as String?,
  laborActive: json['labor_active'] as bool? ?? false,
  postpartumActive: json['postpartum_active'] as bool? ?? false,
  lastEventTs: json['last_event_ts'] == null
      ? null
      : DateTime.parse(json['last_event_ts'] as String),
  activeAlerts: (json['active_alerts'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CaseToJson(Case instance) => <String, dynamic>{
  'case_id': instance.caseId,
  'label': instance.label,
  'labor_active': instance.laborActive,
  'postpartum_active': instance.postpartumActive,
  'last_event_ts': instance.lastEventTs?.toIso8601String(),
  'active_alerts': instance.activeAlerts,
};
