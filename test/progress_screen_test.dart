import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/member/domain/entities/member_progress_entity.dart';
import 'package:my_app/features/member/presentation/screens/progress_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets(
    'deleting weight asks for confirmation and cancel does not delete',
    (tester) async {
      final repo = _repoWithProgress();
      await _pumpScreen(tester, repo);

      await _openWeightDelete(tester);

      expect(find.text('Delete weight entry?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.deleteWeightEntryCalls, 0);
      expect(find.textContaining('Morning weigh-in'), findsOneWidget);
    },
  );

  testWidgets('confirming weight deletion calls repository once', (
    tester,
  ) async {
    final repo = _repoWithProgress();
    await _pumpScreen(tester, repo);

    await _openWeightDelete(tester);
    await tester.tap(
      find.byKey(const Key('progress-confirm-delete-weight-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.deleteWeightEntryCalls, 1);
    expect(repo.lastDeletedWeightEntryId, 'weight-1');
    expect(find.text('Weight entry deleted.'), findsOneWidget);
  });

  testWidgets('weight delete failure shows error and keeps item stable', (
    tester,
  ) async {
    final repo = _repoWithProgress()
      ..deleteWeightEntryError = StateError('delete failed');
    await _pumpScreen(tester, repo);

    await _openWeightDelete(tester);
    await tester.tap(
      find.byKey(const Key('progress-confirm-delete-weight-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.deleteWeightEntryCalls, 1);
    expect(
      find.textContaining('Weight entry could not be deleted:'),
      findsOneWidget,
    );
    expect(find.text('Delete weight entry?'), findsOneWidget);
    expect(find.textContaining('Morning weigh-in'), findsOneWidget);
  });

  testWidgets('saving weight shows loading and prevents duplicate save', (
    tester,
  ) async {
    final repo = _repoWithProgress()
      ..saveWeightEntryCompleter = Completer<void>();
    await _pumpScreen(tester, repo);

    await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Weight (kg)'), '83');
    await tester.pump();
    await tester.tap(find.byKey(const Key('progress-save-weight-button')));
    await tester.pump();

    expect(repo.saveWeightEntryCalls, 1);
    expect(find.text('Saving...'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('progress-save-weight-button')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(repo.saveWeightEntryCalls, 1);

    repo.saveWeightEntryCompleter!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Weight entry saved.'), findsOneWidget);
  });

  testWidgets(
    'deleting measurement asks for confirmation and cancel does not delete',
    (tester) async {
      final repo = _repoWithProgress();
      await _pumpScreen(tester, repo);

      await _openMeasurementDelete(tester);

      expect(find.text('Delete measurement?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.deleteBodyMeasurementCalls, 0);
      expect(find.text('Monthly baseline'), findsOneWidget);
    },
  );

  testWidgets('confirming measurement deletion calls repository once', (
    tester,
  ) async {
    final repo = _repoWithProgress();
    await _pumpScreen(tester, repo);

    await _openMeasurementDelete(tester);
    await tester.tap(
      find.byKey(const Key('progress-confirm-delete-measurement-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.deleteBodyMeasurementCalls, 1);
    expect(repo.lastDeletedBodyMeasurementId, 'measurement-1');
    expect(find.text('Measurement deleted.'), findsOneWidget);
  });

  testWidgets('measurement delete failure shows error and keeps item stable', (
    tester,
  ) async {
    final repo = _repoWithProgress()
      ..deleteBodyMeasurementError = StateError('delete failed');
    await _pumpScreen(tester, repo);

    await _openMeasurementDelete(tester);
    await tester.tap(
      find.byKey(const Key('progress-confirm-delete-measurement-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.deleteBodyMeasurementCalls, 1);
    expect(
      find.textContaining('Measurement could not be deleted:'),
      findsOneWidget,
    );
    expect(find.text('Delete measurement?'), findsOneWidget);
    expect(find.text('Monthly baseline'), findsOneWidget);
  });

  testWidgets('saving measurement shows loading and prevents duplicate save', (
    tester,
  ) async {
    final repo = _repoWithProgress()
      ..saveBodyMeasurementCompleter = Completer<void>();
    await _pumpScreen(tester, repo);

    await tester.tap(find.byIcon(Icons.straighten_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Waist (cm)'), '88');
    await tester.pump();
    await tester.tap(find.byKey(const Key('progress-save-measurement-button')));
    await tester.pump();

    expect(repo.saveBodyMeasurementCalls, 1);
    expect(find.text('Saving...'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('progress-save-measurement-button')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(repo.saveBodyMeasurementCalls, 1);

    repo.saveBodyMeasurementCompleter!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Measurement saved.'), findsOneWidget);
  });
}

FakeMemberRepository _repoWithProgress() {
  return FakeMemberRepository()
    ..weightEntries = <WeightEntryEntity>[
      WeightEntryEntity(
        id: 'weight-1',
        memberId: 'member-1',
        weightKg: 82.4,
        recordedAt: DateTime(2026, 5, 20),
        note: 'Morning weigh-in',
      ),
    ]
    ..measurements = <BodyMeasurementEntity>[
      BodyMeasurementEntity(
        id: 'measurement-1',
        memberId: 'member-1',
        recordedAt: DateTime(2026, 5, 21),
        waistCm: 89,
        chestCm: 104,
        note: 'Monthly baseline',
      ),
    ];
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeMemberRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        memberRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: ProgressScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openWeightDelete(WidgetTester tester) async {
  await _openEntryMenu(tester, find.textContaining('Morning weigh-in'));
  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();
}

Future<void> _openMeasurementDelete(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Monthly baseline'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await _openEntryMenu(tester, find.text('Monthly baseline'));
  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();
}

Future<void> _openEntryMenu(WidgetTester tester, Finder entryText) async {
  final tile = find.ancestor(of: entryText, matching: find.byType(ListTile));
  final menu = find.descendant(
    of: tile,
    matching: find.byType(PopupMenuButton<String>),
  );
  await tester.tap(menu);
  await tester.pumpAndSettle();
}
