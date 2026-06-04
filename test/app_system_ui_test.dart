import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GymUnityApp does not set system UI overlay style from build', () {
    final source = File('lib/app/app.dart').readAsStringSync();
    final buildIndex = source.indexOf('Widget build(BuildContext context)');
    final systemUiIndex = source.indexOf(
      'SystemChrome.setSystemUIOverlayStyle',
    );

    expect(systemUiIndex, isNot(-1));
    expect(buildIndex, isNot(-1));
    expect(systemUiIndex, lessThan(buildIndex));
  });
}
