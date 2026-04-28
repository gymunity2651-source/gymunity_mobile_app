import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/error/app_failure.dart';
import 'package:my_app/features/ai_coach/data/repositories/ai_coach_repository_impl.dart';
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
}
