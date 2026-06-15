import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/localization/localized_formatters.dart';

void main() {
  test('formatEgp uses Arabic-Indic digits for Arabic locale', () {
    expect(formatEgp(1200, const Locale('ar')), '١٬٢٠٠ ج.م');
  });

  test('formatEgp uses EGP with Western digits for English locale', () {
    expect(formatEgp(1200, const Locale('en')), 'EGP 1,200');
  });

  test(
    'localized status labels keep backend values separate from UI labels',
    () {
      expect(
        localizedStatusLabel(const Locale('en'), 'in_progress'),
        'In progress',
      );
      expect(
        localizedStatusLabel(const Locale('ar'), 'in_progress'),
        'قيد التنفيذ',
      );
      expect(
        localizedStatusLabel(const Locale('ar'), 'unknown_value'),
        'unknown_value',
      );
    },
  );
}
