import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/coach_member_insights/domain/entities/member_insight_entity.dart';

void main() {
  group('MemberInsightEntity', () {
    test('fromJson parses all fields correctly', () {
      final json = <String, dynamic>{
        'member_id': 'member-1',
        'member_name': 'Ahmed',
        'member_avatar_path': 'avatars/m1.jpg',
        'current_goal': 'weight_loss',
        'subscription_status': 'active',
        'package_title': 'Starter Pack',
        'last_active_at': '2026-04-15T10:00:00.000Z',
        'plan_insight': <String, dynamic>{
          'plan_id': 'plan-1',
          'plan_title': 'Fat Burn 4W',
          'plan_source': 'ai',
          'plan_status': 'active',
          'total_days': 28,
          'total_tasks': 84,
        },
        'adherence_insight': <String, dynamic>{
          'total_tasks': 84,
          'completed_tasks': 60,
          'partial_tasks': 5,
          'skipped_tasks': 3,
          'missed_tasks': 16,
          'completion_rate': 71.4,
          'streak_days': 3,
        },
        'progress_insight': <String, dynamic>{
          'latest_weight': 82.5,
          'weight_4w_ago': 86.0,
          'weight_trend': 'decreasing',
        },
        'nutrition_insight': <String, dynamic>{
          'target_calories': 2000,
          'target_protein_g': 150,
          'has_active_meal_plan': true,
        },
        'product_insight': <String, dynamic>{
          'recommended_products': <dynamic>[
            <String, dynamic>{
              'product_id': 'prod-1',
              'product_title': 'Whey Protein',
              'context': 'goal_aligned',
              'status': 'suggested',
            },
          ],
          'purchased_relevant': <dynamic>[],
        },
        'risk_flags': <dynamic>['low_adherence', 'no_recent_checkin'],
      };

      final entity = MemberInsightEntity.fromJson(json);

      expect(entity.memberId, 'member-1');
      expect(entity.memberName, 'Ahmed');
      expect(entity.memberAvatarPath, 'avatars/m1.jpg');
      expect(entity.currentGoal, 'weight_loss');
      expect(entity.subscriptionStatus, 'active');
      expect(entity.packageTitle, 'Starter Pack');
      expect(entity.lastActiveAt, isNotNull);

      expect(entity.planInsight, isNotNull);
      expect(entity.planInsight!.planId, 'plan-1');
      expect(entity.planInsight!.totalDays, 28);
      expect(entity.planInsight!.totalTasks, 84);

      expect(entity.adherenceInsight, isNotNull);
      expect(entity.adherenceInsight!.completedTasks, 60);
      expect(entity.adherenceInsight!.completionRate, 71.4);
      expect(entity.adherenceInsight!.streakDays, 3);

      expect(entity.progressInsight, isNotNull);
      expect(entity.progressInsight!.latestWeight, 82.5);
      expect(entity.progressInsight!.weightTrend, 'decreasing');

      expect(entity.nutritionInsight, isNotNull);
      expect(entity.nutritionInsight!.targetCalories, 2000);
      expect(entity.nutritionInsight!.hasActiveMealPlan, true);

      expect(entity.productInsight, isNotNull);
      expect(entity.productInsight!.recommendedProducts.length, 1);
      expect(
        entity.productInsight!.recommendedProducts.first.productTitle,
        'Whey Protein',
      );

      expect(entity.riskFlags, ['low_adherence', 'no_recent_checkin']);
      expect(entity.hasLowAdherence, true);
      expect(entity.hasNoRecentCheckin, true);
      expect(entity.hasManyMissedSessions, false);
      expect(entity.hasAnyRisk, true);
    });

    test('fromJson handles null/missing consent-gated sections', () {
      final json = <String, dynamic>{
        'member_id': 'member-2',
        'member_name': 'Sara',
        'subscription_status': 'active',
      };

      final entity = MemberInsightEntity.fromJson(json);

      expect(entity.memberId, 'member-2');
      expect(entity.memberName, 'Sara');
      expect(entity.planInsight, isNull);
      expect(entity.adherenceInsight, isNull);
      expect(entity.progressInsight, isNull);
      expect(entity.nutritionInsight, isNull);
      expect(entity.productInsight, isNull);
      expect(entity.riskFlags, isEmpty);
      expect(entity.hasAnyRisk, false);
    });

    test('fromJson defaults member_name to Member when null', () {
      final json = <String, dynamic>{
        'member_id': 'member-3',
        'subscription_status': 'active',
      };

      final entity = MemberInsightEntity.fromJson(json);
      expect(entity.memberName, 'Member');
    });
  });

  group('InsightSummaryEntity', () {
    test('fromJson parses complete summary', () {
      final json = <String, dynamic>{
        'subscription_id': 'sub-1',
        'member_id': 'member-1',
        'member_name': 'Ahmed',
        'current_goal': 'muscle_gain',
        'package_title': 'Pro Package',
        'status': 'active',
        'started_at': '2026-03-01T00:00:00.000Z',
        'has_visibility_settings': true,
        'any_data_shared': true,
        'completion_rate': 85.5,
        'last_checkin_at': '2026-04-14T10:00:00.000Z',
        'risk_flags': <dynamic>['many_missed_sessions'],
      };

      final entity = InsightSummaryEntity.fromJson(json);

      expect(entity.subscriptionId, 'sub-1');
      expect(entity.memberName, 'Ahmed');
      expect(entity.hasVisibilitySettings, true);
      expect(entity.anyDataShared, true);
      expect(entity.completionRate, 85.5);
      expect(entity.hasAnyRisk, true);
      expect(entity.riskFlags, ['many_missed_sessions']);
    });

    test('fromJson defaults when fields missing', () {
      final json = <String, dynamic>{
        'subscription_id': 'sub-2',
        'member_id': 'member-2',
        'status': 'active',
      };

      final entity = InsightSummaryEntity.fromJson(json);

      expect(entity.memberName, 'Member');
      expect(entity.hasVisibilitySettings, false);
      expect(entity.anyDataShared, false);
      expect(entity.completionRate, isNull);
      expect(entity.riskFlags, isEmpty);
      expect(entity.hasAnyRisk, false);
    });
  });

  group('AdherenceInsightEntity', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'total_tasks': 100,
        'completed_tasks': 80,
        'partial_tasks': 5,
        'skipped_tasks': 3,
        'missed_tasks': 12,
        'completion_rate': 80.0,
        'streak_days': 7,
        'last_completed_at': '2026-04-17T08:00:00.000Z',
      };

      final entity = AdherenceInsightEntity.fromJson(json);
      expect(entity.totalTasks, 100);
      expect(entity.completedTasks, 80);
      expect(entity.completionRate, 80.0);
      expect(entity.streakDays, 7);
      expect(entity.lastCompletedAt, isNotNull);
    });

    test('fromJson handles all nulls with defaults', () {
      final entity = AdherenceInsightEntity.fromJson(const <String, dynamic>{});
      expect(entity.totalTasks, 0);
      expect(entity.completedTasks, 0);
      expect(entity.completionRate, 0);
      expect(entity.lastCompletedAt, isNull);
    });
  });

  group('ProgressInsightEntity', () {
    test('fromJson with measurement snapshot', () {
      final json = <String, dynamic>{
        'latest_weight': 75.0,
        'weight_4w_ago': 78.0,
        'weight_trend': 'decreasing',
        'latest_measurement': <String, dynamic>{
          'waist_cm': 80.0,
          'chest_cm': 100.0,
          'body_fat_percent': 18.5,
        },
      };

      final entity = ProgressInsightEntity.fromJson(json);
      expect(entity.latestWeight, 75.0);
      expect(entity.weightTrend, 'decreasing');
      expect(entity.latestMeasurement, isNotNull);
      expect(entity.latestMeasurement!.waistCm, 80.0);
      expect(entity.latestMeasurement!.bodyFatPercent, 18.5);
    });
  });
}
