import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/feature_placeholder_screen.dart';
import '../../../user/domain/entities/app_role.dart';

class CoachAccessGate extends ConsumerWidget {
  const CoachAccessGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, _) => FeaturePlaceholderScreen(
        title: 'Sign in required',
        description: 'Please sign in to access the Coach workspace.',
        icon: Icons.lock_outline,
        primaryActionLabel: 'Sign in',
        onPrimaryAction: () =>
            Navigator.pushReplacementNamed(context, AppRoutes.login),
      ),
      data: (profile) {
        if (profile == null) {
          return FeaturePlaceholderScreen(
            title: 'Sign in required',
            description: 'Please sign in to access the Coach workspace.',
            icon: Icons.lock_outline,
            primaryActionLabel: 'Sign in',
            onPrimaryAction: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.login),
          );
        }
        if (!AppConfig.current.enableCoachRole ||
            !AppConfig.current.enableCoachSubscriptions) {
          return FeaturePlaceholderScreen(
            title: 'Coach workspace unavailable',
            description: 'Coach features are currently unavailable.',
            icon: Icons.workspace_premium_outlined,
            primaryActionLabel: 'Back',
            onPrimaryAction: () => Navigator.pop(context),
          );
        }
        if (profile.role != AppRole.coach) {
          return FeaturePlaceholderScreen(
            title: 'Coach access required',
            description: 'This workspace is only available for coach accounts.',
            icon: Icons.workspace_premium_outlined,
            primaryActionLabel: 'Back to home',
            onPrimaryAction: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.memberHome),
          );
        }
        if (!profile.onboardingCompleted) {
          return FeaturePlaceholderScreen(
            title: 'Complete coach setup',
            description:
                'Finish your coach profile before accessing your workspace.',
            icon: Icons.assignment_ind_outlined,
            primaryActionLabel: 'Continue setup',
            onPrimaryAction: () => Navigator.pushReplacementNamed(
              context,
              AppRoutes.coachOnboarding,
            ),
          );
        }

        return child;
      },
    );
  }
}
