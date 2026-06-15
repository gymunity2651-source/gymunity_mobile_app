import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GymUnityApp wires generated localizations and locale theme', () {
    final source = File('lib/app/app.dart').readAsStringSync();

    expect(source, contains("../l10n/app_localizations.dart"));
    expect(source, contains('AppLocalizations.delegate'));
    expect(source, contains('...GlobalMaterialLocalizations.delegates'));
    expect(source, contains('AppTheme.darkThemeForLocale(locale)'));
  });
}
