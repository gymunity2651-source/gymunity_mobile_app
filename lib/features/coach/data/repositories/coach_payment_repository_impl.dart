import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../domain/entities/coach_payment_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/coach_payment_repository.dart';

class CoachPaymentRepositoryImpl implements CoachPaymentRepository {
  CoachPaymentRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<CoachPaymobCheckoutSession> createPaymobCheckout({
    required String packageId,
    String? coachId,
    CoachSubscriptionIntakeEntity intakeSnapshot =
        const CoachSubscriptionIntakeEntity(),
    String? note,
  }) async {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }

    try {
      final response = await _client.functions.invoke(
        'create-coach-paymob-checkout',
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        body:
            <String, dynamic>{
              'package_id': packageId,
              if (coachId != null && coachId.trim().isNotEmpty)
                'coach_id': coachId.trim(),
              if (note != null && note.trim().isNotEmpty)
                'note_to_coach': note.trim(),
              'primary_goal': intakeSnapshot.goal,
              'experience_level': intakeSnapshot.experienceLevel,
              'days_per_week': intakeSnapshot.daysPerWeek,
              'session_minutes': intakeSnapshot.sessionMinutes,
              'city': intakeSnapshot.city,
              'equipment': intakeSnapshot.equipment,
              'limitations': intakeSnapshot.limitations,
            }..removeWhere((_, value) {
              if (value == null) {
                return true;
              }
              return value is String && value.trim().isEmpty;
            }),
      );
      return CoachPaymobCheckoutSession.fromMap(_asMap(response.data));
    } on FunctionException catch (error, stackTrace) {
      throw NetworkFailure(
        message: _functionErrorMessage(
          error,
          fallback: 'Unable to start Paymob checkout.',
        ),
        code: error.status.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<CoachPaymentOrderEntity?> getPaymentOrder(
    String paymentOrderId,
  ) async {
    if (paymentOrderId.trim().isEmpty) {
      return null;
    }

    try {
      final response = await _client.rpc(
        'get_coach_payment_order_status',
        params: <String, dynamic>{
          'target_payment_order_id': paymentOrderId.trim(),
        },
      );
      final rows = _asRows(response);
      if (rows.isEmpty) {
        return null;
      }
      return CoachPaymentOrderEntity.fromMap(rows.first);
    } on PostgrestException catch (error, stackTrace) {
      throw NetworkFailure(
        message: error.message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asRows(dynamic value) {
    if (value is List) {
      return value.map((dynamic row) => _asMap(row)).toList(growable: false);
    }
    if (value == null) {
      return const <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[_asMap(value)];
  }

  String _functionErrorMessage(
    FunctionException error, {
    required String fallback,
  }) {
    final details = error.details;
    if (details is Map) {
      final message = details['error'] ?? details['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }
    final detailsText = details?.toString().trim() ?? '';
    return detailsText.isEmpty ? fallback : detailsText;
  }
}
