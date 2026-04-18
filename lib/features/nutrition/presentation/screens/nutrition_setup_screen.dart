import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../controllers/nutrition_setup_controller.dart';
import '../widgets/nutrition_widgets.dart';

class NutritionSetupScreen extends ConsumerStatefulWidget {
  const NutritionSetupScreen({super.key});

  @override
  ConsumerState<NutritionSetupScreen> createState() =>
      _NutritionSetupScreenState();
}

class _NutritionSetupScreenState extends ConsumerState<NutritionSetupScreen> {
  bool _started = false;
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    Future.microtask(
      () => ref.read(nutritionSetupControllerProvider.notifier).start(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nutritionSetupControllerProvider, (previous, next) {
      if (next.completed && !_navigated) {
        _navigated = true;
        Navigator.pushReplacementNamed(context, AppRoutes.nutrition);
      }
      if ((next.errorMessage ?? '').isNotEmpty &&
          previous?.errorMessage != next.errorMessage) {
        showAppFeedback(context, next.errorMessage!);
      }
    });

    final state = ref.watch(nutritionSetupControllerProvider);
    final controller = ref.read(nutritionSetupControllerProvider.notifier);
    final question = state.currentQuestion;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nutrition setup')),
      body: AppShellBackground(
        child: SafeArea(
          child: state.loading || question == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(AppSizes.screenPadding),
                  children: [
                    NutritionSetupQuestionCard(
                      question: question,
                      answer: state.answers[question.field],
                      progressLabel:
                          'Step ${state.stepNumber} of ${state.totalSteps}',
                      progress: state.progress,
                      onChanged: controller.answerCurrent,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (state.canGoBack)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: state.generating
                                  ? null
                                  : controller.back,
                              child: const Text('Back'),
                            ),
                          ),
                        if (state.canGoBack) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            key: const ValueKey('nutrition-setup-next'),
                            onPressed: !state.canGoNext || state.generating
                                ? null
                                : state.isLastStep
                                ? controller.finish
                                : controller.next,
                            child: Text(
                              state.generating
                                  ? 'Building plan...'
                                  : state.isLastStep
                                  ? 'Generate plan'
                                  : 'Next',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
