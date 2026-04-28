import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/external_link_service.dart';
import '../../domain/entities/coach_hub_entity.dart';
import '../providers/member_providers.dart';

class MemberCoachResourcesScreen extends ConsumerWidget {
  const MemberCoachResourcesScreen({super.key, this.subscriptionId});

  final String? subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourcesAsync = ref.watch(
      memberAssignedResourcesProvider(subscriptionId),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Coach Resources'),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(memberAssignedResourcesProvider(subscriptionId));
          await ref.read(
            memberAssignedResourcesProvider(subscriptionId).future,
          );
        },
        child: resourcesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          ),
          error: (error, _) => _StateText(text: error.toString()),
          data: (resources) {
            if (resources.isEmpty) {
              return const _StateText(
                text: 'Resources your coach assigns will appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: resources.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ResourceCard(
                resource: resources[index],
                subscriptionId: subscriptionId,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ResourceCard extends ConsumerWidget {
  const _ResourceCard({required this.resource, required this.subscriptionId});

  final MemberAssignedResourceEntity resource;
  final String? subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                resource.isExternal
                    ? Icons.link_outlined
                    : Icons.insert_drive_file_outlined,
                color: AppColors.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  resource.title,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _Badge(
                resource.isCompleted
                    ? 'completed'
                    : resource.isViewed
                    ? 'viewed'
                    : 'new',
              ),
            ],
          ),
          if (resource.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              resource.description,
              style: GoogleFonts.inter(
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (resource.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              resource.note!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _open(context, ref),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: resource.isCompleted
                      ? null
                      : () => _mark(context, ref, completed: true),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Complete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      final url = resource.externalUrl?.trim().isNotEmpty == true
          ? resource.externalUrl!
          : await ref
                .read(memberRepositoryProvider)
                .createCoachResourceSignedUrl(resource.storagePath ?? '');
      await ExternalLinkService.openUrl(url);
      if (!context.mounted) return;
      await _mark(context, ref, viewed: true);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resource could not be opened: $error')),
      );
    }
  }

  Future<void> _mark(
    BuildContext context,
    WidgetRef ref, {
    bool viewed = false,
    bool completed = false,
  }) async {
    try {
      await ref
          .read(memberRepositoryProvider)
          .markResourceProgress(
            assignmentId: resource.id,
            markViewed: viewed || completed,
            markCompleted: completed,
          );
      ref.invalidate(memberAssignedResourcesProvider(subscriptionId));
      ref.invalidate(memberCoachHubProvider(subscriptionId));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resource could not be updated: $error')),
      );
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12)),
    );
  }
}

class _StateText extends StatelessWidget {
  const _StateText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        const SizedBox(height: 160),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
