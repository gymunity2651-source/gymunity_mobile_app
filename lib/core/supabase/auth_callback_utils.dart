import '../constants/auth_constants.dart';

class AuthCallbackUtils {
  AuthCallbackUtils._();

  static Uri? uriFromRouteName(String? routeName) {
    final route = routeName?.trim() ?? '';
    if (route.isEmpty) {
      return null;
    }

    if (route.contains('://')) {
      return Uri.tryParse(route);
    }

    if (route.startsWith('/?') || route.startsWith('/#')) {
      return Uri.tryParse(
        '${AppAuthConstants.googleOAuthRedirect}${route.substring(1)}',
      );
    }

    return null;
  }

  static bool isAuthCallback(Uri uri) {
    if (uri.scheme != AppAuthConstants.googleOAuthScheme ||
        uri.host != AppAuthConstants.googleOAuthHost) {
      return false;
    }

    final params = mergedParams(uri);
    return params.containsKey('code') ||
        params.containsKey('access_token') ||
        params.containsKey('refresh_token') ||
        params.containsKey('error');
  }

  static Map<String, String> mergedParams(Uri uri) {
    final params = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      params.addAll(Uri.splitQueryString(uri.fragment));
    }
    return params;
  }

  static Uri normalize(Uri uri) {
    final params = mergedParams(uri);
    return uri.replace(queryParameters: params, fragment: '');
  }

  static String? errorMessage(Uri uri) {
    final params = mergedParams(uri);
    final errorDescription = params['error_description']?.trim();
    if (errorDescription != null && errorDescription.isNotEmpty) {
      return errorDescription;
    }

    final error = params['error']?.trim();
    if (error != null && error.isNotEmpty) {
      return error;
    }

    return null;
  }

  static String? authorizationCode(Uri uri) {
    final code = mergedParams(uri)['code']?.trim();
    if (code == null || code.isEmpty) {
      return null;
    }
    return code;
  }

  static String? callbackFingerprint(Uri uri) {
    final params = mergedParams(uri);
    if (params.isEmpty) {
      return null;
    }

    final sortedKeys = params.keys.toList()..sort();
    final serializedParams = sortedKeys
        .map((key) => '$key=${params[key] ?? ''}')
        .join('&');

    return '${uri.scheme}://${uri.host}?$serializedParams';
  }
}
