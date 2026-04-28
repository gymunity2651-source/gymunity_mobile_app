import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../user/presentation/controllers/onboarding_controller.dart';

const Color _surface = Color(0xFFFAF9F6);
const Color _surfaceLowest = Color(0xFFFFFFFF);
const Color _surfaceLow = Color(0xFFF4F3F1);
const Color _surfaceHigh = Color(0xFFE9E8E5);
const Color _primary = Color(0xFF822700);
const Color _secondary = Color(0xFFA43C12);
const Color _secondaryContainer = Color(0xFFFE7E4F);
const Color _onSurface = Color(0xFF1A1C1A);
const Color _onSurfaceVariant = Color(0xFF6B625F);
const Color _muted = Color(0xFF98918D);
const Color _glass = Color(0xCCFAF9F6);
const Color _ambientShadow = Color(0x0D1A1C1A);

class SellerOnboardingScreen extends ConsumerStatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  ConsumerState<SellerOnboardingScreen> createState() =>
      _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState
    extends ConsumerState<SellerOnboardingScreen> {
  static const int _totalSteps = 3;

  final _storeNameController = TextEditingController();
  final _storeDescController = TextEditingController();

  int _currentStep = 0;
  int _selectedCategory = 0;
  int _selectedShipping = 0;

  final List<_SellerCategory> _categories = const <_SellerCategory>[
    _SellerCategory(
      icon: Icons.science_outlined,
      title: 'Supplements',
      description:
          'Protein formulation and recovery protocols engineered for optimal balance.',
      swatchA: Color(0xFF1F2722),
      swatchB: Color(0xFF64301B),
    ),
    _SellerCategory(
      icon: Icons.checkroom_outlined,
      title: 'Apparel',
      description:
          'Elevated training wear. Breathable, structured, and designed for movement.',
      swatchA: Color(0xFFE7E27B),
      swatchB: Color(0xFFF5F1D1),
    ),
    _SellerCategory(
      icon: Icons.fitness_center_outlined,
      title: 'Equipment',
      description:
          'Curated home gym gear. Sculptural tools for physical discipline.',
      swatchA: Color(0xFFE6D12F),
      swatchB: Color(0xFF171816),
    ),
    _SellerCategory(
      icon: Icons.restaurant_menu_outlined,
      title: 'Nutrition',
      description:
          'Mindful provisions. Healthy snacks to sustain endurance and focus.',
      swatchA: Color(0xFF55B8B2),
      swatchB: Color(0xFFEBF3EA),
    ),
  ];

  final List<_ShippingOption> _shippingOptions = const <_ShippingOption>[
    _ShippingOption(
      title: 'Local Only',
      value: 'local_only',
      description:
          'Perfect for artisan goods, delicate items, or starting out small within your immediate community.',
    ),
    _ShippingOption(
      title: 'National',
      value: 'national',
      description:
          'Ship coast to coast. Reach a broader audience across the country with standardized shipping rates.',
    ),
    _ShippingOption(
      title: 'International',
      value: 'international',
      description:
          'Global reach. Sell to customers worldwide and manage complex customs and duties.',
    ),
  ];

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeDescController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0 && !_validateStoreIdentity()) {
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      return;
    }

    await _launchStore();
  }

  Future<void> _launchStore() async {
    if (!_validateStoreIdentity()) {
      setState(() => _currentStep = 0);
      return;
    }

    final success = await ref
        .read(onboardingControllerProvider.notifier)
        .completeSellerOnboarding(
          storeName: _storeNameController.text.trim(),
          storeDescription: _storeDescController.text.trim(),
          primaryCategory: _categoryValue(_categories[_selectedCategory].title),
          shippingScope: _shippingOptions[_selectedShipping].value,
        );
    if (!mounted) {
      return;
    }
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

  bool _validateStoreIdentity() {
    if (_storeNameController.text.trim().isEmpty) {
      _showMessage('Enter a store name to continue.');
      return false;
    }
    if (_storeDescController.text.trim().isEmpty) {
      _showMessage('Enter a short store description to continue.');
      return false;
    }
    return true;
  }

  String _categoryValue(String raw) {
    return raw.trim().toLowerCase().replaceAll(' ', '_');
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      return;
    }
    Navigator.pop(context);
  }

  String get _primaryLabel {
    return switch (_currentStep) {
      0 => 'Continue to Curation',
      1 => 'Continue',
      _ => 'LAUNCH STORE',
    };
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingControllerProvider);

    return Scaffold(
      backgroundColor: _surface,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _SanctuaryBackdrop(),
          SafeArea(
            child: Column(
              children: [
                _GlassHeader(
                  currentStep: _currentStep,
                  totalSteps: _totalSteps,
                  onBack: _prevStep,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _buildStep(),
                  ),
                ),
                _BottomCta(
                  label: _primaryLabel,
                  loading: onboardingState.isLoading,
                  onTap: _nextStep,
                  tertiaryLabel: _currentStep == 2
                      ? 'You can expand your reach later'
                      : 'Auto-saving',
                  tertiaryIcon: _currentStep == 2
                      ? Icons.auto_awesome_outlined
                      : Icons.lock_outline_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    return switch (_currentStep) {
      0 => _StoreIdentityStep(
        key: const ValueKey('seller-store-identity-step'),
        storeNameController: _storeNameController,
        storeDescController: _storeDescController,
      ),
      1 => _CollectionStep(
        key: const ValueKey('seller-collection-step'),
        categories: _categories,
        selectedIndex: _selectedCategory,
        onSelect: (index) => setState(() => _selectedCategory = index),
      ),
      _ => _DeliveryStep(
        key: const ValueKey('seller-delivery-step'),
        options: _shippingOptions,
        selectedIndex: _selectedShipping,
        onSelect: (index) => setState(() => _selectedShipping = index),
      ),
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope()),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

class _SanctuaryBackdrop extends StatelessWidget {
  const _SanctuaryBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _surface,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFFFFFFFF), _surface, Color(0xFFF6F1EC)],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -120,
          child: _AtmosphereOrb(
            size: 320,
            color: _secondaryContainer.withValues(alpha: 0.18),
          ),
        ),
        Positioned(
          top: 220,
          right: -140,
          child: _AtmosphereOrb(
            size: 260,
            color: _primary.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          bottom: -140,
          left: -80,
          child: _AtmosphereOrb(
            size: 300,
            color: _secondary.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _AtmosphereOrb extends StatelessWidget {
  const _AtmosphereOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: <Color>[color, Colors.transparent]),
      ),
    );
  }
}

class _GlassHeader extends StatelessWidget {
  const _GlassHeader({
    required this.currentStep,
    required this.totalSteps,
    required this.onBack,
  });

  final int currentStep;
  final int totalSteps;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: _glass,
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
          child: Row(
            children: [
              _RoundGlassButton(icon: Icons.arrow_back_rounded, onTap: onBack),
              const Spacer(),
              _ProgressDots(currentStep: currentStep, totalSteps: totalSteps),
              const Spacer(),
              Text(
                currentStep == 1 ? 'The Curator' : 'SELLER',
                style: GoogleFonts.notoSerif(
                  fontSize: currentStep == 1 ? 16 : 12,
                  fontStyle: currentStep == 1
                      ? FontStyle.italic
                      : FontStyle.normal,
                  fontWeight: FontWeight.w600,
                  letterSpacing: currentStep == 1 ? 0.6 : 2.4,
                  color: _primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundGlassButton extends StatelessWidget {
  const _RoundGlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 46,
            height: 46,
            color: _surfaceLowest.withValues(alpha: 0.72),
            alignment: Alignment.center,
            child: Icon(icon, color: _onSurface, size: 21),
          ),
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(totalSteps, (index) {
        final active = index == currentStep;
        final reached = index <= currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: active ? 42 : 8,
          height: active ? 4 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: reached ? _primary : _onSurface.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _StoreIdentityStep extends StatelessWidget {
  const _StoreIdentityStep({
    super.key,
    required this.storeNameController,
    required this.storeDescController,
  });

  final TextEditingController storeNameController;
  final TextEditingController storeDescController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 42),
      children: [
        const _StorefrontHero(),
        const SizedBox(height: 32),
        const _EditorialQuote(
          text:
              '"The space you create is the first quiet conversation you have with your audience."',
        ),
        const SizedBox(height: 84),
        Padding(
          padding: const EdgeInsets.only(right: 30),
          child: _EditorialHeading(
            title: 'Shape your',
            accent: 'storefront',
            subtitle:
                'Define the essence of your space. This is how the world will discover, perceive, and connect with your curated collection.',
          ),
        ),
        const SizedBox(height: 54),
        _AtelierTextField(
          label: 'STORE NAME',
          hint: 'e.g. The Clay Sanctuary',
          controller: storeNameController,
        ),
        const SizedBox(height: 34),
        _AtelierTextField(
          label: 'STORE DESCRIPTION',
          hint:
              'Describe the atmosphere, the curation philosophy, and the soul of your offerings...',
          controller: storeDescController,
          minLines: 5,
          maxLines: 7,
        ),
      ],
    );
  }
}

class _StorefrontHero extends StatelessWidget {
  const _StorefrontHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 370,
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(42),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: _ambientShadow,
            blurRadius: 40,
            spreadRadius: -5,
            offset: Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/fitness_store_home.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF34443F),
                      Color(0xFF17211F),
                      Color(0xFF7D3B22),
                    ],
                  ),
                ),
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  _onSurface.withValues(alpha: 0.18),
                  Colors.transparent,
                  _onSurface.withValues(alpha: 0.16),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  color: _surface.withValues(alpha: 0.72),
                  child: Text(
                    'SAFE WORK',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.1,
                      color: _primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialQuote extends StatelessWidget {
  const _EditorialQuote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 82,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.notoSerif(
                fontSize: 20,
                fontStyle: FontStyle.italic,
                color: _onSurface,
                height: 1.38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionStep extends StatelessWidget {
  const _CollectionStep({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_SellerCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(30, 28, 26, 40),
      children: [
        const _EditorialHeading(
          title: 'Curate your',
          accent: 'collection.',
          subtitle: 'Select the disciplines that define your sanctuary.',
          maxTitleWidth: 280,
        ),
        const SizedBox(height: 54),
        ...List<Widget>.generate(categories.length, (index) {
          final isEven = index.isEven;
          return Padding(
            padding: EdgeInsets.only(
              left: isEven ? 0 : 18,
              right: isEven ? 20 : 0,
              bottom: 28,
            ),
            child: _CollectionCard(
              category: categories[index],
              selected: selectedIndex == index,
              onTap: () => onSelect(index),
            ),
          );
        }),
      ],
    );
  }
}

class _DeliveryStep extends StatelessWidget {
  const _DeliveryStep({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_ShippingOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(30, 46, 30, 40),
      children: [
        Icon(Icons.local_shipping_rounded, size: 36, color: _primary),
        const SizedBox(height: 38),
        Text(
          'Where will you\ndeliver?',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerif(
            fontSize: 38,
            fontWeight: FontWeight.w600,
            height: 1.18,
            letterSpacing: -0.8,
            color: _primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Define your shipping scope. You can always expand your reach as your studio grows.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 19,
            height: 1.7,
            color: _onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 82),
        ...List<Widget>.generate(options.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: _DeliveryOptionCard(
              option: options[index],
              selected: selectedIndex == index,
              onTap: () => onSelect(index),
            ),
          );
        }),
      ],
    );
  }
}

class _EditorialHeading extends StatelessWidget {
  const _EditorialHeading({
    required this.title,
    required this.accent,
    required this.subtitle,
    this.maxTitleWidth = 330,
  });

  final String title;
  final String accent;
  final String subtitle;
  final double maxTitleWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxTitleWidth),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title\n',
                  style: GoogleFonts.notoSerif(
                    fontSize: 40,
                    fontWeight: FontWeight.w500,
                    height: 1.16,
                    letterSpacing: -1.0,
                    color: _onSurface,
                  ),
                ),
                TextSpan(
                  text: accent,
                  style: GoogleFonts.notoSerif(
                    fontSize: 40,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    height: 1.16,
                    letterSpacing: -1.0,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 16,
              height: 1.75,
              color: _onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _AtelierTextField extends StatefulWidget {
  const _AtelierTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;

  @override
  State<_AtelierTextField> createState() => _AtelierTextFieldState();
}

class _AtelierTextFieldState extends State<_AtelierTextField> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        setState(() => _focused = _focusNode.hasFocus);
      });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            widget.label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.2,
              color: _focused ? _secondary : _onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: _focused ? _surfaceHigh : _surfaceLow,
            borderRadius: BorderRadius.circular(32),
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            cursorColor: _primary,
            style: GoogleFonts.manrope(
              fontSize: 16,
              height: 1.55,
              color: _onSurface,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.manrope(
                fontSize: 15,
                height: 1.55,
                color: _muted.withValues(alpha: 0.52),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(
                28,
                widget.maxLines > 1 ? 28 : 20,
                28,
                widget.maxLines > 1 ? 28 : 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _SellerCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 34),
        decoration: BoxDecoration(
          color: selected ? _surfaceHigh : _surfaceLow,
          borderRadius: BorderRadius.circular(42),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: _ambientShadow,
              blurRadius: 40,
              spreadRadius: -5,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryImagePanel(category: category, selected: selected),
            const SizedBox(height: 34),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    category.title,
                    style: GoogleFonts.notoSerif(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                      color: _onSurface,
                    ),
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0.72,
                  duration: const Duration(milliseconds: 220),
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: _primary,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              category.description,
              style: GoogleFonts.manrope(
                fontSize: 14,
                height: 1.55,
                color: _onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryImagePanel extends StatelessWidget {
  const _CategoryImagePanel({required this.category, required this.selected});

  final _SellerCategory category;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      height: 128,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: RadialGradient(
          center: selected ? Alignment.topRight : Alignment.center,
          radius: 1.16,
          colors: <Color>[category.swatchB, category.swatchA],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Icon(
              category.icon,
              size: 132,
              color: _surfaceLowest.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: _surfaceLowest.withValues(alpha: 0.88),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, size: 34, color: _primary),
            ),
          ),
          Positioned(
            left: 20,
            top: 16,
            child: Text(
              category.title.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: _surfaceLowest.withValues(alpha: 0.86),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryOptionCard extends StatelessWidget {
  const _DeliveryOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ShippingOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(38, 38, 34, 38),
        decoration: BoxDecoration(
          color: selected ? _surfaceHigh : _surfaceLow,
          borderRadius: BorderRadius.circular(54),
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: _ambientShadow,
                    blurRadius: 40,
                    spreadRadius: -5,
                    offset: Offset(0, 18),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? _primary : _surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: _surface, size: 20)
                  : null,
            ),
            const SizedBox(width: 30),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: GoogleFonts.notoSerif(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                      height: 1.1,
                      color: selected ? _primary : _onSurface,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    option.description,
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      height: 1.66,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.label,
    required this.loading,
    required this.onTap,
    required this.tertiaryLabel,
    required this.tertiaryIcon,
  });

  final String label;
  final bool loading;
  final VoidCallback onTap;
  final String tertiaryLabel;
  final IconData tertiaryIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: _surface.withValues(alpha: 0.80),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 60,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[_primary, _secondaryContainer],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: _ambientShadow,
                        blurRadius: 40,
                        spreadRadius: -5,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: loading ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _surfaceLowest,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: GoogleFonts.manrope(
                                  fontSize: label == 'LAUNCH STORE' ? 14 : 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: label == 'LAUNCH STORE'
                                      ? 3.2
                                      : 0,
                                  color: _surfaceLowest,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: _surfaceLowest,
                                size: 20,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tertiaryIcon, size: 14, color: _onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    tertiaryLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: _onSurfaceVariant,
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

class _SellerCategory {
  const _SellerCategory({
    required this.icon,
    required this.title,
    required this.description,
    required this.swatchA,
    required this.swatchB,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color swatchA;
  final Color swatchB;
}

class _ShippingOption {
  const _ShippingOption({
    required this.title,
    required this.value,
    required this.description,
  });

  final String title;
  final String value;
  final String description;
}
