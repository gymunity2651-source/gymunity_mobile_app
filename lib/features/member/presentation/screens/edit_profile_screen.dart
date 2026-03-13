import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../user/domain/entities/profile_entity.dart';
import '../providers/member_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _goalController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _experienceController = TextEditingController();
  bool _seeded = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _goalController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _frequencyController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final memberAsync = ref.watch(memberProfileDetailsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Edit Profile'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _RetryState(
          message: 'GymUnity could not load your profile right now.',
          onRetry: () {
            ref.invalidate(currentUserProfileProvider);
            ref.invalidate(memberProfileDetailsProvider);
          },
        ),
        data: (profile) => memberAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _RetryState(
            message: 'GymUnity could not load your member details right now.',
            onRetry: () => ref.invalidate(memberProfileDetailsProvider),
          ),
          data: (memberProfile) {
            _seedControllers(profile, memberProfile);
            return ListView(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              children: [
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickAvatar,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Upload Avatar'),
                ),
                const SizedBox(height: 18),
                _InputField(
                  controller: _fullNameController,
                  label: 'Full Name',
                ),
                _InputField(controller: _phoneController, label: 'Phone'),
                _InputField(controller: _countryController, label: 'Country'),
                _InputField(controller: _goalController, label: 'Goal'),
                _InputField(
                  controller: _ageController,
                  label: 'Age',
                  keyboardType: TextInputType.number,
                ),
                _InputField(controller: _genderController, label: 'Gender'),
                _InputField(
                  controller: _heightController,
                  label: 'Height (cm)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _InputField(
                  controller: _weightController,
                  label: 'Current Weight (kg)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _InputField(
                  controller: _frequencyController,
                  label: 'Training Frequency',
                ),
                _InputField(
                  controller: _experienceController,
                  label: 'Experience Level',
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _seedControllers(ProfileEntity? profile, dynamic memberProfile) {
    if (_seeded) {
      return;
    }
    _seeded = true;
    _fullNameController.text = profile?.fullName ?? '';
    _phoneController.text = profile?.phone ?? '';
    _countryController.text = profile?.country ?? '';
    _goalController.text = memberProfile?.goal ?? '';
    _ageController.text = memberProfile?.age?.toString() ?? '';
    _genderController.text = memberProfile?.gender ?? '';
    _heightController.text = memberProfile?.heightCm?.toString() ?? '';
    _weightController.text = memberProfile?.currentWeightKg?.toString() ?? '';
    _frequencyController.text = memberProfile?.trainingFrequency ?? '';
    _experienceController.text = memberProfile?.experienceLevel ?? '';
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      await ref
          .read(userRepositoryProvider)
          .uploadAvatar(
            bytes: bytes,
            extension: file.path.split('.').last.toLowerCase(),
          );
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar uploaded successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _saveProfile() async {
    final fullName = _fullNameController.text.trim();
    final goal = _goalController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    if (fullName.isEmpty ||
        goal.isEmpty ||
        age == null ||
        height == null ||
        weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all required fields first.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .updateProfileDetails(
            fullName: fullName,
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            country: _countryController.text.trim().isEmpty
                ? null
                : _countryController.text.trim(),
          );
      await ref
          .read(memberRepositoryProvider)
          .upsertMemberProfile(
            goal: goal,
            age: age,
            gender: _genderController.text.trim().toLowerCase().isEmpty
                ? 'prefer_not_to_say'
                : _genderController.text.trim().toLowerCase(),
            heightCm: height,
            currentWeightKg: weight,
            trainingFrequency: _frequencyController.text.trim().isEmpty
                ? '3_4_days_per_week'
                : _frequencyController.text.trim(),
            experienceLevel: _experienceController.text.trim().isEmpty
                ? 'beginner'
                : _experienceController.text.trim().toLowerCase(),
          );
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(memberProfileDetailsProvider);
      ref.invalidate(memberHomeSummaryProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
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

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});

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
