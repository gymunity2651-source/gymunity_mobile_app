import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/supabase/auth_callback_utils.dart';

void main() {
  group('AuthCallbackUtils', () {
    test('converts raw Flutter callback route into custom scheme URI', () {
      final uri = AuthCallbackUtils.uriFromRouteName('/?code=test-code');

      expect(uri, isNotNull);
      expect(uri!.scheme, 'gymunity');
      expect(uri.host, 'auth-callback');
      expect(AuthCallbackUtils.authorizationCode(uri), 'test-code');
    });

    test('normalizes fragment callback params into query params', () {
      final uri = Uri.parse(
        'gymunity://auth-callback#code=test-code&state=abc123',
      );

      final normalized = AuthCallbackUtils.normalize(uri);

      expect(normalized.fragment, isEmpty);
      expect(normalized.queryParameters['code'], 'test-code');
      expect(normalized.queryParameters['state'], 'abc123');
    });

    test('prefers error_description over generic error', () {
      final uri = Uri.parse(
        'gymunity://auth-callback?error=access_denied&error_description=OAuth%20blocked',
      );

      expect(AuthCallbackUtils.errorMessage(uri), 'OAuth blocked');
    });

    test(
      'builds the same callback fingerprint for equivalent callback forms',
      () {
        final routeUri = AuthCallbackUtils.uriFromRouteName('/?code=test-code');
        final customUri = Uri.parse('gymunity://auth-callback?code=test-code');

        expect(routeUri, isNotNull);
        expect(
          AuthCallbackUtils.callbackFingerprint(routeUri!),
          AuthCallbackUtils.callbackFingerprint(customUri),
        );
      },
    );
  });
}
