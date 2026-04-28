import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../providers/coach_providers.dart';

class CoachProgramLibraryScreen extends ConsumerWidget {
  const CoachProgramLibraryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(coachProgramTemplatesProvider);
    final exercisesAsync = ref.watch(coachExercisesProvider);

    final content = RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(coachProgramTemplatesProvider);
        ref.invalidate(coachExercisesProvider);
        await Future.wait<dynamic>([
          ref.read(coachProgramTemplatesProvider.future),
          ref.read(coachExercisesProvider.future),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.lg,
          AppSizes.screenPadding,
          96,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Program library',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Create template',
                onPressed: () => _openTemplateSheet(context, ref),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Templates',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          templatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _LibraryState(
              icon: Icons.cloud_off_outlined,
              title: 'Templates unavailable',
              body: error.toString(),
            ),
            data: (templates) => templates.isEmpty
                ? _LibraryState(
                    icon: Icons.library_books_outlined,
                    title: 'No templates',
                    body: 'Create phased templates for repeatable delivery.',
                    actionLabel: 'Create template',
                    onTap: () => _openTemplateSheet(context, ref),
                  )
                : Column(
                    children: templates
                        .map(
                          (template) => _LibraryTile(
                            icon: Icons.view_week_outlined,
                            title: template.title,
                            subtitle:
                                '${template.goalType.replaceAll('_', ' ')} · ${template.durationWeeks} weeks · ${template.difficultyLevel}',
                            trailing: template.isSystem
                                ? 'System'
                                : 'Coach-owned',
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Exercises',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openExerciseSheet(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Exercise'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          exercisesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _LibraryState(
              icon: Icons.cloud_off_outlined,
              title: 'Exercises unavailable',
              body: error.toString(),
            ),
            data: (exercises) => exercises.isEmpty
                ? _LibraryState(
                    icon: Icons.fitness_center_outlined,
                    title: 'No exercises',
                    body:
                        'Add exercises with instructions, rest, substitutions, and progression rules.',
                    actionLabel: 'Add exercise',
                    onTap: () => _openExerciseSheet(context, ref),
                  )
                : Column(
                    children: exercises
                        .take(30)
                        .map((exercise) {
                          final subtitleParts = <String>[
                            exercise.category,
                            if (exercise.equipmentTags.isNotEmpty)
                              exercise.equipmentTags.join(', '),
                            if (exercise.restGuidanceSeconds != null)
                              '${exercise.restGuidanceSeconds}s rest',
                            if (exercise.progressionRule.isNotEmpty)
                              'progression set',
                          ];
                          return _LibraryTile(
                            icon: Icons.fitness_center_outlined,
                            title: exercise.title,
                            subtitle: subtitleParts.join(' · '),
                            trailing: exercise.isSystem ? 'System' : 'Coach',
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );

    if (embedded) return content;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Library'),
        backgroundColor: AppColors.background,
      ),
      body: content,
    );
  }

  Future<void> _openTemplateSheet(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController(
      text: 'Custom coaching block',
    );
    final descriptionController = TextEditingController();
    final weeksController = TextEditingController(text: '4');
    final tagsController = TextEditingController(
      text: 'phased, accountability',
    );
    String goal = 'general_fitness';
    String difficulty = 'beginner';
    String location = 'online';

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
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHeader(title: 'Program template'),
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
                initialValue: goal,
                decoration: const InputDecoration(labelText: 'Goal'),
                items: const [
                  DropdownMenuItem(value: 'fat_loss', child: Text('Fat loss')),
                  DropdownMenuItem(
                    value: 'muscle_gain',
                    child: Text('Muscle gain'),
                  ),
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(
                    value: 'general_fitness',
                    child: Text('General fitness'),
                  ),
                  DropdownMenuItem(
                    value: 'home_training',
                    child: Text('Home training'),
                  ),
                  DropdownMenuItem(
                    value: 'women_coaching',
                    child: Text('Women coaching'),
                  ),
                  DropdownMenuItem(
                    value: 'ramadan_lifestyle',
                    child: Text('Ramadan lifestyle'),
                  ),
                ],
                onChanged: (value) =>
                    setSheetState(() => goal = value ?? 'general_fitness'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: weeksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Weeks'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'beginner',
                          child: Text('Beginner'),
                        ),
                        DropdownMenuItem(
                          value: 'intermediate',
                          child: Text('Intermediate'),
                        ),
                        DropdownMenuItem(
                          value: 'advanced',
                          child: Text('Advanced'),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => difficulty = value ?? 'beginner'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: location,
                decoration: const InputDecoration(labelText: 'Location'),
                items: const [
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'home', child: Text('Home')),
                  DropdownMenuItem(value: 'gym', child: Text('Gym')),
                  DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                ],
                onChanged: (value) =>
                    setSheetState(() => location = value ?? 'online'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'fat loss, beginner, high accountability',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final weekCount = int.tryParse(weeksController.text) ?? 4;
                    await ref
                        .read(coachRepositoryProvider)
                        .saveProgramTemplate(
                          title: titleController.text.trim(),
                          goalType: goal,
                          description: descriptionController.text.trim(),
                          durationWeeks: weekCount,
                          difficultyLevel: difficulty,
                          locationMode: location,
                          weeklyStructure: List<Map<String, dynamic>>.generate(
                            weekCount,
                            (index) => <String, dynamic>{
                              'week': index + 1,
                              'focus': goal,
                              'block_title': 'Block ${index + 1}',
                              'sessions': const <Map<String, dynamic>>[
                                <String, dynamic>{
                                  'day': 'Day 1',
                                  'goal': 'Primary strength work',
                                },
                                <String, dynamic>{
                                  'day': 'Day 2',
                                  'goal': 'Conditioning and recovery',
                                },
                              ],
                            },
                          ),
                          tags: _tags(tagsController.text),
                        );
                    ref.invalidate(coachProgramTemplatesProvider);
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
    descriptionController.dispose();
    weeksController.dispose();
    tagsController.dispose();
  }

  Future<void> _openExerciseSheet(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final instructionsController = TextEditingController();
    final progressionController = TextEditingController();
    final regressionController = TextEditingController();
    final videoController = TextEditingController();
    final equipmentController = TextEditingController();
    final musclesController = TextEditingController();
    final restController = TextEditingController(text: '90');
    String category = 'strength';
    String difficulty = 'beginner';

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
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHeader(title: 'Exercise'),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: instructionsController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Coach instructions',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(
                          value: 'strength',
                          child: Text('Strength'),
                        ),
                        DropdownMenuItem(
                          value: 'cardio',
                          child: Text('Cardio'),
                        ),
                        DropdownMenuItem(
                          value: 'mobility',
                          child: Text('Mobility'),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => category = value ?? 'strength'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'beginner',
                          child: Text('Beginner'),
                        ),
                        DropdownMenuItem(
                          value: 'intermediate',
                          child: Text('Intermediate'),
                        ),
                        DropdownMenuItem(
                          value: 'advanced',
                          child: Text('Advanced'),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => difficulty = value ?? 'beginner'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: musclesController,
                decoration: const InputDecoration(
                  labelText: 'Primary muscles',
                  hintText: 'quads, glutes',
                ),
              ),
              TextField(
                controller: equipmentController,
                decoration: const InputDecoration(
                  labelText: 'Equipment tags',
                  hintText: 'dumbbell, bench',
                ),
              ),
              TextField(
                controller: progressionController,
                decoration: const InputDecoration(
                  labelText: 'Progression rule',
                ),
              ),
              TextField(
                controller: regressionController,
                decoration: const InputDecoration(
                  labelText: 'Regression or substitution',
                ),
              ),
              TextField(
                controller: videoController,
                decoration: const InputDecoration(labelText: 'Video URL'),
              ),
              TextField(
                controller: restController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rest seconds'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(coachRepositoryProvider)
                        .saveExercise(
                          title: titleController.text.trim(),
                          category: category,
                          difficultyLevel: difficulty,
                          primaryMuscles: _tags(musclesController.text),
                          equipmentTags: _tags(equipmentController.text),
                          instructions: instructionsController.text.trim(),
                          videoUrl: _textOrNull(videoController.text),
                          progressionRule: progressionController.text.trim(),
                          regressionRule: regressionController.text.trim(),
                          substitutions:
                              regressionController.text.trim().isEmpty
                              ? const <dynamic>[]
                              : <Map<String, dynamic>>[
                                  <String, dynamic>{
                                    'title': regressionController.text.trim(),
                                  },
                                ],
                          restGuidanceSeconds: int.tryParse(
                            restController.text.trim(),
                          ),
                          cues: const <Map<String, dynamic>>[
                            <String, dynamic>{'type': 'tempo'},
                          ],
                        );
                    ref.invalidate(coachExercisesProvider);
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
    instructionsController.dispose();
    progressionController.dispose();
    regressionController.dispose();
    videoController.dispose();
    equipmentController.dispose();
    musclesController.dispose();
    restController.dispose();
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
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
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

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
          Icon(icon, color: AppColors.orange),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: GoogleFonts.inter(fontSize: 11)),
        ],
      ),
    );
  }
}

class _LibraryState extends StatelessWidget {
  const _LibraryState({
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
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
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

String? _textOrNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
