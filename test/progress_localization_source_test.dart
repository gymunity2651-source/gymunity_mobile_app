import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress screen user-facing copy uses localization', () {
    final source = File(
      'lib/features/member/presentation/screens/progress_screen.dart',
    ).readAsStringSync();

    for (final key in <String>[
      'l10n.progressTracking',
      'l10n.weightHistory',
      'l10n.bodyMeasurements',
      'l10n.addWeight',
      'l10n.addMeasurement',
      'l10n.weightEntrySaved',
      'l10n.measurementSaved',
      'l10n.enterValidWeightValue',
      'l10n.measurementsPositiveNumbers',
    ]) {
      expect(source, contains(key), reason: 'Missing $key');
    }

    for (final hardcoded in <String>[
      "'Progress Tracking'",
      "'Weight History'",
      "'Body Measurements'",
      "'Add weight'",
      "'Add measurement'",
      "'Weight entry saved.'",
      "'Measurement saved.'",
      "'Enter a valid weight value.'",
      "'Measurements must be positive numbers.'",
      "'Retry'",
    ]) {
      expect(source, isNot(contains(hardcoded)), reason: hardcoded);
    }
  });
}
