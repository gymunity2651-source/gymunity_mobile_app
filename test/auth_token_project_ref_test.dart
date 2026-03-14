import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/supabase/auth_token_project_ref.dart';

void main() {
  group('AuthTokenProjectRef', () {
    test('extracts expected project ref from Supabase URL', () {
      expect(
        AuthTokenProjectRef.expectedProjectRef(
          'https://pooelnnveljiikpdrvqw.supabase.co',
        ),
        'pooelnnveljiikpdrvqw',
      );
    });

    test('extracts project ref from jwt ref claim', () {
      final token = _jwt(<String, dynamic>{
        'ref': 'pooelnnveljiikpdrvqw',
        'iss': 'https://pooelnnveljiikpdrvqw.supabase.co/auth/v1',
      });

      expect(
        AuthTokenProjectRef.projectRefFromJwt(token),
        'pooelnnveljiikpdrvqw',
      );
    });

    test('detects mismatch between token project and configured project', () {
      final token = _jwt(<String, dynamic>{
        'ref': 'differentprojectref',
        'iss': 'https://differentprojectref.supabase.co/auth/v1',
      });

      expect(
        AuthTokenProjectRef.matchesProject(
          token,
          'https://pooelnnveljiikpdrvqw.supabase.co',
        ),
        isFalse,
      );
    });
  });
}

String _jwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.signature';
}
