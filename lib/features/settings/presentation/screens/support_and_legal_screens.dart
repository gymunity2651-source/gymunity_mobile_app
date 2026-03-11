import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            'Support contact options, common answers, and issue reporting live here now instead of a dead-end placeholder.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _SupportCard(
            icon: Icons.chat_bubble_outline,
            title: 'Chat with support',
            description:
                'Best for login issues, account confusion, and broken flows inside the app.',
            onTap: () {
              showAppFeedback(
                context,
                'Live support chat will connect here once your support channel is ready.',
              );
            },
          ),
          const SizedBox(height: 12),
          _SupportCard(
            icon: Icons.email_outlined,
            title: 'Email support',
            description:
                'Use this when you need to attach details or want a written follow-up.',
            onTap: () {
              showAppFeedback(
                context,
                'Support email will open here after your contact address is configured.',
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Popular topics',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...const [
            'How role selection affects the dashboard you receive.',
            'Why some commerce and subscription actions are still preview-only.',
            'How AI chat, coaches, and store flows connect together inside GymUnity.',
          ].map(
            (topic) => Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _FaqRow(topic: topic),
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
    return const _LegalDocumentScreen(
      title: 'Privacy Policy',
      sections: [
        _LegalSection(
          heading: 'Data you provide',
          body:
              'GymUnity stores the account details and profile data needed to deliver your role-based experience, including onboarding choices and connected content.',
        ),
        _LegalSection(
          heading: 'Operational usage',
          body:
              'Activity data, chats, store actions, and subscriptions are used to render dashboards, personalize recommendations, and keep the app functional.',
        ),
        _LegalSection(
          heading: 'Product status',
          body:
              'Some parts of the app still run in preview mode. Where a flow is local-only, the interface now states that clearly instead of implying a live transaction happened.',
        ),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Terms of Service',
      sections: [
        _LegalSection(
          heading: 'Account use',
          body:
              'Members, coaches, and sellers are expected to use the platform according to their selected role and keep account access secure.',
        ),
        _LegalSection(
          heading: 'Marketplace and coaching',
          body:
              'Product discovery and package comparison are available in-app. Final payment and subscription enforcement should not be considered live until the backend checkout phase is connected.',
        ),
        _LegalSection(
          heading: 'AI guidance',
          body:
              'AI output is supportive product functionality and should be reviewed by the user before acting on it for training or nutrition decisions.',
        ),
      ],
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({
    required this.title,
    required this.sections,
  });

  final String title;
  final List<_LegalSection> sections;

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
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        itemBuilder: (context, index) {
          final section = sections[index];
          return Container(
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
                  section.heading,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  section.body,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemCount: sections.length,
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
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.topic});

  final String topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        topic,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({
    required this.heading,
    required this.body,
  });

  final String heading;
  final String body;
}
