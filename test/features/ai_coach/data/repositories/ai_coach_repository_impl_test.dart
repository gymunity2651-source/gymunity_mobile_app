import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/error/app_failure.dart';
import 'package:my_app/features/ai_coach/data/repositories/ai_coach_repository_impl.dart';
import 'package:my_app/features/ai_coach/domain/entities/ai_coach_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ai coach backend gap detection', () {
    test('detects missing daily brief table schema errors', () {
      const error = PostgrestException(
        message:
            "Could not find the table 'public.member_ai_daily_briefs' in the schema cache",
        code: 'PGRST205',
      );

      expect(isMissingAiCoachSchemaError(error), isTrue);
    });

    test('detects missing ai coach rpc schema errors', () {
      const error = PostgrestException(
        message:
            "Could not find the function public.upsert_member_readiness_log(input_log_date, input_energy_level) in the schema cache",
        code: 'PGRST202',
      );

      expect(isMissingAiCoachSchemaError(error), isTrue);
    });

    test('detects friendly backend unavailable failures', () {
      const failure = NetworkFailure(
        message: kAiCoachBackendUnavailableMessage,
        code: '404',
      );

      expect(isAiCoachBackendUnavailableFailure(failure), isTrue);
    });

    test('ignores unrelated failures', () {
      const failure = NetworkFailure(
        message: 'permission denied',
        code: '42501',
      );

      expect(isAiCoachBackendUnavailableFailure(failure), isFalse);
    });
  });

  group('TAIYO daily brief response mapping', () {
    test('fromMap reads UI keys and backward-compatible AI result keys', () {
      final uiEntity = AiDailyBriefEntity.fromMap(<String, dynamic>{
        'id': 'brief-ui',
        'brief_date': '2026-04-29',
        'readiness_score': 84,
        'intensity_band': 'green',
        'recommended_workout_json': <String, dynamic>{
          'title': 'Train upper strength',
          'focus': 'Controlled pressing',
        },
        'habit_focus_json': <String, dynamic>{
          'title': 'TAIYO focus',
          'body': 'Start with the first block.',
        },
        'nutrition_priority_json': <String, dynamic>{
          'title': 'Nutrition focus',
          'body': 'Hit protein early.',
        },
        'why_short': 'Real data.',
      });

      expect(uiEntity.workoutTitle, 'Train upper strength');
      expect(uiEntity.workoutSubtitle, 'Controlled pressing');
      expect(uiEntity.habitBody, 'Start with the first block.');
      expect(uiEntity.nutritionBody, 'Hit protein early.');

      final legacyEntity = AiDailyBriefEntity.fromMap(<String, dynamic>{
        'id': 'brief-legacy',
        'brief_date': '2026-04-29',
        'recommended_workout_json': <String, dynamic>{
          'training_decision': 'Deload today',
          'workout_focus': 'Recovery mobility',
        },
        'habit_focus_json': <String, dynamic>{
          'motivation_message': 'Protect consistency.',
        },
        'nutrition_priority_json': <String, dynamic>{
          'nutrition_focus': 'Hydrate before training.',
        },
        'why_short': 'Legacy data.',
      });

      expect(legacyEntity.workoutTitle, 'Deload today');
      expect(legacyEntity.workoutSubtitle, 'Recovery mobility');
      expect(legacyEntity.habitBody, 'Protect consistency.');
      expect(legacyEntity.nutritionBody, 'Hydrate before training.');
    });

    test(
      'maps normalized Edge Function response to existing daily brief entity',
      () {
        final entity = AiDailyBriefEntity.fromTaiyoDailyBriefResponse(
          <String, dynamic>{
            'request_type': 'daily_member_brief',
            'status': 'success',
            'readiness_score': 86,
            'result': <String, dynamic>{
              'training_decision': 'Train normally with controlled intensity.',
              'workout_focus': 'Upper body strength',
              'nutrition_focus': 'Keep protein on track.',
              'risk_level': 'low',
              'motivation_message': 'Build momentum with clean execution.',
              'safety_notes': <String>[],
            },
            'data_quality': <String, dynamic>{
              'missing_fields': <String>['latest_weight'],
              'optional_missing_fields': <String>['latest_weight'],
              'confidence': 'medium',
            },
            'metadata': <String, dynamic>{
              'source': 'supabase_edge_function',
              'generated_at': '2026-04-29T10:00:00Z',
            },
          },
          briefDate: DateTime(2026, 4, 29),
        );

        expect(entity.id, 'taiyo-daily-brief-2026-04-29');
        expect(entity.briefDate, DateTime(2026, 4, 29));
        expect(entity.intensityBand, 'green');
        expect(entity.readinessScore, 86);
        expect(
          entity.workoutTitle,
          'Train normally with controlled intensity.',
        );
        expect(entity.workoutSubtitle, 'Upper body strength');
        expect(entity.nutritionBody, 'Keep protein on track.');
        expect(entity.whyShort, 'Build momentum with clean execution.');
        expect(entity.confidence, 0.7);
        expect(entity.signalsUsed, isNot(contains('missing_context')));
        expect(entity.sourceContext['status'], 'success');
      },
    );

    test('maps safety-blocked response to coach mode and red intensity', () {
      final entity = AiDailyBriefEntity.fromTaiyoDailyBriefResponse(
        <String, dynamic>{
          'request_type': 'daily_member_brief',
          'status': 'blocked_for_safety',
          'result': <String, dynamic>{
            'training_decision': 'Skip training and seek support.',
            'workout_focus': 'Recovery',
            'nutrition_focus': '',
            'risk_level': 'high',
            'motivation_message': 'Prioritize safety today.',
            'safety_notes': <String>['Dizziness reported'],
          },
          'data_quality': <String, dynamic>{'confidence': 'high'},
          'metadata': <String, dynamic>{},
        },
        briefDate: DateTime(2026, 4, 29),
      );

      expect(entity.coachMode, isTrue);
      expect(entity.intensityBand, 'red');
      expect(entity.readinessScore, 35);
      expect(entity.recommendedActions, contains('review_safety_notes'));
      expect(entity.recap['safety_notes'], <String>['Dizziness reported']);
      expect(entity.confidence, 0.9);
    });

    test('helper getters expose status and linked-action state', () {
      final entity = AiDailyBriefEntity(
        id: 'brief-1',
        briefDate: DateTime(2026, 4, 29),
        planId: 'plan-1',
        dayId: 'day-1',
        primaryTaskId: 'task-1',
        readinessScore: 60,
        intensityBand: 'yellow',
        coachMode: false,
        whyShort: 'Needs context.',
        signalsUsed: const <String>['missing_context'],
        confidence: 0.5,
        sourceContext: const <String, dynamic>{
          'status': 'needs_more_context',
          'legacy_fallback': true,
        },
      );

      expect(entity.isLegacyFallback, isTrue);
      expect(entity.isNeedsMoreContext, isTrue);
      expect(entity.isSafetyBlocked, isFalse);
      expect(entity.canStartWorkout, isTrue);
      expect(entity.hasPrimaryTask, isTrue);
    });
  });
}
