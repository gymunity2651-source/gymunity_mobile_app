import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/external_link_service.dart';
import '../../../../core/widgets/app_feedback.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.current;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Text(
            'Need help with login, account deletion, or reviewer access? Use one of the verified support channels below.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          if (config.supportUrl.trim().isNotEmpty)
            _SupportCard(
              icon: Icons.support_agent_outlined,
              title: 'Support Center',
              description:
                  'Open the configured support portal for help articles and direct support.',
              onTap: () async {
                final opened = await ExternalLinkService.openSupportUrl();
                if (!context.mounted || opened) {
                  return;
                }
                showAppFeedback(context, 'Unable to open the support URL.');
              },
            ),
          if (config.supportEmail.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _SupportCard(
              icon: Icons.email_outlined,
              title: 'Email Support',
              description:
                  'Use the configured support email for account issues or reviewer follow-up.',
              onTap: () async {
                final opened = await ExternalLinkService.composeSupportEmail(
                  subject: config.supportEmailSubject,
                );
                if (!context.mounted || opened) {
                  return;
                }
                showAppFeedback(context, 'Unable to open the email client.');
              },
            ),
          ],
          if (config.reviewerLoginHelpUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _SupportCard(
              icon: Icons.fact_check_outlined,
              title: 'Reviewer Access',
              description:
                  'Open the reviewer instructions configured for this environment.',
              onTap: () async {
                final opened = await ExternalLinkService.openReviewerHelp();
                if (!context.mounted || opened) {
                  return;
                }
                showAppFeedback(
                  context,
                  'Unable to open the reviewer access instructions.',
                );
              },
            ),
          ],
          if (config.supportUrl.trim().isEmpty &&
              config.supportEmail.trim().isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Support contact details are not configured for this build.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: 'Privacy Policy',
      body:
          'GymUnity uses the approved privacy policy hosted at the configured legal URL for this environment.',
      actionLabel: 'OPEN PRIVACY POLICY',
      onAction: () async {
        final opened = await ExternalLinkService.openPrivacyPolicy();
        if (!context.mounted || opened) {
          return;
        }
        showAppFeedback(context, 'Unable to open the privacy policy URL.');
      },
      fallbackMessage: 'No privacy policy URL is configured for this build.',
      isConfigured: AppConfig.current.privacyPolicyUrl.trim().isNotEmpty,
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: 'Terms of Service',
      body:
          'GymUnity uses the approved terms of service hosted at the configured legal URL for this environment.',
      actionLabel: 'OPEN TERMS',
      onAction: () async {
        final opened = await ExternalLinkService.openTerms();
        if (!context.mounted || opened) {
          return;
        }
        showAppFeedback(context, 'Unable to open the terms URL.');
      },
      fallbackMessage: 'No terms of service URL is configured for this build.',
      isConfigured: AppConfig.current.termsUrl.trim().isNotEmpty,
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.fallbackMessage,
    required this.isConfigured,
  });

  final String title;
  final String body;
  final String actionLabel;
  final Future<void> Function() onAction;
  final String fallbackMessage;
  final bool isConfigured;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isConfigured ? body : fallbackMessage,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isConfigured) ...[
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.white,
                    ),
                    child: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.orange.withValues(alpha: 0.16),
              child: Icon(icon, color: AppColors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.open_in_new, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
