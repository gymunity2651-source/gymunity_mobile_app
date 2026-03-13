import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../coach/domain/entities/coach_entity.dart';
import '../../../coach/presentation/providers/coach_providers.dart';
import '../../../../core/di/providers.dart';

class SubscriptionPackagesScreen extends ConsumerWidget {
  const SubscriptionPackagesScreen({super.key, this.coach});

  final CoachEntity? coach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (coach == null) {
      return const _UnavailablePackagesScreen();
    }

    final coachAsync = ref.watch(coachDetailsProvider(coach!.id));
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.textDark,
        title: Text('${coach!.name} Packages'),
      ),
      body: coachAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: ElevatedButton(
            onPressed: () => ref.refresh(coachDetailsProvider(coach!.id)),
            child: const Text('Retry'),
          ),
        ),
        data: (data) {
          final currentCoach = data ?? coach!;
          if (currentCoach.packages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Text(
                  'This coach does not have any active packages right now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              Text(
                'Request a real coaching package. GymUnity will create a pending coaching service request and the coach will confirm manual payment offline.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ...currentCoach.packages.map(
                (package) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                package.title,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            Text(
                              '\$${package.price.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          package.description,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Billing cycle: ${package.billingCycle}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: () => _requestPackage(
                            context: context,
                            ref: ref,
                            packageId: package.id,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: AppColors.white,
                          ),
                          child: const Text('Request this package'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestPackage({
    required BuildContext context,
    required WidgetRef ref,
    required String packageId,
  }) async {
    final noteController = TextEditingController();
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Request Coaching Package'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This creates a real pending coaching service request. Payment stays manual/offline until the coach confirms it.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Optional note to the coach',
                ),
              ),
            ],
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
        );
      },
    );
    if (shouldContinue != true) {
      return;
    }

    try {
      await ref
          .read(coachRepositoryProvider)
          .requestSubscription(
            packageId: packageId,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Coaching package request created. It is now pending manual payment confirmation.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _UnavailablePackagesScreen extends StatelessWidget {
  const _UnavailablePackagesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Text(
            'No coach package context was provided for this route.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 15),
          ),
        ),
      ),
    );
  }
}
