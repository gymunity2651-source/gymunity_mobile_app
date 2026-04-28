import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/theme/atelier_theme.dart';
import '../../../coach/domain/entities/coach_entity.dart';
import '../../../coach/presentation/providers/coach_providers.dart';

class CoachDetailsScreen extends ConsumerWidget {
  const CoachDetailsScreen({super.key, this.coach});

  final CoachEntity? coach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (coach == null) {
      return const _UnavailableCoachScreen();
    }

    final coachAsync = ref.watch(coachDetailsProvider(coach!.id));
    // Use the coach entity we already have from the marketplace list.
    // The details provider enriches it with packages, reviews, etc.
    // On error/loading, we gracefully fall back to the existing data.
    final currentCoach = coachAsync.valueOrNull ?? coach!;

    if (coachAsync.hasError) {
      debugPrint('[CoachDetailsScreen] Error: ${coachAsync.error}');
    }

    return Theme(
      data: AtelierTheme.light,
      child: Scaffold(
        backgroundColor: AtelierColors.surfaceContainerLowest,
        body: SafeArea(
          child: Builder(
            builder: (context) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const Spacer(),
                          Text(
                            'Coach Profile',
                            style: GoogleFonts.notoSerif(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AtelierColors.onSurface,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AtelierColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AtelierColors.onSurface.withValues(
                                alpha: 0.06,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 42,
                              backgroundColor: AtelierColors.primary,
                              child: Icon(
                                Icons.person,
                                size: 42,
                                color: AtelierColors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              currentCoach.name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSerif(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AtelierColors.onSurface,
                              ),
                            ),
                            if (currentCoach.publicHeadline
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                currentCoach.publicHeadline,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  color: AtelierColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (currentCoach.positioningStatement
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                currentCoach.positioningStatement,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AtelierColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: currentCoach.specialties
                                  .map((specialty) => _Chip(text: specialty))
                                  .toList(growable: false),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    label: 'Experience',
                                    value:
                                        '${currentCoach.yearsExperience} yrs',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    label: currentCoach.trialOfferEnabled
                                        ? 'Trial'
                                        : 'Starting offer',
                                    value: currentCoach.trialOfferEnabled
                                        ? currentCoach.trialLabel
                                        : currentCoach.discoveryPriceLabel,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    label: 'Offers live',
                                    value: '${currentCoach.activePackageCount}',
                                  ),
                                ),
                              ],
                            ),
                            if (currentCoach.isVerified) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AtelierColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Verified Coach',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: AtelierColors.primary,
                                  ),
                                ),
                              ),
                            ],
                            if (currentCoach.trustBadges.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: currentCoach.trustBadges
                                    .map((badge) => _Chip(text: badge.label))
                                    .toList(growable: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(title: 'About'),
                          const SizedBox(height: 8),
                          Text(
                            currentCoach.bio.trim().isEmpty
                                ? 'This coach has not added a public bio yet.'
                                : currentCoach.bio,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              height: 1.5,
                              color: AtelierColors.onSurfaceVariant,
                            ),
                          ),
                          if (currentCoach.serviceSummary
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              currentCoach.serviceSummary,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                height: 1.5,
                                color: AtelierColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _SectionTitle(title: 'Service Model'),
                          const SizedBox(height: 8),
                          Text(
                            currentCoach.locationLabel,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: AtelierColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Chip(text: currentCoach.verificationBadge),
                              _Chip(text: currentCoach.reliabilityLabel),
                              if (currentCoach.languages.isNotEmpty)
                                _Chip(text: currentCoach.languages.join(' / ')),
                            ],
                          ),
                          if (currentCoach.certifications.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _SectionTitle(title: 'Certifications'),
                            const SizedBox(height: 8),
                            ...currentCoach.certifications.map(
                              (certification) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.verified_outlined),
                                title: Text(certification.title),
                                subtitle: Text(
                                  [
                                    if (certification.issuer != null)
                                      certification.issuer!,
                                    if (certification.year != null)
                                      certification.year.toString(),
                                  ].join(' - '),
                                ),
                              ),
                            ),
                          ],
                          if (currentCoach.testimonials.isNotEmpty ||
                              currentCoach.resultMedia.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _SectionTitle(title: 'Proof'),
                            const SizedBox(height: 8),
                            if (currentCoach.resultMedia.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: currentCoach.resultMedia
                                    .take(4)
                                    .map(
                                      (media) => _Chip(
                                        text:
                                            media.caption?.trim().isNotEmpty ==
                                                true
                                            ? media.caption!
                                            : media.mediaType,
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            if (currentCoach.testimonials.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...currentCoach.testimonials
                                  .take(3)
                                  .map(
                                    (testimonial) => Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color:
                                            AtelierColors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AtelierColors.outlineVariant
                                              .withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Text(
                                        testimonial.memberName == null
                                            ? testimonial.quote
                                            : '${testimonial.quote}\n- ${testimonial.memberName}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          height: 1.45,
                                          color: AtelierColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ],
                          const SizedBox(height: 20),
                          _SectionTitle(title: 'Offer Preview'),
                          const SizedBox(height: 8),
                          if (currentCoach.packages.isEmpty)
                            Text(
                              'This coach has not published any offers yet.',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: AtelierColors.onSurfaceVariant,
                              ),
                            )
                          else
                            ...currentCoach.packages
                                .take(2)
                                .map(
                                  (package) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color:
                                            AtelierColors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AtelierColors.outlineVariant
                                              .withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  package.title,
                                                  style: GoogleFonts.manrope(
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        AtelierColors.onSurface,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                package.checkoutPriceLabel,
                                                style: GoogleFonts.manrope(
                                                  fontWeight: FontWeight.w700,
                                                  color: AtelierColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _Chip(
                                                text:
                                                    '${package.durationWeeks} weeks',
                                              ),
                                              _Chip(
                                                text:
                                                    '${package.sessionsPerWeek} sessions / week',
                                              ),
                                              _Chip(
                                                text: package.weeklyCheckinType,
                                              ),
                                              _Chip(text: package.locationMode),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            package.outcomeSummary
                                                    .trim()
                                                    .isEmpty
                                                ? package.description
                                                : package.outcomeSummary,
                                            style: GoogleFonts.manrope(
                                              fontSize: 13,
                                              height: 1.45,
                                              color: AtelierColors
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                          if (package
                                              .deliverableLabels
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: package
                                                  .deliverableLabels
                                                  .take(4)
                                                  .map(
                                                    (label) =>
                                                        _Chip(text: label),
                                                  )
                                                  .toList(growable: false),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          if (currentCoach.packages.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.subscriptionPackages,
                                    arguments: currentCoach,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AtelierColors.primary,
                                  foregroundColor: AtelierColors.white,
                                ),
                                child: const Text('View full offers'),
                              ),
                            ),
                          ],
                          if (currentCoach.faqItems.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _SectionTitle(title: 'FAQ'),
                            const SizedBox(height: 8),
                            ...currentCoach.faqItems.map(
                              (faq) => ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(faq.question),
                                childrenPadding: const EdgeInsets.only(
                                  bottom: 10,
                                ),
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      faq.answer,
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        height: 1.45,
                                        color: AtelierColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _SectionTitle(title: 'Availability'),
                          const SizedBox(height: 8),
                          if (currentCoach.availability.isEmpty)
                            Text(
                              'No public availability has been added yet.',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: AtelierColors.onSurfaceVariant,
                              ),
                            )
                          else
                            ...currentCoach.availability.map(
                              (slot) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(slot.weekdayLabel),
                                subtitle: Text(
                                  '${slot.startTime} - ${slot.endTime} (${slot.timezone})',
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          _SectionTitle(title: 'Reviews'),
                          const SizedBox(height: 8),
                          if (currentCoach.reviews.isEmpty)
                            Text(
                              'No reviews yet.',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: AtelierColors.onSurfaceVariant,
                              ),
                            )
                          else
                            ...currentCoach.reviews
                                .take(5)
                                .map(
                                  (review) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color:
                                            AtelierColors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AtelierColors.outlineVariant
                                              .withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review.memberDisplayName,
                                            style: GoogleFonts.manrope(
                                              fontWeight: FontWeight.w700,
                                              color: AtelierColors.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('${review.rating}/5'),
                                          const SizedBox(height: 6),
                                          Text(review.reviewText),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AtelierColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _UnavailableCoachScreen extends StatelessWidget {
  const _UnavailableCoachScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No coach details were provided for this route.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.notoSerif(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AtelierColors.onSurface,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
