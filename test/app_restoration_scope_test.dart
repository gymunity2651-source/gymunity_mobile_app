import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GymUnityApp declares a safe Flutter restoration scope', () async {
    final source = await File('lib/app/app.dart').readAsString();

    expect(source, contains("restorationScopeId: 'gymunity_app'"));
  });
}
