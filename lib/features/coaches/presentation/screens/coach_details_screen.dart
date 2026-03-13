import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
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
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: coachAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            onRetry: () => ref.refresh(coachDetailsProvider(coach!.id)),
          ),
          data: (data) {
            final currentCoach = data ?? coach!;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.screenPadding),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Spacer(),
                        Text(
                          'Coach Details',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.screenPadding,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.orange,
                            child: Icon(
                              Icons.person,
                              size: 42,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            currentCoach.name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: currentCoach.specialties
                                .map(
                                  (specialty) => Chip(
                                    label: Text(specialty),
                                    backgroundColor: AppColors.lightBackground,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Experience',
                                  value: '${currentCoach.yearsExperience} yrs',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  label: 'Rate',
                                  value: currentCoach.rateLabel,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  label: currentCoach.ratingCount == 0
                                      ? 'Reviews'
                                      : 'Rating',
                                  value: currentCoach.ratingCount == 0
                                      ? 'None'
                                      : currentCoach.rating,
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
                                color: AppColors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusFull,
                                ),
                              ),
                              child: Text(
                                'Verified Coach',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(title: 'Bio'),
                        const SizedBox(height: 8),
                        Text(
                          currentCoach.bio.trim().isEmpty
                              ? 'This coach has not added a public bio yet.'
                              : currentCoach.bio,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionTitle(title: 'Service Model'),
                        const SizedBox(height: 8),
                        Text(
                          currentCoach.deliveryMode?.replaceAll('_', ' ') ??
                              'Not specified yet',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (currentCoach.serviceSummary.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            currentCoach.serviceSummary,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _SectionTitle(title: 'Availability'),
                        const SizedBox(height: 8),
                        if (currentCoach.availability.isEmpty)
                          Text(
                            'No public availability has been added yet.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
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
                        _SectionTitle(title: 'Packages'),
                        const SizedBox(height: 8),
                        if (currentCoach.packages.isEmpty)
                          Text(
                            'This coach has not published any packages yet.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          ...currentCoach.packages
                              .take(2)
                              .map(
                                (package) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(package.title),
                                  subtitle: Text(package.description),
                                  trailing: Text(
                                    '\$${package.price.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.orange,
                                    ),
                                  ),
                                ),
                              ),
                        if (currentCoach.packages.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.subscriptionPackages,
                                arguments: currentCoach,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: AppColors.white,
                            ),
                            child: const Text('Request Coaching Package'),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _SectionTitle(title: 'Reviews'),
                        const SizedBox(height: 8),
                        if (currentCoach.reviews.isEmpty)
                          Text(
                            'No reviews yet.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
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
                                      color: AppColors.lightSurface,
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusLg,
                                      ),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          review.memberDisplayName,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
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
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Text(
            'No coach details were provided for this route.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GymUnity could not load this coach right now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
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
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
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
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
