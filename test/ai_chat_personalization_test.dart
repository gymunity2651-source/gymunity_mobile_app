import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_message_entity.dart';
import 'package:my_app/features/ai_chat/domain/entities/planner_turn_result.dart';
import 'package:my_app/features/ai_chat/presentation/ai_personalization.dart';
import 'package:my_app/features/coach/domain/entities/workout_plan_entity.dart';
import 'package:my_app/features/member/domain/entities/member_home_summary_entity.dart';
import 'package:my_app/features/member/domain/entities/member_profile_entity.dart';
import 'package:my_app/features/member/domain/entities/member_progress_entity.dart';

void main() {
  test('PlannerTurnResult parses personalization metadata additively', () {
    final result = PlannerTurnResult.fromMap(<String, dynamic>{
      'assistant_message': 'Here is a personalized check-in.',
      'status': 'general_response',
      'conversation_mode': 'progress_checkin',
      'personalization_used': <String>['goal', 'active plan'],
      'suggested_replies': <String>[
        'Compare this week to last week.',
        'Make today easier.',
      ],
      'extracted_profile': const <String, dynamic>{},
      'plan': null,
    });

    expect(result.conversationMode, 'progress_checkin');
    expect(result.personalizationUsed, <String>['goal', 'active plan']);
    expect(result.suggestedReplies, <String>[
      'Compare this week to last week.',
      'Make today easier.',
    ]);
  });

  test(
    'ChatMessageEntity exposes personalization metadata from stored message',
    () {
      final message = ChatMessageEntity(
        id: 'assistant-1',
        sessionId: 'session-1',
        sender: 'assistant',
        content: 'Use your active plan today.',
        createdAt: DateTime(2026, 3, 15),
        metadata: const <String, dynamic>{
          'conversation_mode': 'planner_refine',
          'personalization_used': <String>['active plan', 'recent workouts'],
          'suggested_replies': <String>[
            'Shorten sessions to 40 minutes.',
            'Reduce lower-body volume.',
          ],
        },
      );

      expect(message.conversationMode, 'planner_refine');
      expect(message.personalizationUsed, <String>[
        'active plan',
        'recent workouts',
      ]);
      expect(message.suggestedReplies, <String>[
        'Shorten sessions to 40 minutes.',
        'Reduce lower-body volume.',
      ]);
    },
  );

  test('buildPersonalizedAiSuggestions uses profile and home summary', () {
    final suggestions = buildPersonalizedAiSuggestions(
      profile: const MemberProfileEntity(userId: 'user-1', goal: 'fat_loss'),
      summary: MemberHomeSummaryEntity(
        latestWeightEntry: WeightEntryEntity(
          id: 'weight-1',
          memberId: 'user-1',
          weightKg: 72,
          recordedAt: DateTime(2026, 3, 14),
        ),
        activePlan: const WorkoutPlanEntity(
          id: 'plan-1',
          memberId: 'user-1',
          source: 'ai',
          title: 'Cut Plan',
          status: 'active',
        ),
        latestSession: WorkoutSessionEntity(
          id: 'session-1',
          memberId: 'user-1',
          title: 'Upper',
          performedAt: DateTime(2026, 3, 14),
          durationMinutes: 50,
        ),
      ),
      now: DateTime(2026, 3, 15),
    );

    expect(suggestions, hasLength(3));
    expect(suggestions.first.label, 'Refine current plan');
    expect(suggestions.first.prompt, contains('Cut Plan'));
    expect(suggestions[1].label, 'Weekly check-in');
  });
}
