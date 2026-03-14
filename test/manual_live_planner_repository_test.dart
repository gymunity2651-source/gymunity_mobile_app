import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:my_app/features/planner/data/repositories/planner_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const runManualLiveTests = bool.fromEnvironment(
    'RUN_MANUAL_LIVE_SUPABASE_TESTS',
  );

  if (!runManualLiveTests) {
    test(
      'manual live planner repository is skipped by default',
      () {},
      skip:
          'Set --dart-define=RUN_MANUAL_LIVE_SUPABASE_TESTS=true to run the live Supabase repository probe.',
    );
    return;
  }

  group('manual live planner repository', () {
    late SupabaseClient client;
    late PlannerRepositoryImpl repository;

    setUpAll(() async {
      await Supabase.initialize(
        url: 'https://pooelnnveljiikpdrvqw.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBvb2Vsbm52ZWxqaWlrcGRydnF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5Mzk3MDYsImV4cCI6MjA4ODUxNTcwNn0.YFxc3cvtzRymeqIq8wot4Xvv65twjXIhn3mhd1m4OTk',
      );
      client = Supabase.instance.client;
      await client.auth.signInWithPassword(
        email: 'qae2elogin1773475185@gmail.com',
        password: 'Qa123456',
      );
      repository = PlannerRepositoryImpl(client);
    });

    test('fetches active plan detail', () async {
      final plan = await repository.getPlanDetail();
      expect(plan, isNotNull);
      expect(plan!.planId, isNotEmpty);
      expect(plan.planTitle, isNotEmpty);
    });

    test('fetches today agenda', () async {
      final tasks = await repository.listTodayAgenda();
      expect(tasks, isA<List>());
    });
  });
}
