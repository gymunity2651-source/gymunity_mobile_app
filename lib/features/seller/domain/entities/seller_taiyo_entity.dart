class SellerTaiyoCopilotEntity {
  const SellerTaiyoCopilotEntity({
    required this.requestType,
    required this.status,
    required this.summary,
    this.priorityActions = const <String>[],
    this.productOpportunities = const <String>[],
    this.orderNotes = const <String>[],
    this.riskLevel = 'low',
    this.recommendedNextStep = '',
    this.missingFields = const <String>[],
    this.confidence = 'low',
    this.generatedAt,
  });

  final String requestType;
  final String status;
  final String summary;
  final List<String> priorityActions;
  final List<String> productOpportunities;
  final List<String> orderNotes;
  final String riskLevel;
  final String recommendedNextStep;
  final List<String> missingFields;
  final String confidence;
  final DateTime? generatedAt;

  bool get isSuccessful => status == 'success';

  factory SellerTaiyoCopilotEntity.fromMap(Map<String, dynamic> map) {
    final result = _map(map['result']);
    final dataQuality = _map(map['data_quality']);
    final metadata = _map(map['metadata']);
    return SellerTaiyoCopilotEntity(
      requestType: _string(
        map['request_type'],
        fallback: 'seller_dashboard_brief',
      ),
      status: _string(map['status'], fallback: 'error'),
      summary: _string(result['summary']),
      priorityActions: _strings(result['priority_actions']),
      productOpportunities: _strings(result['product_opportunities']),
      orderNotes: _strings(result['order_notes']),
      riskLevel: _string(result['risk_level'], fallback: 'low'),
      recommendedNextStep: _string(result['recommended_next_step']),
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
