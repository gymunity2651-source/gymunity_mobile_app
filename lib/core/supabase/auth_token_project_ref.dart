import 'dart:convert';

class AuthTokenProjectRef {
  const AuthTokenProjectRef._();

  static String? expectedProjectRef(String supabaseUrl) {
    final uri = Uri.tryParse(supabaseUrl.trim());
    final host = uri?.host.trim() ?? '';
    if (host.isEmpty) {
      return null;
    }

    final segments = host.split('.');
    if (segments.isEmpty || segments.first.trim().isEmpty) {
      return null;
    }
    return segments.first.trim();
  }

  static String? projectRefFromJwt(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) {
        return null;
      }

      final map = payload.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
      final explicitRef = map['ref']?.toString().trim();
      if (explicitRef != null && explicitRef.isNotEmpty) {
        return explicitRef;
      }

      final issuer = map['iss']?.toString().trim();
      if (issuer == null || issuer.isEmpty) {
        return null;
      }

      final issuerUri = Uri.tryParse(issuer);
      final host = issuerUri?.host.trim() ?? '';
      if (host.isEmpty) {
        return null;
      }
      return expectedProjectRef('https://$host');
    } catch (_) {
      return null;
    }
  }

  static bool matchesProject(String token, String supabaseUrl) {
    final expected = expectedProjectRef(supabaseUrl);
    final actual = projectRefFromJwt(token);
    if (expected == null || actual == null) {
      return true;
    }
    return expected == actual;
  }
}
