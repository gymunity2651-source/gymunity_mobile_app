import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes.dart';
import '../../../user/presentation/controllers/onboarding_controller.dart';
import '../widgets/onboarding_dna.dart';

class SellerOnboardingScreen extends ConsumerStatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  ConsumerState<SellerOnboardingScreen> createState() =>
      _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState
    extends ConsumerState<SellerOnboardingScreen> {
  int _currentStep = 0;
  final int _totalSteps = 3;

  int _selectedCategory = 0;
  final List<_SellerCategory> _categories = const <_SellerCategory>[
    _SellerCategory(
      icon: Icons.bolt_outlined,
      title: 'Supplements',
      description: 'Protein, recovery, and performance support.',
    ),
    _SellerCategory(
      icon: Icons.checkroom_outlined,
      title: 'Apparel',
      description: 'Training wear and active lifestyle essentials.',
    ),
    _SellerCategory(
      icon: Icons.fitness_center,
      title: 'Equipment',
      description: 'Home gym gear, tools, and accessories.',
    ),
    _SellerCategory(
      icon: Icons.local_drink_outlined,
      title: 'Nutrition',
      description: 'Healthy snacks, drinks, and wellness products.',
    ),
  ];

  final _storeNameController = TextEditingController();
  final _storeDescController = TextEditingController();

  int _selectedShipping = 0;
  final List<String> _shippingOptions = const <String>[
    'Local only',
    'National',
    'International',
    'Digital products',
  ];

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeDescController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      return;
    }

    final storeName = _storeNameController.text.trim();
    final storeDescription = _storeDescController.text.trim();
    if (storeName.isEmpty) {
      _showMessage('Enter a store name to continue.');
      return;
    }
    if (storeDescription.isEmpty) {
      _showMessage('Enter a short store description to continue.');
      return;
    }

    final success = await ref
        .read(onboardingControllerProvider.notifier)
        .completeSellerOnboarding(
          storeName: storeName,
          storeDescription: storeDescription,
          primaryCategory: _categoryValue(_categories[_selectedCategory].title),
          shippingScope: _shippingValue(_shippingOptions[_selectedShipping]),
        );
    if (!mounted) return;
    if (!success) {
      _showMessage(
        ref.read(onboardingControllerProvider).errorMessage ??
            'Unable to complete onboarding right now.',
      );
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.sellerDashboard,
      (route) => false,
    );
  }

  String _categoryValue(String raw) {
    return raw.trim().toLowerCase().replaceAll(' ', '_');
  }

  String _shippingValue(String raw) {
    switch (raw) {
      case 'Local only':
        return 'local_only';
      case 'National':
        return 'national';
      case 'International':
        return 'international';
      case 'Digital products':
        return 'digital_products';
      default:
        return raw.trim().toLowerCase().replaceAll(' ', '_');
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingControllerProvider);

    return OnboardingScreenFrame(
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onBack: _prevStep,
      primaryLabel: _currentStep < _totalSteps - 1
          ? 'CONTINUE'
          : 'LAUNCH STORE',
      onPrimaryAction: _nextStep,
      footerText: _currentStep == 0
          ? 'You can refine your catalog and business profile later from the seller dashboard.'
          : 'GymUnity will use these inputs to tailor your store setup and visibility.',
      isLoading: onboardingState.isLoading,
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildCategoryStep();
      case 1:
        return _buildStoreInfoStep();
      case 2:
        return _buildShippingStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCategoryStep() {
    return SingleChildScrollView(
      key: const ValueKey('seller-category-step'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            title: 'What does your',
            accent: 'store sell?',
            subtitle:
                'Choose the category that best represents your storefront so the seller dashboard starts in the right lane.',
          ),
          const SizedBox(height: 28),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.84,
            ),
            itemBuilder: (context, index) {
              final category = _categories[index];
              return OnboardingOptionCard(
                icon: category.icon,
                title: category.title,
                description: category.description,
                selected: _selectedCategory == index,
                onTap: () => setState(() => _selectedCategory = index),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfoStep() {
    return SingleChildScrollView(
      key: const ValueKey('seller-info-step'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            title: 'Shape your',
            accent: 'storefront.',
            subtitle:
                'A clear brand name and focused description make your catalog feel real from day one.',
          ),
          const SizedBox(height: 28),
          OnboardingTextField(
            label: 'Store Name',
            hint: 'FitGear Pro',
            controller: _storeNameController,
          ),
          const SizedBox(height: 18),
          OnboardingTextField(
            label: 'Store Description',
            hint:
                'Describe your niche, products, and why people should buy from you.',
            controller: _storeDescController,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildShippingStep() {
    return SingleChildScrollView(
      key: const ValueKey('seller-shipping-step'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            title: 'Where will you',
            accent: 'deliver?',
            subtitle:
                'Your shipping scope helps GymUnity frame buyer expectations and order reach from the start.',
          ),
          const SizedBox(height: 28),
          ...List.generate(_shippingOptions.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: OnboardingSelectablePanel(
                label: _shippingOptions[index],
                helper: _shippingHelper(index),
                selected: _selectedShipping == index,
                onTap: () => setState(() => _selectedShipping = index),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _shippingHelper(int index) {
    switch (index) {
      case 0:
        return 'Perfect for pickup, city-level delivery, or limited radius logistics.';
      case 1:
        return 'Ship across the country with a broader buyer base and stable operations.';
      case 2:
        return 'Open the store to international buyers and cross-border logistics.';
      case 3:
        return 'Best for programs, guides, meal plans, or any instant-delivery product.';
      default:
        return '';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SellerCategory {
  const _SellerCategory({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
