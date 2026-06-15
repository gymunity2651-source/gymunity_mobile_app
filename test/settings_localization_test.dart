import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings screen reads user-facing labels from localization', () {
    final source = File(
      'lib/features/settings/presentation/screens/settings_screen.dart',
    ).readAsStringSync();

    expect(source, contains('context.l10n'));
    expect(source, contains('l10n.settings'));
    expect(source, contains('l10n.language'));
    expect(source, contains('l10n.arabic'));
    expect(source, contains('l10n.english'));
    expect(source, isNot(contains("const Text('Settings')")));
    expect(source, isNot(contains("Text('Language')")));
  });

  test('Settings preferences keep backend language values stable', () {
    final source = File(
      'lib/features/settings/presentation/providers/settings_providers.dart',
    ).readAsStringSync();

    expect(source, contains("'language': language.name"));
    expect(source, contains("'arabic'"));
    expect(source, contains("'english'"));
    expect(source, contains('AppLanguage.arabic'));
    expect(source, contains('AppLanguage.english'));
  });
}
