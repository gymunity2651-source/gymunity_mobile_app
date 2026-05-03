class CoachTaiyoClientBriefEntity {
  const CoachTaiyoClientBriefEntity({
    required this.requestType,
    required this.status,
    required this.clientStatus,
    required this.summary,
    this.redFlags = const <String>[],
    this.suggestedAction = '',
    this.suggestedMessage = '',
    this.privacyNotes = const <String>[],
    this.riskLevel = 'low',
    this.missingFields = const <String>[],
    this.confidence = 'low',
    this.generatedAt,
  });

  final String requestType;
  final String status;
  final String clientStatus;
  final String summary;
  final List<String> redFlags;
  final String suggestedAction;
  final String suggestedMessage;
  final List<String> privacyNotes;
  final String riskLevel;
  final List<String> missingFields;
  final String confidence;
  final DateTime? generatedAt;

  bool get needsVisibilityPermission => status == 'needs_visibility_permission';
  bool get hasDraftMessage => suggestedMessage.trim().isNotEmpty;

  factory CoachTaiyoClientBriefEntity.fromMap(Map<String, dynamic> map) {
    final result = _map(map['result']);
    final dataQuality = _map(map['data_quality']);
    final metadata = _map(map['metadata']);
    return CoachTaiyoClientBriefEntity(
      requestType: _string(map['request_type'], fallback: 'coach_client_brief'),
      status: _string(map['status'], fallback: 'error'),
      clientStatus: _string(result['client_status'], fallback: 'watch'),
      summary: _string(result['summary']),
      redFlags: _strings(result['red_flags']),
      suggestedAction: _string(result['suggested_action']),
      suggestedMessage: _string(result['suggested_message']),
      privacyNotes: _strings(result['privacy_notes']),
      riskLevel: _string(result['risk_level'], fallback: 'low'),
      missingFields: _strings(dataQuality['missing_fields']),
      confidence: _string(dataQuality['confidence'], fallback: 'low'),
      generatedAt: _date(metadata['generated_at']),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<String> _strings(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _string(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
