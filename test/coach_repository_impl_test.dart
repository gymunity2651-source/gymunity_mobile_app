import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/error/app_failure.dart';
import 'package:my_app/features/coach/data/repositories/coach_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('coach profile schema-compatible writes', () {
    test(
      'missing-column errors retry with reduced payloads until success',
      () async {
        final payloads = buildCoachProfilePayloadVariants(
          fullPayload: <String, dynamic>{
            'user_id': 'coach-1',
            'bio': 'Bio',
            'specialties': const <String>['Strength'],
            'headline': 'Strength coach',
            'positioning_statement': 'Structured coaching',
            'delivery_mode': 'remote',
            'service_summary': 'Weekly support',
            'city': 'Cairo',
            'response_sla_hours': 12,
          },
        );

        final attemptedPayloads = <Map<String, dynamic>>[];
        await runSchemaCompatibleWrite(
          payloads: payloads,
          operation: (payload) async {
            attemptedPayloads.add(Map<String, dynamic>.from(payload));
            if (attemptedPayloads.length < 3) {
              throw const PostgrestException(
                message:
                    "Could not find the 'headline' column of 'coach_profiles' in the schema cache",
                code: 'PGRST204',
              );
            }
          },
        );

        expect(attemptedPayloads, hasLength(3));
        expect(attemptedPayloads.first['headline'], 'Strength coach');
        expect(attemptedPayloads[1].containsKey('headline'), isFalse);
        expect(attemptedPayloads[1].containsKey('delivery_mode'), isTrue);
        expect(attemptedPayloads[2].containsKey('delivery_mode'), isFalse);
        expect(attemptedPayloads[2].containsKey('city'), isFalse);
      },
    );

    test('non-schema errors bubble up without retries', () async {
      final payloads = buildCoachProfilePayloadVariants(
        fullPayload: <String, dynamic>{'user_id': 'coach-1'},
      );
      var attempts = 0;

      await expectLater(
        () => runSchemaCompatibleWrite(
          payloads: payloads,
          operation: (_) async {
            attempts++;
            throw const PostgrestException(
              message: 'permission denied',
              code: '42501',
            );
          },
        ),
        throwsA(isA<PostgrestException>()),
      );

      expect(attempts, 1);
    });

    test('missing schema detection recognizes PostgREST cache errors', () {
      const error = PostgrestException(
        message:
            "Could not find the 'headline' column of 'coach_profiles' in the schema cache",
        code: 'PGRST204',
      );

      expect(isMissingSchemaColumnError(error), isTrue);
    });
  });

  group('TAIYO coach client brief mapping', () {
    test('builds request body for the Edge Function', () {
      final body = coachTaiyoClientBriefRequestBody(
        clientId: 'member-1',
        subscriptionId: 'sub-1',
        requestType: 'coach_client_brief',
      );

      expect(body['request_type'], 'coach_client_brief');
      expect(body['client_id'], 'member-1');
      expect(body['subscription_id'], 'sub-1');
    });

    test('maps normalized success response safely', () {
      final brief = coachTaiyoClientBriefFromResponse(<String, dynamic>{
        'request_type': 'coach_client_brief',
        'status': 'success',
        'result': <String, dynamic>{
          'client_status': 'watch',
          'summary': 'Client needs adherence support.',
          'red_flags': <String>['low_adherence'],
          'suggested_action': 'Send a check-in prompt.',
          'suggested_message': 'How did this week feel?',
          'privacy_notes': <String>['Draft only'],
          'risk_level': 'medium',
        },
        'data_quality': <String, dynamic>{
          'missing_fields': <String>[],
          'confidence': 'high',
        },
        'metadata': <String, dynamic>{'generated_at': '2026-05-02T10:00:00Z'},
      });

      expect(brief.status, 'success');
      expect(brief.clientStatus, 'watch');
      expect(brief.redFlags, contains('low_adherence'));
      expect(brief.suggestedMessage, 'How did this week feel?');
      expect(brief.hasDraftMessage, isTrue);
    });

    test('maps visibility-needed response without throwing', () {
      final brief = coachTaiyoClientBriefFromResponse(<String, dynamic>{
        'request_type': 'coach_client_brief',
        'status': 'needs_visibility_permission',
        'result': <String, dynamic>{
          'client_status': 'watch',
          'summary': 'TAIYO needs member visibility permission.',
          'privacy_notes': <String>['No sharing enabled'],
          'risk_level': 'medium',
        },
        'data_quality': <String, dynamic>{
          'missing_fields': <String>['visibility_permission'],
        },
        'metadata': <String, dynamic>{},
      });

      expect(brief.needsVisibilityPermission, isTrue);
      expect(brief.summary, contains('visibility'));
    });

    test('throws NetworkFailure for malformed response', () {
      expect(
        () => coachTaiyoClientBriefFromResponse(null),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
