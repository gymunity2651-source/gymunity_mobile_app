import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/subscription_entity.dart';
import '../providers/coach_providers.dart';

class CoachResourcesScreen extends ConsumerWidget {
  const CoachResourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourcesAsync = ref.watch(coachResourcesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Resources'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: 'Upload resource',
            onPressed: () => _uploadResource(context, ref),
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: 'Create link resource',
            onPressed: () => _openLinkResourceSheet(context, ref),
            icon: const Icon(Icons.add_link_outlined),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(coachResourcesProvider);
          await ref.read(coachResourcesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            Text(
              'Resource library',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            resourcesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ResourceState(
                icon: Icons.cloud_off_outlined,
                title: 'Resources unavailable',
                body: error.toString(),
                actionLabel: 'Retry',
                onTap: () => ref.invalidate(coachResourcesProvider),
              ),
              data: (resources) {
                if (resources.isEmpty) {
                  return _ResourceState(
                    icon: Icons.folder_outlined,
                    title: 'No resources',
                    body:
                        'Upload PDFs, videos, guides, and meal-plan support files.',
                    actionLabel: 'Upload',
                    onTap: () => _uploadResource(context, ref),
                  );
                }
                return Column(
                  children: resources
                      .map(
                        (resource) => _ResourceTile(
                          title: resource.title,
                          subtitle: resource.description.isEmpty
                              ? resource.resourceType.replaceAll('_', ' ')
                              : resource.description,
                          trailing: resource.tags.take(2).join(', '),
                          onAssign: () =>
                              _openAssignSheet(context, ref, resource.id),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadResource(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'mp4', 'mov', 'jpg', 'png'],
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) {
      return;
    }
    final title = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    final path = await ref
        .read(coachRepositoryProvider)
        .uploadCoachResource(bytes: bytes, fileName: file.name);
    await ref
        .read(coachRepositoryProvider)
        .saveCoachResource(
          title: title,
          description: '',
          resourceType: file.extension == 'pdf' ? 'pdf' : 'file',
          storagePath: path,
        );
    ref.invalidate(coachResourcesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Resource uploaded.')));
  }

  Future<void> _openLinkResourceSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final urlController = TextEditingController();
    final tagsController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.screenPadding,
          right: AppSizes.screenPadding,
          top: AppSizes.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'External resource',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            TextField(
              controller: tagsController,
              decoration: const InputDecoration(labelText: 'Tags'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(coachRepositoryProvider)
                      .saveCoachResource(
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        resourceType: 'external_link',
                        externalUrl: urlController.text.trim(),
                        tags: _tags(tagsController.text),
                      );
                  ref.invalidate(coachResourcesProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save link'),
              ),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    urlController.dispose();
    tagsController.dispose();
  }

  Future<void> _openAssignSheet(
    BuildContext context,
    WidgetRef ref,
    String resourceId,
  ) async {
    final subscriptions = await ref.read(
      coachManagedSubscriptionsProvider.future,
    );
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Assign resource',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (subscriptions.isEmpty)
              const Text('No subscriptions available.')
            else
              ...subscriptions
                  .take(8)
                  .map(
                    (subscription) => _AssignSubscriptionTile(
                      subscription: subscription,
                      onTap: () async {
                        await ref
                            .read(coachRepositoryProvider)
                            .assignResourceToClient(
                              subscriptionId: subscription.id,
                              resourceId: resourceId,
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Resource assigned.')),
                          );
                        }
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _AssignSubscriptionTile extends StatelessWidget {
  const _AssignSubscriptionTile({
    required this.subscription,
    required this.onTap,
  });

  final SubscriptionEntity subscription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text(subscription.memberName ?? 'Member'),
      subtitle: Text(subscription.packageTitle ?? 'Coaching'),
      trailing: TextButton(onPressed: onTap, child: const Text('Assign')),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onAssign,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: AppColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(trailing, style: GoogleFonts.inter(fontSize: 11)),
            ),
          TextButton(onPressed: onAssign, child: const Text('Assign')),
        ],
      ),
    );
  }
}

class _ResourceState extends StatelessWidget {
  const _ResourceState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, style: GoogleFonts.inter(color: AppColors.textSecondary)),
          if (actionLabel != null && onTap != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onTap, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

List<String> _tags(String value) => value
    .split(',')
    .map((tag) => tag.trim())
    .where((tag) => tag.isNotEmpty)
    .toList(growable: false);
