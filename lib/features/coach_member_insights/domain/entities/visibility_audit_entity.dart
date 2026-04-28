/// Immutable record of a consent change, displayed in the member's
/// privacy audit timeline.
class VisibilityAuditEntity {
  const VisibilityAuditEntity({
    required this.id,
    required this.changeType,
    required this.oldValue,
    required this.newValue,
    required this.createdAt,
  });

  final String id;

  /// One of 'initial_grant', 'updated', or 'revoked_all'.
  final String changeType;
  final Map<String, dynamic> oldValue;
  final Map<String, dynamic> newValue;
  final DateTime createdAt;

  String get changeLabel {
    switch (changeType) {
      case 'initial_grant':
        return 'Granted access';
      case 'revoked_all':
        return 'Revoked all access';
      default:
        return 'Updated settings';
    }
  }

  factory VisibilityAuditEntity.fromJson(Map<String, dynamic> json) =>
      VisibilityAuditEntity(
        id: json['id'] as String,
        changeType: json['change_type'] as String? ?? 'updated',
        oldValue: (json['old_value_json'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
        newValue: (json['new_value_json'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
