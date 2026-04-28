import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<AdminUserEntity?> getCurrentAdmin() async {
    try {
      final response = await _client.rpc('current_admin');
      final map = _nullableMap(response);
      return map == null ? null : AdminUserEntity.fromMap(map);
    } on PostgrestException catch (error, stackTrace) {
      throw _failure(error, stackTrace);
    }
  }

  @override
  Future<AdminDashboardSummaryEntity> getDashboardSummary() async {
    final map = await _rpcMap('admin_dashboard_summary');
    return AdminDashboardSummaryEntity.fromMap(map);
  }

  @override
  Future<List<AdminPaymentOrderEntity>> listPaymentOrders({
    String? status,
    String? search,
    String? payoutStatus,
  }) async {
    final rows = await _rpcRows('admin_list_payment_orders', {
      if (_hasText(status)) 'status': status!.trim(),
      if (_hasText(search)) 'search': search!.trim(),
      if (_hasText(payoutStatus)) 'payout_status': payoutStatus!.trim(),
      'limit': 100,
    });
    return rows.map(AdminPaymentOrderEntity.fromMap).toList(growable: false);
  }

  @override
  Future<AdminPaymentOrderEntity> getPaymentOrderDetails(
    String paymentOrderId,
  ) async {
    final map = await _rpcMap(
      'admin_get_payment_order_details',
      params: {'target_payment_order_id': paymentOrderId},
    );
    return AdminPaymentOrderEntity.fromMap(map);
  }

  @override
  Future<List<AdminPayoutEntity>> listPayouts({
    String? status,
    String? search,
  }) async {
    final rows = await _rpcRows('admin_list_payouts', {
      if (_hasText(status)) 'status': status!.trim(),
      if (_hasText(search)) 'search': search!.trim(),
      'limit': 100,
    });
    return rows.map(AdminPayoutEntity.fromMap).toList(growable: false);
  }

  @override
  Future<AdminPayoutEntity> getPayoutDetails(String payoutId) async {
    final map = await _rpcMap(
      'admin_get_payout_details',
      params: {'target_payout_id': payoutId},
    );
    return AdminPayoutEntity.fromMap(map);
  }

  @override
  Future<List<AdminCoachBalanceEntity>> listCoachBalances({
    String? search,
  }) async {
    final rows = await _rpcRows('admin_list_coach_balances', {
      if (_hasText(search)) 'search': search!.trim(),
      'limit': 100,
    });
    return rows.map(AdminCoachBalanceEntity.fromMap).toList(growable: false);
  }

  @override
  Future<List<AdminSubscriptionEntity>> listSubscriptions({
    String? status,
    String? search,
  }) async {
    final rows = await _rpcRows('admin_list_subscriptions', {
      if (_hasText(status)) 'status': status!.trim(),
      if (_hasText(search)) 'search': search!.trim(),
      'limit': 100,
    });
    return rows.map(AdminSubscriptionEntity.fromMap).toList(growable: false);
  }

  @override
  Future<List<AdminAuditEventEntity>> listAuditEvents({
    String? action,
    String? targetType,
  }) async {
    final rows = await _rpcRows('admin_list_audit_events', {
      if (_hasText(action)) 'action': action!.trim(),
      if (_hasText(targetType)) 'target_type': targetType!.trim(),
      'limit': 150,
    });
    return rows.map(AdminAuditEventEntity.fromMap).toList(growable: false);
  }

  @override
  Future<AdminSettingsEntity> getSettings() async {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (!_hasText(accessToken)) {
      throw const AuthFailure(message: 'Admin sign-in is required.');
    }

    try {
      final response = await _client.functions.invoke(
        'admin-payment-settings',
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return AdminSettingsEntity.fromMap(_asMap(response.data));
    } on FunctionException catch (error, stackTrace) {
      throw NetworkFailure(
        message: _functionErrorMessage(error),
        code: error.status.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> markPayoutReady(String payoutId, {String? note}) {
    return _rpcVoid('admin_mark_payout_ready', {
      'payout_id': payoutId,
      'note': note,
    });
  }

  @override
  Future<void> holdPayout(String payoutId, {required String reason}) {
    return _rpcVoid('admin_hold_payout', {
      'payout_id': payoutId,
      'reason': reason,
    });
  }

  @override
  Future<void> releasePayout(String payoutId, {String? note}) {
    return _rpcVoid('admin_release_payout', {
      'payout_id': payoutId,
      'note': note,
    });
  }

  @override
  Future<void> markPayoutProcessing(String payoutId, {String? note}) {
    return _rpcVoid('admin_mark_payout_processing', {
      'payout_id': payoutId,
      'note': note,
    });
  }

  @override
  Future<void> markPayoutPaid({
    required String payoutId,
    required String method,
    required String externalReference,
    String? adminNote,
  }) {
    return _rpcVoid('admin_mark_payout_paid', {
      'target_payout_id': payoutId,
      'input_method': method,
      'input_external_reference': externalReference,
      'input_admin_note': adminNote,
    });
  }

  @override
  Future<void> markPayoutFailed(String payoutId, {required String reason}) {
    return _rpcVoid('admin_mark_payout_failed', {
      'payout_id': payoutId,
      'reason': reason,
    });
  }

  @override
  Future<void> cancelPayout(String payoutId, {required String reason}) {
    return _rpcVoid('admin_cancel_payout', {
      'payout_id': payoutId,
      'reason': reason,
    });
  }

  @override
  Future<void> reconcilePaymentOrder(String paymentOrderId) {
    return _rpcVoid('admin_reconcile_payment_order', {
      'payment_order_id': paymentOrderId,
    });
  }

  @override
  Future<void> markPaymentNeedsReview(String paymentOrderId, String reason) {
    return _rpcVoid('admin_mark_payment_needs_review', {
      'payment_order_id': paymentOrderId,
      'reason': reason,
    });
  }

  @override
  Future<void> cancelUnpaidCheckout(String paymentOrderId, String reason) {
    return _rpcVoid('admin_cancel_unpaid_checkout', {
      'payment_order_id': paymentOrderId,
      'reason': reason,
    });
  }

  @override
  Future<void> ensureSubscriptionThread(String subscriptionId) {
    return _rpcVoid('admin_ensure_subscription_thread', {
      'subscription_id': subscriptionId,
    });
  }

  @override
  Future<void> verifyCoachPayoutAccount({
    required String coachId,
    required bool isVerified,
    String? note,
  }) {
    return _rpcVoid('admin_verify_coach_payout_account', {
      'coach_id': coachId,
      'is_verified': isVerified,
      'note': note,
    });
  }

  Future<List<Map<String, dynamic>>> _rpcRows(
    String functionName,
    Map<String, dynamic> filters,
  ) async {
    final data = await _rpc(functionName, params: {'filters': filters});
    return _asRows(data);
  }

  Future<Map<String, dynamic>> _rpcMap(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    final data = await _rpc(functionName, params: params ?? {'filters': {}});
    return _asMap(data);
  }

  Future<void> _rpcVoid(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    await _rpc(
      functionName,
      params: params..removeWhere((_, value) => value == null),
    );
  }

  Future<dynamic> _rpc(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    try {
      return await _client.rpc(functionName, params: params);
    } on PostgrestException catch (error, stackTrace) {
      throw _failure(error, stackTrace);
    }
  }

  NetworkFailure _failure(PostgrestException error, StackTrace stackTrace) {
    return NetworkFailure(
      message: error.message,
      code: error.code,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  String _functionErrorMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final message = details['error'] ?? details['message'];
      if (_hasText(message?.toString())) {
        return message.toString();
      }
    }
    final text = details?.toString().trim() ?? '';
    return text.isEmpty ? 'Admin settings are unavailable.' : text;
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  Map<String, dynamic>? _nullableMap(dynamic value) {
    final map = _asMap(value);
    return map.isEmpty ? null : map;
  }

  List<Map<String, dynamic>> _asRows(dynamic value) {
    if (value is List) {
      return value.map((item) => _asMap(item)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }
}
