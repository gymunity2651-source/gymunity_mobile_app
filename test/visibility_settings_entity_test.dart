import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/coach_member_insights/domain/entities/visibility_settings_entity.dart';
import 'package:my_app/features/coach_member_insights/domain/entities/visibility_audit_entity.dart';

void main() {
  group('VisibilitySettingsEntity', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'id': 'vis-1',
        'member_id': 'member-1',
        'coach_id': 'coach-1',
        'subscription_id': 'sub-1',
        'share_ai_plan_summary': true,
        'share_workout_adherence': true,
        'share_progress_metrics': false,
        'share_nutrition_summary': true,
        'share_product_recommendations': false,
        'share_relevant_purchases': false,
        'created_at': '2026-04-10T10:00:00.000Z',
        'updated_at': '2026-04-15T14:30:00.000Z',
      };

      final entity = VisibilitySettingsEntity.fromJson(json);

      expect(entity.id, 'vis-1');
      expect(entity.memberId, 'member-1');
      expect(entity.coachId, 'coach-1');
      expect(entity.subscriptionId, 'sub-1');
      expect(entity.shareAiPlanSummary, true);
      expect(entity.shareWorkoutAdherence, true);
      expect(entity.shareProgressMetrics, false);
      expect(entity.shareNutritionSummary, true);
      expect(entity.shareProductRecommendations, false);
      expect(entity.shareRelevantPurchases, false);
      expect(entity.createdAt, isNotNull);
      expect(entity.updatedAt, isNotNull);
    });

    test('fromJson defaults all booleans to false when missing', () {
      final json = <String, dynamic>{
        'id': 'vis-2',
        'member_id': 'member-2',
        'coach_id': 'coach-2',
        'subscription_id': 'sub-2',
      };

      final entity = VisibilitySettingsEntity.fromJson(json);

      expect(entity.shareAiPlanSummary, false);
      expect(entity.shareWorkoutAdherence, false);
      expect(entity.shareProgressMetrics, false);
      expect(entity.shareNutritionSummary, false);
      expect(entity.shareProductRecommendations, false);
      expect(entity.shareRelevantPurchases, false);
    });

    test('hasAnySharing returns true when at least one toggle on', () {
      const entity = VisibilitySettingsEntity(
        id: 'vis-1',
        memberId: 'member-1',
        coachId: 'coach-1',
        subscriptionId: 'sub-1',
        shareProgressMetrics: true,
      );

      expect(entity.hasAnySharing, true);
    });

    test('hasAnySharing returns false when all toggles off', () {
      const entity = VisibilitySettingsEntity(
        id: 'vis-1',
        memberId: 'member-1',
        coachId: 'coach-1',
        subscriptionId: 'sub-1',
      );

      expect(entity.hasAnySharing, false);
    });

    test('copyWith creates modified copy', () {
      const original = VisibilitySettingsEntity(
        id: 'vis-1',
        memberId: 'member-1',
        coachId: 'coach-1',
        subscriptionId: 'sub-1',
        shareAiPlanSummary: false,
        shareWorkoutAdherence: false,
      );

      final updated = original.copyWith(
        shareAiPlanSummary: true,
        shareWorkoutAdherence: true,
      );

      expect(updated.id, 'vis-1');
      expect(updated.memberId, 'member-1');
      expect(updated.shareAiPlanSummary, true);
      expect(updated.shareWorkoutAdherence, true);
      expect(updated.shareProgressMetrics, false);
    });

    test('toRpcParams returns correct parameter map', () {
      const entity = VisibilitySettingsEntity(
        id: 'vis-1',
        memberId: 'member-1',
        coachId: 'coach-1',
        subscriptionId: 'sub-1',
        shareAiPlanSummary: true,
        shareWorkoutAdherence: false,
        shareProgressMetrics: true,
        shareNutritionSummary: false,
        shareProductRecommendations: true,
        shareRelevantPurchases: false,
      );

      final params = entity.toRpcParams();

      expect(params['input_share_ai_plan_summary'], true);
      expect(params['input_share_workout_adherence'], false);
      expect(params['input_share_progress_metrics'], true);
      expect(params['input_share_nutrition_summary'], false);
      expect(params['input_share_product_recommendations'], true);
      expect(params['input_share_relevant_purchases'], false);
      expect(params.length, 6);
    });

    test('defaultFor creates all-off settings', () {
      final entity = VisibilitySettingsEntity.defaultFor(
        memberId: 'member-1',
        coachId: 'coach-1',
        subscriptionId: 'sub-1',
      );

      expect(entity.id, '');
      expect(entity.hasAnySharing, false);
      expect(entity.memberId, 'member-1');
    });
  });

  group('VisibilityAuditEntity', () {
    test('fromJson parses correctly', () {
      final json = <String, dynamic>{
        'id': 'audit-1',
        'change_type': 'initial_grant',
        'old_value_json': <String, dynamic>{},
        'new_value_json': <String, dynamic>{
          'share_ai_plan_summary': true,
        },
        'created_at': '2026-04-10T10:00:00.000Z',
      };

      final entity = VisibilityAuditEntity.fromJson(json);

      expect(entity.id, 'audit-1');
      expect(entity.changeType, 'initial_grant');
      expect(entity.oldValue, isEmpty);
      expect(entity.newValue['share_ai_plan_summary'], true);
      expect(entity.changeLabel, 'Granted access');
    });

    test('changeLabel returns correct labels for each type', () {
      expect(
        VisibilityAuditEntity(
          id: '1',
          changeType: 'initial_grant',
          oldValue: const {},
          newValue: const {},
          createdAt: DateTime.now(),
        ).changeLabel,
        'Granted access',
      );
      expect(
        VisibilityAuditEntity(
          id: '2',
          changeType: 'revoked_all',
          oldValue: const {},
          newValue: const {},
          createdAt: DateTime.now(),
        ).changeLabel,
        'Revoked all access',
      );
      expect(
        VisibilityAuditEntity(
          id: '3',
          changeType: 'updated',
          oldValue: const {},
          newValue: const {},
          createdAt: DateTime.now(),
        ).changeLabel,
        'Updated settings',
      );
    });
  });
}
