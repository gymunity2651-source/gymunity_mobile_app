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
    test(
      'maps normalized Edge Function response to existing daily brief entity',
      () {
        final entity = AiDailyBriefEntity.fromTaiyoDailyBriefResponse(
          <String, dynamic>{
            'request_type': 'daily_member_brief',
            'status': 'success',
            'result': <String, dynamic>{
              'training_decision': 'Train normally with controlled intensity.',
              'workout_focus': 'Upper body strength',
              'nutrition_focus': 'Keep protein on track.',
              'risk_level': 'low',
              'motivation_message': 'Build momentum with clean execution.',
              'safety_notes': <String>[],
            },
            'data_quality': <String, dynamic>{
              'missing_fields': <String>['sleep_hours'],
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
        expect(entity.readinessScore, 72);
        expect(
          entity.workoutTitle,
          'Train normally with controlled intensity.',
        );
        expect(entity.workoutSubtitle, 'Upper body strength');
        expect(entity.nutritionBody, 'Keep protein on track.');
        expect(entity.whyShort, 'Build momentum with clean execution.');
        expect(entity.confidence, 0.7);
        expect(entity.signalsUsed, contains('missing_context'));
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
  });
}
