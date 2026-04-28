import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/subscription_entity.dart';
import '../providers/coach_providers.dart';

class CoachOnboardingFlowsScreen extends ConsumerWidget {
  const CoachOnboardingFlowsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(coachOnboardingTemplatesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Onboarding'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: 'Create flow',
            onPressed: () => _openTemplateSheet(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(coachOnboardingTemplatesProvider);
          await ref.read(coachOnboardingTemplatesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            Text(
              'Onboarding flows',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'One-click flows can assign welcome messages, programs, habits, check-in schedules, and resources.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _FlowState(
                icon: Icons.cloud_off_outlined,
                title: 'Flows unavailable',
                body: error.toString(),
                actionLabel: 'Retry',
                onTap: () => ref.invalidate(coachOnboardingTemplatesProvider),
              ),
              data: (templates) {
                if (templates.isEmpty) {
                  return _FlowState(
                    icon: Icons.auto_awesome_motion_outlined,
                    title: 'No onboarding flows',
                    body: 'Create templates by client type and goal.',
                    actionLabel: 'Create flow',
                    onTap: () => _openTemplateSheet(context, ref),
                  );
                }
                return Column(
                  children: templates
                      .map(
                        (template) => _FlowTile(
                          title: template.title,
                          subtitle:
                              '${template.clientType.replaceAll('_', ' ')} · ${template.resourceIds.length} resources · ${template.habitTemplates.length} habits',
                          onApply: () =>
                              _openApplySheet(context, ref, template.id),
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

  Future<void> _openTemplateSheet(BuildContext context, WidgetRef ref) async {
    final templates = await ref.read(coachProgramTemplatesProvider.future);
    final resources = await ref.read(coachResourcesProvider.future);
    if (!context.mounted) return;

    final titleController = TextEditingController();
    final welcomeController = TextEditingController();
    final descriptionController = TextEditingController();
    final habitsController = TextEditingController(
      text: 'Water intake, Sleep consistency',
    );
    final nutritionTasksController = TextEditingController(
      text: 'Upload meal photos, Complete nutrition baseline',
    );
    String clientType = 'general';
    String? starterProgramId = templates.isEmpty ? null : templates.first.id;
    final selectedResourceIds = <String>{
      ...resources.take(2).map((resource) => resource.id),
    };

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
        child: StatefulBuilder(
          builder: (context, setSheetState) => ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Onboarding flow',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
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
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: clientType,
                decoration: const InputDecoration(labelText: 'Client type'),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(value: 'fat_loss', child: Text('Fat loss')),
                  DropdownMenuItem(
                    value: 'muscle_gain',
                    child: Text('Muscle gain'),
                  ),
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(
                    value: 'hybrid',
                    child: Text('Hybrid coaching'),
                  ),
                ],
                onChanged: (value) =>
                    setSheetState(() => clientType = value ?? 'general'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: welcomeController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Welcome message',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              if (templates.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: starterProgramId,
                  decoration: const InputDecoration(
                    labelText: 'Starter program',
                  ),
                  items: templates
                      .map(
                        (template) => DropdownMenuItem(
                          value: template.id,
                          child: Text(template.title),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setSheetState(() => starterProgramId = value),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: habitsController,
                decoration: const InputDecoration(
                  labelText: 'Habits',
                  hintText: 'Water intake, Sleep consistency',
                ),
              ),
              TextField(
                controller: nutritionTasksController,
                decoration: const InputDecoration(
                  labelText: 'Nutrition tasks',
                  hintText: 'Upload meal photos, Track water',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Resources',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (resources.isEmpty)
                const Text('No resources available yet.')
              else
                ...resources
                    .take(6)
                    .map(
                      (resource) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selectedResourceIds.contains(resource.id),
                        title: Text(resource.title),
                        onChanged: (selected) {
                          setSheetState(() {
                            if (selected == true) {
                              selectedResourceIds.add(resource.id);
                            } else {
                              selectedResourceIds.remove(resource.id);
                            }
                          });
                        },
                      ),
                    ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(coachRepositoryProvider)
                        .saveOnboardingTemplate(
                          title: titleController.text.trim(),
                          clientType: clientType,
                          description: descriptionController.text.trim(),
                          welcomeMessage: welcomeController.text.trim(),
                          intakeForm: const <String, dynamic>{
                            'status': 'pending',
                            'sections': <String>[
                              'profile',
                              'goals',
                              'constraints',
                            ],
                          },
                          goalsQuestionnaire: const <String, dynamic>{
                            'goal_priority': 'primary',
                            'timeline': 'next_90_days',
                          },
                          starterProgramTemplateId: starterProgramId,
                          habitTemplates: _items(habitsController.text)
                              .map(
                                (item) => <String, dynamic>{
                                  'title': item,
                                  'frequency': 'daily',
                                },
                              )
                              .toList(growable: false),
                          nutritionTasks: _items(nutritionTasksController.text)
                              .map((item) => <String, dynamic>{'title': item})
                              .toList(growable: false),
                          checkinSchedule: const <String, dynamic>{
                            'frequency': 'weekly',
                            'day': 'friday',
                          },
                          resourceIds: selectedResourceIds.toList(
                            growable: false,
                          ),
                        );
                    ref.invalidate(coachOnboardingTemplatesProvider);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    titleController.dispose();
    welcomeController.dispose();
    descriptionController.dispose();
    habitsController.dispose();
    nutritionTasksController.dispose();
  }

  Future<void> _openApplySheet(
    BuildContext context,
    WidgetRef ref,
    String templateId,
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
                    'Apply onboarding flow',
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
              const Text('No active subscriptions available.')
            else
              ...subscriptions
                  .take(8)
                  .map(
                    (subscription) => _ApplySubscriptionTile(
                      subscription: subscription,
                      onTap: () async {
                        await ref
                            .read(coachRepositoryProvider)
                            .applyOnboardingTemplate(
                              subscriptionId: subscription.id,
                              templateId: templateId,
                            );
                        ref.invalidate(coachClientPipelineProvider);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Onboarding flow applied.'),
                            ),
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

class _ApplySubscriptionTile extends StatelessWidget {
  const _ApplySubscriptionTile({
    required this.subscription,
    required this.onTap,
  });

  final SubscriptionEntity subscription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_add_alt_outlined),
      title: Text(subscription.memberName ?? 'Member'),
      subtitle: Text(subscription.packageTitle ?? 'Coaching'),
      trailing: TextButton(onPressed: onTap, child: const Text('Apply')),
    );
  }
}

class _FlowTile extends StatelessWidget {
  const _FlowTile({
    required this.title,
    required this.subtitle,
    required this.onApply,
  });

  final String title;
  final String subtitle;
  final VoidCallback onApply;

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
          const Icon(
            Icons.auto_awesome_motion_outlined,
            color: AppColors.orange,
          ),
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
          TextButton(onPressed: onApply, child: const Text('Apply')),
        ],
      ),
    );
  }
}

class _FlowState extends StatelessWidget {
  const _FlowState({
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

List<String> _items(String raw) => raw
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList(growable: false);
