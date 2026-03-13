import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

class ExternalLinkService {
  ExternalLinkService._();

  static Future<bool> openUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openSupportUrl() {
    return openUrl(AppConfig.current.supportUrl);
  }

  static Future<bool> openPrivacyPolicy() {
    return openUrl(AppConfig.current.privacyPolicyUrl);
  }

  static Future<bool> openTerms() {
    return openUrl(AppConfig.current.termsUrl);
  }

  static Future<bool> openReviewerHelp() {
    return openUrl(AppConfig.current.reviewerLoginHelpUrl);
  }

  static Future<bool> composeSupportEmail({String? subject, String? body}) {
    final email = AppConfig.current.supportEmail.trim();
    if (email.isEmpty) {
      return Future<bool>.value(false);
    }

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: <String, String>{
        if ((subject ?? '').trim().isNotEmpty) 'subject': subject!.trim(),
        if ((body ?? '').trim().isNotEmpty) 'body': body!.trim(),
      },
    );
    return launchUrl(uri);
  }
}
