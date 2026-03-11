import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../coach/domain/entities/coach_entity.dart';

class SubscriptionPackagesScreen extends StatelessWidget {
  const SubscriptionPackagesScreen({super.key, this.coach});

  final CoachEntity? coach;

  @override
  Widget build(BuildContext context) {
    final currentCoach =
        coach ??
        const CoachEntity(
          id: 'preview',
          name: 'GymUnity Coach',
          specialty: 'FITNESS',
          rateLabel: '\$0/hr',
          rating: '0.0',
          reviewsLabel: '0 Reviews',
          badge: 'Preview',
        );
    final baseRate = _hourlyRate(currentCoach.rateLabel);
    final packages = <_PackageConfig>[
      _PackageConfig(
        title: 'Starter',
        description: 'Weekly check-ins and one structured plan update.',
        price: baseRate * 4,
        accent: AppColors.orange,
      ),
      _PackageConfig(
        title: 'Performance',
        description: 'Deeper form feedback, plan tweaks, and progress reviews.',
        price: baseRate * 8,
        accent: AppColors.limeGreen,
      ),
      _PackageConfig(
        title: 'Elite',
        description: 'High-touch coaching with faster response loops and tighter accountability.',
        price: baseRate * 12,
        accent: AppColors.electricBlue,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.textDark,
        title: Text(
          '${currentCoach.name} Packages',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Text(
            'Choose the level of support that fits your current phase.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ...packages.map(
            (package) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: package.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusFull,
                            ),
                          ),
                          child: Text(
                            package.title,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: package.accent,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '\$${package.price.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      package.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () {
                        showAppFeedback(
                          context,
                          '${package.title} with ${currentCoach.name} is ready for checkout once subscription payments are connected.',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: package.accent,
                        foregroundColor: package.accent == AppColors.limeGreen
                            ? AppColors.black
                            : AppColors.white,
                      ),
                      child: Text('Choose ${package.title}'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double _hourlyRate(String rateLabel) {
    final raw = rateLabel.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(raw) ?? 0;
  }
}

class _PackageConfig {
  const _PackageConfig({
    required this.title,
    required this.description,
    required this.price,
    required this.accent,
  });

  final String title;
  final String description;
  final double price;
  final Color accent;
}
