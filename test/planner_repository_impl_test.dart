import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/error/app_failure.dart';
import 'package:my_app/features/planner/data/repositories/planner_repository_impl.dart';

void main() {
  group('TAIYO workout planner response mapping', () {
    test('maps normalized success to planner turn result', () {
      final result = plannerTurnResultFromTaiyoWorkoutPlannerResponse(
        <String, dynamic>{
          'request_type': 'workout_plan_draft',
          'status': 'success',
          'result': <String, dynamic>{
            'summary': 'Three steady strength days.',
            'activation_allowed': true,
          },
          'data_quality': <String, dynamic>{
            'missing_fields': <String>[],
            'confidence': 'high',
          },
          'metadata': <String, dynamic>{
            'draft_id': 'draft-1',
            'session_id': 'session-1',
            'plan_json': <String, dynamic>{
              'title': 'TAIYO Strength Plan',
              'summary': 'Three steady strength days.',
              'duration_weeks': 4,
              'level': 'beginner',
              'safety_notes': <String>[],
              'weekly_structure': <Map<String, dynamic>>[
                <String, dynamic>{
                  'week_number': 1,
                  'days': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'day_number': 1,
                      'label': 'Day 1',
                      'focus': 'Strength',
                      'tasks': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'type': 'workout',
                          'title': 'Goblet squat',
                          'instructions': 'Controlled reps.',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
            'extracted_profile': <String, dynamic>{
              'goal': 'strength',
              'experience_level': 'beginner',
            },
          },
        },
      );

      expect(result.status, 'plan_ready');
      expect(result.draftId, 'draft-1');
      expect(result.plan?.title, 'TAIYO Strength Plan');
      expect(result.extractedProfile.goal, 'strength');
    });

    test('maps safety block to unsafe request', () {
      final result = plannerTurnResultFromTaiyoWorkoutPlannerResponse(
        <String, dynamic>{
          'request_type': 'workout_plan_draft',
          'status': 'blocked_for_safety',
          'result': <String, dynamic>{
            'summary': 'Safety first.',
            'safety_notes': <String>['Do not train with dizziness.'],
            'activation_allowed': false,
          },
          'data_quality': <String, dynamic>{},
          'metadata': <String, dynamic>{'draft_id': 'draft-safe'},
        },
      );

      expect(result.status, 'unsafe_request');
      expect(result.draftId, 'draft-safe');
      expect(result.plan, isNull);
      expect(result.assistantMessage, 'Safety first.');
    });

    test('throws NetworkFailure for malformed response', () {
      expect(
        () => plannerTurnResultFromTaiyoWorkoutPlannerResponse(null),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
