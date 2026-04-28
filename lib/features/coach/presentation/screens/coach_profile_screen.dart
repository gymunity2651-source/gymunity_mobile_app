import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/coach_entity.dart';
import '../providers/coach_providers.dart';

class CoachProfileScreen extends ConsumerStatefulWidget {
  const CoachProfileScreen({super.key});

  @override
  ConsumerState<CoachProfileScreen> createState() => _CoachProfileScreenState();
}

class _CoachProfileScreenState extends ConsumerState<CoachProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _headlineController = TextEditingController();
  final _positioningController = TextEditingController();
  final _serviceSummaryController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _cityController = TextEditingController();
  final _responseSlaController = TextEditingController();
  final _trialPriceController = TextEditingController();

  String _deliveryMode = 'online';
  String? _coachGender;
  bool _remoteOnly = false;
  bool _trialOfferEnabled = false;
  List<String> _specialties = <String>[];
  List<String> _languages = <String>[];
  bool _seeded = false;
  bool _isSaving = false;

  final _specialtyController = TextEditingController();
  final _languageController = TextEditingController();

  static const _deliveryModes = <String, String>{
    'online': 'Online',
    'in_person': 'In-Person',
    'hybrid': 'Hybrid',
  };

  static const _genderOptions = <String, String>{
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
  };

  @override
  void dispose() {
    _bioController.dispose();
    _headlineController.dispose();
    _positioningController.dispose();
    _serviceSummaryController.dispose();
    _yearsExperienceController.dispose();
    _hourlyRateController.dispose();
    _cityController.dispose();
    _responseSlaController.dispose();
    _trialPriceController.dispose();
    _specialtyController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(coachProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Coach Profile'),
        actions: [
          if (profileAsync.valueOrNull != null)
            IconButton(
              tooltip: 'Preview public profile',
              onPressed: () {
                final profile = profileAsync.valueOrNull;
                if (profile != null) {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.coachDetails,
                    arguments: profile,
                  );
                }
              },
              icon: const Icon(Icons.public_rounded),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (error, stackTrace) => _ErrorState(
          message: 'GymUnity could not load your coach profile right now.',
          onRetry: () => ref.invalidate(coachProfileProvider),
        ),
        data: (profile) {
          _seedControllers(profile);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              children: [
                _CompletenessCard(profile: profile),
                const SizedBox(height: AppSizes.xxl),

                // ── Identity Section ──
                _SectionHeader(
                  title: 'Identity',
                  subtitle: 'How members see you in the marketplace.',
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _headlineController,
                  label: 'Headline',
                  hint: 'Strength coach for busy professionals',
                  maxLines: 1,
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _positioningController,
                  label: 'Positioning Statement',
                  hint:
                      'What makes your coaching approach specific and credible',
                  maxLines: 3,
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _bioController,
                  label: 'Bio',
                  hint: 'Share your coaching philosophy and background...',
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bio is required for your public profile.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _serviceSummaryController,
                  label: 'Service Summary',
                  hint: 'A one-liner about your coaching offer',
                  maxLines: 2,
                ),
                const SizedBox(height: AppSizes.xxl),

                // ── Expertise Section ──
                _SectionHeader(
                  title: 'Expertise',
                  subtitle: 'Your skills and coaching style.',
                ),
                const SizedBox(height: AppSizes.md),
                _ChipInputField(
                  label: 'Specialties',
                  chips: _specialties,
                  controller: _specialtyController,
                  onAdd: (value) {
                    if (value.trim().isNotEmpty &&
                        !_specialties.contains(value.trim())) {
                      setState(
                        () => _specialties = [..._specialties, value.trim()],
                      );
                    }
                  },
                  onRemove: (value) {
                    setState(
                      () => _specialties = _specialties
                          .where((s) => s != value)
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _yearsExperienceController,
                  label: 'Years of Experience',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Years of experience is required.';
                    }
                    if (int.tryParse(value.trim()) == null) {
                      return 'Enter a valid number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.md),
                _DropdownField<String>(
                  label: 'Delivery Mode',
                  value: _deliveryMode,
                  items: _deliveryModes.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _deliveryMode = value);
                    }
                  },
                ),
                const SizedBox(height: AppSizes.xxl),

                // ── Pricing Section ──
                _SectionHeader(
                  title: 'Pricing',
                  subtitle: 'Rates visible on your public profile.',
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _hourlyRateController,
                  label: 'Hourly Rate (EGP)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Hourly rate is required.';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Enter a valid amount.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.md),
                SwitchListTile.adaptive(
                  title: Text(
                    'Offer Trial Period',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Let members try a 7-day reduced-price trial.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: _trialOfferEnabled,
                  activeTrackColor: AppColors.orange,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() => _trialOfferEnabled = value);
                  },
                ),
                if (_trialOfferEnabled) ...[
                  const SizedBox(height: AppSizes.sm),
                  _FormField(
                    controller: _trialPriceController,
                    label: 'Trial Price (EGP)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.xxl),

                // ── Location Section ──
                _SectionHeader(
                  title: 'Location & Reach',
                  subtitle: 'Where and how you coach.',
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _cityController,
                  label: 'City',
                  hint: 'Cairo, Alexandria, etc.',
                ),
                const SizedBox(height: AppSizes.md),
                SwitchListTile.adaptive(
                  title: Text(
                    'Remote Only',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Only available for online coaching.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: _remoteOnly,
                  activeTrackColor: AppColors.orange,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() => _remoteOnly = value);
                  },
                ),
                const SizedBox(height: AppSizes.md),
                _ChipInputField(
                  label: 'Languages',
                  chips: _languages,
                  controller: _languageController,
                  onAdd: (value) {
                    if (value.trim().isNotEmpty &&
                        !_languages.contains(value.trim())) {
                      setState(
                        () => _languages = [..._languages, value.trim()],
                      );
                    }
                  },
                  onRemove: (value) {
                    setState(
                      () => _languages = _languages
                          .where((l) => l != value)
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSizes.xxl),

                // ── Preferences Section ──
                _SectionHeader(
                  title: 'Preferences',
                  subtitle: 'Optional details for discovery filtering.',
                ),
                const SizedBox(height: AppSizes.md),
                _DropdownField<String?>(
                  label: 'Coach Gender',
                  value: _coachGender,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Prefer not to say'),
                    ),
                    ..._genderOptions.entries.map(
                      (entry) => DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _coachGender = value);
                  },
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _responseSlaController,
                  label: 'Response Time (hours)',
                  hint: 'How quickly you typically reply',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSizes.xxxl),

                // ── Save Button ──
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    child: Text(
                      _isSaving ? 'Saving...' : 'Save Coach Profile',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  void _seedControllers(CoachEntity? profile) {
    if (_seeded) {
      return;
    }
    _seeded = true;
    _bioController.text = profile?.bio ?? '';
    _headlineController.text = profile?.headline ?? '';
    _positioningController.text = profile?.positioningStatement ?? '';
    _serviceSummaryController.text = profile?.serviceSummary ?? '';
    _yearsExperienceController.text =
        profile?.yearsExperience.toString() ?? '0';
    _hourlyRateController.text = profile?.hourlyRate.toString() ?? '0';
    _cityController.text = profile?.city ?? '';
    _responseSlaController.text = profile?.responseSlaHours.toString() ?? '12';
    _trialPriceController.text = profile?.trialPriceEgp.toString() ?? '0';
    _deliveryMode = profile?.deliveryMode ?? 'online';
    _coachGender = profile?.coachGender;
    _remoteOnly = profile?.remoteOnly ?? false;
    _trialOfferEnabled = profile?.trialOfferEnabled ?? false;
    _specialties = List<String>.from(profile?.specialties ?? <String>[]);
    _languages = List<String>.from(profile?.languages ?? <String>[]);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(coachRepositoryProvider)
          .upsertCoachProfile(
            bio: _bioController.text.trim(),
            specialties: _specialties,
            yearsExperience:
                int.tryParse(_yearsExperienceController.text.trim()) ?? 0,
            hourlyRate: double.tryParse(_hourlyRateController.text.trim()) ?? 0,
            deliveryMode: _deliveryMode,
            serviceSummary: _serviceSummaryController.text.trim(),
            city: _cityController.text.trim().isEmpty
                ? null
                : _cityController.text.trim(),
            languages: _languages,
            coachGender: _coachGender,
            responseSlaHours:
                int.tryParse(_responseSlaController.text.trim()) ?? 12,
            trialOfferEnabled: _trialOfferEnabled,
            trialPriceEgp:
                double.tryParse(_trialPriceController.text.trim()) ?? 0,
            remoteOnly: _remoteOnly,
            headline: _headlineController.text.trim(),
            positioningStatement: _positioningController.text.trim(),
          );
      ref.invalidate(coachProfileProvider);
      ref.invalidate(coachDashboardSummaryProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coach profile updated successfully.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────

class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.profile});

  final CoachEntity? profile;

  @override
  Widget build(BuildContext context) {
    final checks = <String, bool>{
      'Bio': profile?.bio.trim().isNotEmpty == true,
      'Headline': profile?.headline.trim().isNotEmpty == true,
      'Specialties': profile?.specialties.isNotEmpty == true,
      'Experience': (profile?.yearsExperience ?? 0) > 0,
      'Hourly rate': (profile?.hourlyRate ?? 0) > 0,
      'Service summary': profile?.serviceSummary.trim().isNotEmpty == true,
      'Delivery mode': profile?.deliveryMode?.trim().isNotEmpty == true,
    };
    final completed = checks.values.where((v) => v).length;
    final total = checks.length;
    final fraction = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fraction >= 1.0
                    ? Icons.check_circle_rounded
                    : Icons.person_outline,
                color: fraction >= 1.0 ? AppColors.success : AppColors.orange,
                size: 28,
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fraction >= 1.0
                          ? 'Profile complete'
                          : 'Complete your coaching profile',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completed of $total key fields filled',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                fraction >= 1.0 ? AppColors.success : AppColors.orange,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: checks.entries.map((entry) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    entry.value
                        ? Icons.check_circle_outline_rounded
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: entry.value
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.key,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: entry.value
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          dropdownColor: AppColors.surfaceRaised,
        ),
      ),
    );
  }
}

class _ChipInputField extends StatelessWidget {
  const _ChipInputField({
    required this.label,
    required this.chips,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final List<String> chips;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: 'Type and press +',
                  isDense: true,
                ),
                onSubmitted: (value) {
                  onAdd(value);
                  controller.clear();
                },
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            IconButton(
              onPressed: () {
                onAdd(controller.text);
                controller.clear();
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: AppColors.orange,
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: chips
                .map(
                  (chip) => Chip(
                    label: Text(chip),
                    onDeleted: () => onRemove(chip),
                    deleteIconColor: AppColors.textMuted,
                    backgroundColor: AppColors.cardDark,
                    side: BorderSide(color: AppColors.border),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
