import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/seller_profile_entity.dart';
import '../providers/seller_providers.dart';

class SellerProfileScreen extends ConsumerStatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  ConsumerState<SellerProfileScreen> createState() =>
      _SellerProfileScreenState();
}

class _SellerProfileScreenState extends ConsumerState<SellerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storeDescriptionController = TextEditingController();
  final _supportEmailController = TextEditingController();
  String _primaryCategory = 'supplements';
  String _shippingScope = 'domestic';
  bool _seeded = false;
  bool _isSaving = false;

  static const _categories = <String, String>{
    'supplements': 'Supplements',
    'equipment': 'Equipment',
    'apparel': 'Apparel',
    'accessories': 'Accessories',
    'nutrition': 'Nutrition',
    'recovery': 'Recovery & Wellness',
    'other': 'Other',
  };

  static const _shippingScopes = <String, String>{
    'domestic': 'Domestic Only',
    'regional': 'Regional',
    'international': 'International',
  };

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _supportEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(sellerProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Store Profile'),
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (error, stackTrace) => _ErrorState(
          message:
              'GymUnity could not load your store profile right now.',
          onRetry: () => ref.invalidate(sellerProfileProvider),
        ),
        data: (profile) {
          _seedControllers(profile);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              children: [
                _ProfileCompletenessCard(profile: profile),
                const SizedBox(height: AppSizes.xxl),
                Text(
                  'Store Identity',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _storeNameController,
                  label: 'Store Name',
                  hint: 'e.g. FitGear Egypt',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Store name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _storeDescriptionController,
                  label: 'Store Description',
                  hint:
                      'What does your store offer? What makes it special?',
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'A brief store description is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.xxl),
                Text(
                  'Business Details',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _DropdownField<String>(
                  label: 'Primary Category',
                  value: _primaryCategory,
                  items: _categories.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _primaryCategory = value);
                    }
                  },
                ),
                const SizedBox(height: AppSizes.md),
                _DropdownField<String>(
                  label: 'Shipping Scope',
                  value: _shippingScope,
                  items: _shippingScopes.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _shippingScope = value);
                    }
                  },
                ),
                const SizedBox(height: AppSizes.xxl),
                Text(
                  'Support',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _FormField(
                  controller: _supportEmailController,
                  label: 'Support Email',
                  hint: 'support@yourstore.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSizes.xxxl),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMd,
                        ),
                      ),
                    ),
                    child: Text(
                      _isSaving ? 'Saving...' : 'Save Store Profile',
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

  void _seedControllers(SellerProfileEntity? profile) {
    if (_seeded) {
      return;
    }
    _seeded = true;
    _storeNameController.text = profile?.storeName ?? '';
    _storeDescriptionController.text = profile?.storeDescription ?? '';
    _supportEmailController.text = profile?.supportEmail ?? '';
    _primaryCategory = profile?.primaryCategory ?? 'supplements';
    _shippingScope = profile?.shippingScope ?? 'domestic';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(sellerRepositoryProvider)
          .upsertSellerProfile(
            storeName: _storeNameController.text.trim(),
            storeDescription: _storeDescriptionController.text.trim(),
            primaryCategory: _primaryCategory,
            shippingScope: _shippingScope,
            supportEmail: _supportEmailController.text.trim().isEmpty
                ? null
                : _supportEmailController.text.trim(),
          );
      ref.invalidate(sellerProfileProvider);
      ref.invalidate(sellerDashboardSummaryProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store profile updated successfully.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────

class _ProfileCompletenessCard extends StatelessWidget {
  const _ProfileCompletenessCard({required this.profile});

  final SellerProfileEntity? profile;

  @override
  Widget build(BuildContext context) {
    final checks = <String, bool>{
      'Store name': profile?.storeName?.trim().isNotEmpty == true,
      'Description': profile?.storeDescription?.trim().isNotEmpty == true,
      'Category': profile?.primaryCategory?.trim().isNotEmpty == true,
      'Shipping scope': profile?.shippingScope?.trim().isNotEmpty == true,
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
                    : Icons.store_mall_directory_outlined,
                color: fraction >= 1.0
                    ? AppColors.success
                    : AppColors.orange,
                size: 28,
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fraction >= 1.0
                          ? 'Store profile complete'
                          : 'Complete your store profile',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completed of $total fields filled',
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
        ],
      ),
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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
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
