import 'package:flutter_test/flutter_test.dart';
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
}
