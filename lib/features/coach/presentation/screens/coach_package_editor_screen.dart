import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/offer_preview_factory.dart';
import '../providers/coach_providers.dart';

class CoachPackageEditorScreen extends ConsumerStatefulWidget {
  const CoachPackageEditorScreen({super.key, this.initialPackage});

  final CoachPackageEntity? initialPackage;

  @override
  ConsumerState<CoachPackageEditorScreen> createState() =>
      _CoachPackageEditorScreenState();
}

class _CoachPackageEditorScreenState
    extends ConsumerState<CoachPackageEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _outcomeController = TextEditingController();
  final _idealForController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _featuresController = TextEditingController();
  final _supportController = TextEditingController();
  final _summaryForMemberController = TextEditingController();
  late final List<_FaqDraft> _faqDrafts;

  late int _durationWeeks;
  late int _sessionsPerWeek;
  late int _weeklyCheckinsIncluded;
  late int _feedbackSlaHours;
  late int _initialPlanSlaHours;
  late int _sessionCountPerMonth;
  late String _billingCycle;
  late String _difficultyLevel;
  late String _checkInFrequency;
  late String _visibilityStatus;
  late bool _workoutPlanIncluded;
  late bool _nutritionGuidanceIncluded;
  late bool _habitsIncluded;
  late bool _resourcesIncluded;
  late bool _sessionsIncluded;
  late bool _monthlyReviewIncluded;
  bool _isSaving = false;

  static const _billingCycles = <String>[
    'weekly',
    'monthly',
    'quarterly',
    'one_time',
  ];
  static const _difficultyLevels = <String>[
    'beginner',
    'intermediate',
    'advanced',
  ];
  static const _checkInFrequencies = <String>[
    'Weekly',
    'Twice weekly',
    'Biweekly',
    'Monthly',
    'As needed',
  ];
  static const _visibilityStates = <String>['draft', 'published', 'archived'];

  @override
  void initState() {
    super.initState();
    final package = widget.initialPackage;
    _titleController.text = package?.title ?? '';
    _subtitleController.text = package?.subtitle ?? '';
    _priceController.text = package == null
        ? ''
        : package.price.toStringAsFixed(
            package.price.truncateToDouble() == package.price ? 0 : 2,
          );
    _descriptionController.text = package?.description ?? '';
    _outcomeController.text = package?.outcomeSummary ?? '';
    _idealForController.text = package?.idealFor.join(', ') ?? '';
    _equipmentController.text = package?.equipmentTags.join(', ') ?? '';
    _featuresController.text = package?.includedFeatures.join('\n') ?? '';
    _supportController.text = package?.supportSummary ?? '';
    _summaryForMemberController.text = package?.packageSummaryForMember ?? '';
    _durationWeeks = package?.durationWeeks ?? 4;
    _sessionsPerWeek = package?.sessionsPerWeek ?? 3;
    _weeklyCheckinsIncluded = package?.weeklyCheckinsIncluded ?? 1;
    _feedbackSlaHours = package?.feedbackSlaHours ?? 24;
    _initialPlanSlaHours = package?.initialPlanSlaHours ?? 48;
    _sessionCountPerMonth = package?.sessionCountPerMonth ?? 0;
    _billingCycle = package?.billingCycle ?? 'monthly';
    _difficultyLevel = package?.difficultyLevel ?? 'beginner';
    _checkInFrequency = package?.checkInFrequency.isNotEmpty == true
        ? package!.checkInFrequency
        : 'Weekly';
    _visibilityStatus = package?.visibilityStatus ?? 'published';
    _workoutPlanIncluded = package?.workoutPlanIncluded ?? true;
    _nutritionGuidanceIncluded = package?.nutritionGuidanceIncluded ?? false;
    _habitsIncluded = package?.habitsIncluded ?? true;
    _resourcesIncluded = package?.resourcesIncluded ?? true;
    _sessionsIncluded = package?.sessionsIncluded ?? false;
    _monthlyReviewIncluded = package?.monthlyReviewIncluded ?? false;
    _faqDrafts = (package?.faqItems ?? const <CoachPackageFaqEntity>[])
        .map((faq) => _FaqDraft(question: faq.question, answer: faq.answer))
        .toList(growable: true);
    if (_faqDrafts.isEmpty) {
      _faqDrafts.add(_FaqDraft());
    }
    for (final controller in <TextEditingController>[
      _titleController,
      _descriptionController,
      _outcomeController,
      _equipmentController,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _titleController,
      _descriptionController,
      _outcomeController,
      _equipmentController,
    ]) {
      controller.removeListener(_refreshPreview);
    }
    _titleController.dispose();
    _subtitleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _outcomeController.dispose();
    _idealForController.dispose();
    _equipmentController.dispose();
    _featuresController.dispose();
    _supportController.dispose();
    _summaryForMemberController.dispose();
    for (final faq in _faqDrafts) {
      faq.dispose();
    }
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = buildCoachOfferPlanPreview(
      title: _titleController.text.trim().isEmpty
          ? 'Coach Starter Plan'
          : _titleController.text.trim(),
      summary: _outcomeController.text.trim().isEmpty
          ? _descriptionController.text.trim()
          : _outcomeController.text.trim(),
      durationWeeks: _durationWeeks,
      sessionsPerWeek: _sessionsPerWeek,
      difficultyLevel: _difficultyLevel,
      equipmentTags: _splitList(_equipmentController.text),
    );
    final previewWeeks =
        preview['weekly_structure'] as List<dynamic>? ?? const <dynamic>[];
    final previewDays = previewWeeks.isEmpty
        ? const <dynamic>[]
        : ((previewWeeks.first as Map<String, dynamic>)['days']
                  as List<dynamic>? ??
              const <dynamic>[]);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppShellBackground(
          topGlowColor: AppColors.glowOrange,
          bottomGlowColor: AppColors.glowBlue,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.xl,
                AppSizes.screenPadding,
                120,
              ),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.initialPackage == null
                                ? 'Create coaching offer'
                                : 'Edit coaching offer',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Build a storefront-ready offer with a visible starter plan preview and clear support promise.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xl),
                _section(
                  'Basics',
                  'Public-facing identity, pricing, and billing.',
                  [
                    _field(
                      controller: _titleController,
                      label: 'Offer title',
                      hint: '12-week strength coaching',
                      validator: _required,
                    ),
                    const SizedBox(height: AppSizes.md),
                    _field(
                      controller: _subtitleController,
                      label: 'Subtitle',
                      hint: 'Remote accountability for busy lifters',
                    ),
                    const SizedBox(height: AppSizes.md),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _priceController,
                            label: 'Price',
                            hint: '249',
                            validator: _priceValidator,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: _dropdown(
                            label: 'Billing cycle',
                            value: _billingCycle,
                            values: _billingCycles,
                            onChanged: (value) =>
                                setState(() => _billingCycle = value),
                            labelBuilder: _titleize,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    _field(
                      controller: _descriptionController,
                      label: 'Description',
                      hint:
                          'Explain how the coaching relationship works and what the member receives.',
                      minLines: 4,
                      maxLines: 6,
                      validator: _required,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                _section(
                  'Offer Promise',
                  'Clarify the outcome, best-fit member, and support style.',
                  [
                    _field(
                      controller: _outcomeController,
                      label: 'Outcome summary',
                      hint:
                          'Build consistency, confidence, and measurable progress.',
                      minLines: 3,
                      maxLines: 5,
                      validator: _required,
                    ),
                    const SizedBox(height: AppSizes.md),
                    _field(
                      controller: _idealForController,
                      label: 'Ideal for',
                      hint: 'Beginners, fat loss, gym returners',
                    ),
                    const SizedBox(height: AppSizes.md),
                    Row(
                      children: [
                        Expanded(
                          child: _dropdown(
                            label: 'Check-in frequency',
                            value: _checkInFrequency,
                            values: _checkInFrequencies,
                            onChanged: (value) =>
                                setState(() => _checkInFrequency = value),
                            labelBuilder: (value) => value,
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: _dropdown(
                            label: 'Difficulty',
                            value: _difficultyLevel,
                            values: _difficultyLevels,
                            onChanged: (value) =>
                                setState(() => _difficultyLevel = value),
                            labelBuilder: _titleize,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    _field(
                      controller: _supportController,
                      label: 'Support summary',
                      hint:
                          'What accountability, adjustments, and ongoing support are included?',
                      minLines: 3,
                      maxLines: 5,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                _section(
                  'Service Contract',
                  'Set the measurable coaching promises members see before subscribing.',
                  [
                    Row(
                      children: [
                        Expanded(
                          child: _stepper(
                            'Weekly check-ins',
                            _weeklyCheckinsIncluded,
                            0,
                            7,
                            (value) =>
                                setState(() => _weeklyCheckinsIncluded = value),
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: _stepper(
                            'Sessions / month',
                            _sessionCountPerMonth,
                            0,
                            20,
                            (value) => setState(() {
                              _sessionCountPerMonth = value;
                              _sessionsIncluded = value > 0;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    Row(
                      children: [
                        Expanded(
                          child: _stepper(
                            'Feedback SLA (hours)',
                            _feedbackSlaHours,
                            1,
                            168,
                            (value) =>
                                setState(() => _feedbackSlaHours = value),
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: _stepper(
                            'Initial plan SLA',
                            _initialPlanSlaHours,
                            1,
                            168,
                            (value) =>
                                setState(() => _initialPlanSlaHours = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    _deliverableSwitch(
                      'Workout plan included',
                      _workoutPlanIncluded,
                      (value) => setState(() => _workoutPlanIncluded = value),
                    ),
                    _deliverableSwitch(
                      'Nutrition guidance included',
                      _nutritionGuidanceIncluded,
                      (value) =>
                          setState(() => _nutritionGuidanceIncluded = value),
                    ),
                    _deliverableSwitch(
                      'Coach-assigned habits included',
                      _habitsIncluded,
                      (value) => setState(() => _habitsIncluded = value),
                    ),
                    _deliverableSwitch(
                      'Coach resources included',
                      _resourcesIncluded,
                      (value) => setState(() => _resourcesIncluded = value),
                    ),
                    _deliverableSwitch(
                      'Monthly review included',
                      _monthlyReviewIncluded,
                      (value) => setState(() => _monthlyReviewIncluded = value),
                    ),
                    const SizedBox(height: AppSizes.md),
                    _field(
                      controller: _summaryForMemberController,
                      label: 'Member-facing package summary',
                      hint:
                          'Weekly plan, habit targets, check-in feedback within 24h, and monthly progress review.',
                      minLines: 3,
                      maxLines: 5,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                _section(
                  'Plan Preview',
                  'This becomes the starter plan members inspect before they subscribe.',
                  [
                    Row(
                      children: [
                        Expanded(
                          child: _stepper(
                            'Duration (weeks)',
                            _durationWeeks,
                            1,
                            16,
                            (value) => setState(() => _durationWeeks = value),
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: _stepper(
                            'Sessions / week',
                            _sessionsPerWeek,
                            1,
                            7,
                            (value) => setState(() => _sessionsPerWeek = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    _field(
                      controller: _equipmentController,
                      label: 'Equipment tags',
                      hint: 'Dumbbells, barbell, bands, bodyweight',
                    ),
                    const SizedBox(height: AppSizes.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSizes.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Starter plan preview',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          Wrap(
                            spacing: AppSizes.sm,
                            runSpacing: AppSizes.sm,
                            children: [
                              _previewChip('$_durationWeeks weeks'),
                              _previewChip('$_sessionsPerWeek sessions / week'),
                              _previewChip(_titleize(_difficultyLevel)),
                              _previewChip('$_checkInFrequency check-ins'),
                            ],
                          ),
                          const SizedBox(height: AppSizes.md),
                          ...previewDays
                              .take(3)
                              .map(
                                (day) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSizes.sm,
                                  ),
                                  child: Text(
                                    '${day['label'] ?? 'Session'}: ${day['focus'] ?? 'Workout'}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                _section(
                  'What Is Included',
                  'List the member-facing features one per line.',
                  [
                    _field(
                      controller: _featuresController,
                      label: 'Included features',
                      hint:
                          'Weekly program adjustments\nForm review\nProgress check-ins',
                      minLines: 5,
                      maxLines: 8,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                _section(
                  'FAQ',
                  'Answer the objections that typically block a subscription decision.',
                  [
                    for (var index = 0; index < _faqDrafts.length; index++) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSizes.md),
                        decoration: BoxDecoration(
                          color: AppColors.fieldFill,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusLg,
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'FAQ ${index + 1}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                if (_faqDrafts.length > 1)
                                  IconButton(
                                    onPressed: () => setState(() {
                                      final draft = _faqDrafts.removeAt(index);
                                      draft.dispose();
                                    }),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                            _field(
                              controller: _faqDrafts[index].questionController,
                              label: 'Question',
                              hint: 'Who is this coaching offer best for?',
                            ),
                            const SizedBox(height: AppSizes.md),
                            _field(
                              controller: _faqDrafts[index].answerController,
                              label: 'Answer',
                              hint:
                                  'Explain the fit, commitment, or delivery details.',
                              minLines: 3,
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                      if (index != _faqDrafts.length - 1)
                        const SizedBox(height: AppSizes.md),
                    ],
                    const SizedBox(height: AppSizes.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _faqDrafts.add(_FaqDraft())),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Add FAQ item'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                _section(
                  'Publish Settings',
                  'Draft offers stay private. Published offers appear in the marketplace.',
                  [
                    Wrap(
                      spacing: AppSizes.sm,
                      runSpacing: AppSizes.sm,
                      children: _visibilityStates
                          .map(
                            (status) => ChoiceChip(
                              label: Text(_titleize(status)),
                              selected: _visibilityStatus == status,
                              onSelected: (_) =>
                                  setState(() => _visibilityStatus = status),
                              backgroundColor: AppColors.fieldFill,
                              selectedColor: _statusColor(
                                status,
                              ).withValues(alpha: 0.16),
                              side: BorderSide(
                                color: _visibilityStatus == status
                                    ? _statusColor(status)
                                    : AppColors.border,
                              ),
                              labelStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: _visibilityStatus == status
                                    ? _statusColor(status)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : widget.initialPackage == null
                          ? 'Create offer'
                          : 'Update offer',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String subtitle, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          color: AppColors.cardDark.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            ...children,
          ],
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.inter(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.fieldFill,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(color: AppColors.orange),
        errorBorder: _border(color: AppColors.error),
        focusedErrorBorder: _border(color: AppColors.error),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    required String Function(String value) labelBuilder,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
      dropdownColor: AppColors.surfaceRaised,
      style: GoogleFonts.inter(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.fieldFill,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(color: AppColors.orange),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(labelBuilder(item)),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _stepper(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) => Container(
    padding: const EdgeInsets.all(AppSizes.md),
    decoration: BoxDecoration(
      color: AppColors.fieldFill,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Row(
          children: [
            IconButton(
              onPressed: value <= min ? null : () => onChanged(value - 1),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Expanded(
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: value >= max ? null : () => onChanged(value + 1),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _previewChip(String label) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSizes.md,
      vertical: AppSizes.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _deliverableSwitch(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      value: value,
      activeThumbColor: AppColors.orange,
      onChanged: onChanged,
    );
  }

  OutlineInputBorder _border({Color color = AppColors.border}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        borderSide: BorderSide(color: color),
      );

  Future<void> _saveOffer() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final outcome = _outcomeController.text.trim();
      final equipmentTags = _splitList(_equipmentController.text);
      final faqItems = _faqDrafts
          .map(
            (draft) => CoachPackageFaqEntity(
              question: draft.questionController.text.trim(),
              answer: draft.answerController.text.trim(),
            ),
          )
          .where((faq) => faq.question.isNotEmpty && faq.answer.isNotEmpty)
          .toList(growable: false);

      await ref
          .read(coachRepositoryProvider)
          .saveCoachPackage(
            packageId: widget.initialPackage?.id,
            title: title,
            subtitle: _subtitleController.text.trim(),
            description: description,
            billingCycle: _billingCycle,
            price: double.parse(_priceController.text.trim()),
            outcomeSummary: outcome,
            idealFor: _splitList(_idealForController.text),
            durationWeeks: _durationWeeks,
            sessionsPerWeek: _sessionsPerWeek,
            difficultyLevel: _difficultyLevel,
            equipmentTags: equipmentTags,
            includedFeatures: _splitList(_featuresController.text),
            checkInFrequency: _checkInFrequency,
            supportSummary: _supportController.text.trim(),
            faqItems: faqItems,
            planPreviewJson: buildCoachOfferPlanPreview(
              title: title,
              summary: outcome.isEmpty ? description : outcome,
              durationWeeks: _durationWeeks,
              sessionsPerWeek: _sessionsPerWeek,
              difficultyLevel: _difficultyLevel,
              equipmentTags: equipmentTags,
            ),
            visibilityStatus: _visibilityStatus,
            isActive: _visibilityStatus == 'published',
            weeklyCheckinsIncluded: _weeklyCheckinsIncluded,
            feedbackSlaHours: _feedbackSlaHours,
            initialPlanSlaHours: _initialPlanSlaHours,
            workoutPlanIncluded: _workoutPlanIncluded,
            nutritionGuidanceIncluded: _nutritionGuidanceIncluded,
            habitsIncluded: _habitsIncluded,
            resourcesIncluded: _resourcesIncluded,
            sessionsIncluded: _sessionsIncluded || _sessionCountPerMonth > 0,
            monthlyReviewIncluded: _monthlyReviewIncluded,
            sessionCountPerMonth: _sessionCountPerMonth,
            packageSummaryForMember: _summaryForMemberController.text.trim(),
          );

      ref.invalidate(coachPackagesProvider);
      ref.invalidate(coachDashboardSummaryProvider);
      ref.invalidate(coachProfileProvider);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _visibilityStatus == 'published'
                ? 'Offer saved and published.'
                : 'Offer saved as ${_titleize(_visibilityStatus).toLowerCase()}.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _isSaving = false);
      return;
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'This field is required' : null;

  String? _priceValidator(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) {
      return 'Enter a valid price';
    }
    return null;
  }

  List<String> _splitList(String raw) => raw
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  String _titleize(String value) => value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');

  Color _statusColor(String value) {
    switch (value) {
      case 'published':
        return AppColors.limeGreen;
      case 'archived':
        return AppColors.textMuted;
      default:
        return AppColors.orangeLight;
    }
  }
}

class _FaqDraft {
  _FaqDraft({String question = '', String answer = ''})
    : questionController = TextEditingController(text: question),
      answerController = TextEditingController(text: answer);

  final TextEditingController questionController;
  final TextEditingController answerController;

  void dispose() {
    questionController.dispose();
    answerController.dispose();
  }
}
