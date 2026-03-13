import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../user/domain/entities/app_role.dart';
import '../../../user/presentation/controllers/onboarding_controller.dart';

/// Role selection screen â€” ref: assets/images/role_selection.png
///
/// Light-theme variant. Three role cards (Member, Seller, Coach) with
/// images, descriptions, CTA pills, and "POPULAR" badge on Member.
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = AppConfig.current;
    final cards = <Widget>[
      _RoleCard(
        title: AppStrings.member,
        description: AppStrings.memberDesc,
        cta: AppStrings.memberCta,
        icon: Icons.fitness_center,
        badge: AppStrings.popular,
        imagePath: 'assets/images/role_selection.png',
        onSelect: () {
          _onSelectRole(
            context: context,
            ref: ref,
            role: AppRole.member,
            route: AppRoutes.memberOnboarding,
          );
        },
      ),
    ];

    if (config.enableSellerRole) {
      cards.add(
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _RoleCard(
            title: AppStrings.seller,
            description: AppStrings.sellerDesc,
            cta: AppStrings.sellerCta,
            icon: Icons.storefront_outlined,
            imagePath: 'assets/images/fitness_store_home.png',
            onSelect: () {
              _onSelectRole(
                context: context,
                ref: ref,
                role: AppRole.seller,
                route: AppRoutes.sellerOnboarding,
              );
            },
          ),
        ),
      );
    }

    if (config.enableCoachRole) {
      cards.add(
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _RoleCard(
            title: AppStrings.coach,
            description: AppStrings.coachDesc,
            cta: AppStrings.coachCta,
            icon: Icons.groups_outlined,
            imagePath: 'assets/images/discover_coaches.png',
            onSelect: () {
              _onSelectRole(
                context: context,
                ref: ref,
                role: AppRole.coach,
                route: AppRoutes.coachOnboarding,
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.screenPadding,
          ),
          children: [
            // â”€â”€ Top bar â”€â”€
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textDark,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    AppStrings.appName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 24),
                ],
              ),
            ),

            // â”€â”€ Heading â”€â”€
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.roleHeadline,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  config.isProduction
                      ? 'Choose your member experience to continue into GymUnity.'
                      : AppStrings.roleSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // â”€â”€ Role cards â”€â”€
            ...cards,
            const SizedBox(height: 24),

            // â”€â”€ Already have account â”€â”€
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.alreadyHaveAccountRole,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.login);
                  },
                  child: Text(
                    AppStrings.logIn,
                    style: GoogleFonts.inter(
                      color: AppColors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _onSelectRole({
    required BuildContext context,
    required WidgetRef ref,
    required AppRole role,
    required String route,
  }) async {
    final success = await ref
        .read(onboardingControllerProvider.notifier)
        .saveRole(role);
    if (!context.mounted) return;

    if (!success) {
      final error =
          ref.read(onboardingControllerProvider).errorMessage ??
          'Unable to save your role right now.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.pushNamed(context, route);
  }
}

/// A single role card matching the reference image style.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.cta,
    required this.icon,
    required this.imagePath,
    required this.onSelect,
    this.badge,
  });

  final String title;
  final String description;
  final String cta;
  final IconData icon;
  final String imagePath;
  final VoidCallback onSelect;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Image section â”€â”€
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
                child: Image.asset(
                  imagePath,
                  height: 160,
                  cacheHeight: 480, // Request decoding at a smaller size
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    color: AppColors.cardDark,
                    child: Icon(icon, size: 48, color: AppColors.orange),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.white, size: 20),
                ),
              ),
            ],
          ),

          // â”€â”€ Text section â”€â”€
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    if (badge != null)
                      Text(
                        badge!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.orange,
                          letterSpacing: 1.5,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      cta,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                        ),
                        elevation: 0,
                        textStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(AppStrings.select),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
