import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../providers/nutrition_providers.dart';

class NutritionPreferencesScreen extends ConsumerWidget {
  const NutritionPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(nutritionProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nutrition preferences')),
      body: AppShellBackground(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (profile) {
            if (profile == null) {
              return _EmptyPreferences(
                onStart: () => Navigator.pushNamed(
                  context,
                  AppRoutes.nutritionSetup,
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              children: [
                _PreferenceTile(
                  label: 'Diet',
                  value: profile.dietaryPreference,
                  icon: Icons.restaurant_outlined,
                ),
                _PreferenceTile(
                  label: 'Meals per day',
                  value: '${profile.mealCountPreference}',
                  icon: Icons.view_day_outlined,
                ),
                _PreferenceTile(
                  label: 'Activity',
                  value: profile.activityLevel ?? 'Inferred from training',
                  icon: Icons.directions_run_outlined,
                ),
                _PreferenceTile(
                  label: 'Cuisines',
                  value: profile.preferredCuisines.join(', '),
                  icon: Icons.public_outlined,
                ),
                _PreferenceTile(
                  label: 'Allergies',
                  value: profile.allergies.isEmpty
                      ? 'None saved'
                      : profile.allergies.join(', '),
                  icon: Icons.health_and_safety_outlined,
                ),
                _PreferenceTile(
                  label: 'Exclusions',
                  value: profile.foodExclusions.isEmpty
                      ? 'None saved'
                      : profile.foodExclusions.join(', '),
                  icon: Icons.block_outlined,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.nutritionSetup),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Update nutrition setup'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPreferences extends StatelessWidget {
  const _EmptyPreferences({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: onStart,
          child: const Text('Start nutrition setup'),
        ),
      ),
    );
  }
}
