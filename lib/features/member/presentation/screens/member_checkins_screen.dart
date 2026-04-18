import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../coach/domain/entities/subscription_entity.dart';
import '../providers/member_providers.dart';

class MemberCheckinsScreen extends ConsumerWidget {
  const MemberCheckinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(memberSubscriptionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Weekly Check-ins'),
        backgroundColor: AppColors.background,
      ),
      body: subscriptionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (subscriptions) {
          final activeSubscriptions = subscriptions
              .where(
                (subscription) =>
                    subscription.isActive || subscription.isPaused,
              )
              .toList(growable: false);

          if (activeSubscriptions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Text(
                  'Activate a coaching subscription first, then your weekly check-ins will appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: activeSubscriptions
                .map(
                  (subscription) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CheckinCard(subscription: subscription),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _CheckinCard extends ConsumerWidget {
  const _CheckinCard({required this.subscription});

  final SubscriptionEntity subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(
      memberWeeklyCheckinsProvider(subscription.id),
    );
    final latest = checkinsAsync.valueOrNull?.isNotEmpty == true
        ? checkinsAsync.valueOrNull!.first
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subscription.coachName ?? 'Coach',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subscription.displayTitle,
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (latest != null)
            Text(
              'Latest: ${latest.weekStart.toLocal().toString().split(' ').first} • ${latest.adherenceScore}% adherence',
              style: GoogleFonts.inter(color: AppColors.textMuted),
            )
          else
            Text(
              'No check-in submitted yet.',
              style: GoogleFonts.inter(color: AppColors.textMuted),
            ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => _openCheckinDialog(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Submit this week'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCheckinDialog(BuildContext context, WidgetRef ref) async {
    final weightController = TextEditingController();
    final waistController = TextEditingController();
    final adherenceController = TextEditingController(text: '80');
    final winsController = TextEditingController();
    final blockersController = TextEditingController();
    final questionsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Check-in for ${subscription.coachName ?? 'coach'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: waistController,
                decoration: const InputDecoration(labelText: 'Waist (cm)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: adherenceController,
                decoration: const InputDecoration(labelText: 'Adherence %'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: winsController,
                decoration: const InputDecoration(labelText: 'Wins'),
              ),
              TextField(
                controller: blockersController,
                decoration: const InputDecoration(labelText: 'Blockers'),
              ),
              TextField(
                controller: questionsController,
                decoration: const InputDecoration(labelText: 'Questions'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(memberRepositoryProvider)
        .submitWeeklyCheckin(
          subscriptionId: subscription.id,
          weekStart: DateTime.now(),
          weightKg: double.tryParse(weightController.text.trim()),
          waistCm: double.tryParse(waistController.text.trim()),
          adherenceScore: int.tryParse(adherenceController.text.trim()) ?? 0,
          wins: winsController.text.trim().isEmpty
              ? null
              : winsController.text.trim(),
          blockers: blockersController.text.trim().isEmpty
              ? null
              : blockersController.text.trim(),
          questions: questionsController.text.trim().isEmpty
              ? null
              : questionsController.text.trim(),
        );
    ref.invalidate(memberWeeklyCheckinsProvider(subscription.id));
    ref.invalidate(memberSubscriptionsProvider);
    ref.invalidate(memberHomeSummaryProvider);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Weekly check-in submitted.')));
  }
}
