import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/auth_provider_type.dart';
import '../controllers/google_oauth_controller.dart';
import '../providers/auth_providers.dart';
import '../widgets/pre_auth_scene.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const int _finalPageIndex = 3;
  static const List<PreAuthSlideSpec> _slides = <PreAuthSlideSpec>[
    preAuthUnifiedSpec,
    preAuthShopSpec,
    preAuthWorkoutsSpec,
    preAuthEmpireSpec,
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authFlowState = ref.watch(authFlowControllerProvider);
    ref.listen<AuthFlowState>(authFlowControllerProvider, (
      AuthFlowState? previous,
      AuthFlowState next,
    ) {
      _handleAuthFlowState(previous, next);
    });

    return PageView.builder(
      controller: _pageController,
      itemCount: _slides.length,
      onPageChanged: (int index) {
        if (_currentPage != index) {
          setState(() {
            _currentPage = index;
          });
        }
      },
      itemBuilder: (BuildContext context, int index) {
        final PreAuthSlideSpec spec = _slides[index];
        final bool isFinalPage = index == _finalPageIndex;
        return PreAuthScene(
          spec: spec,
          onPrimaryAction: isFinalPage
              ? (authFlowState.isBusy ? null : _signInWithGoogle)
              : _nextPage,
          onSkip: spec.showSkip ? _skipToLoginSlide : null,
          isBusy: isFinalPage && authFlowState.isBusy,
          statusText: isFinalPage && authFlowState.isBusy
              ? AppStrings.completingGoogleSignIn
              : null,
        );
      },
    );
  }

  Future<void> _nextPage() async {
    if (!_pageController.hasClients || _currentPage >= _finalPageIndex) {
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skipToLoginSlide() async {
    if (!_pageController.hasClients) {
      return;
    }
    await _pageController.animateToPage(
      _finalPageIndex,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _signInWithGoogle() async {
    await ref
        .read(authFlowControllerProvider.notifier)
        .startOAuth(AuthProviderType.google);
  }

  void _handleAuthFlowState(AuthFlowState? previous, AuthFlowState next) {
    if (!mounted) {
      return;
    }

    if (next.status == AuthFlowStatus.success &&
        next.resolvedRoute != null &&
        next.resolvedRoute != previous?.resolvedRoute) {
      ref.read(authFlowControllerProvider.notifier).clearOutcome();
      Navigator.pushNamedAndRemoveUntil(
        context,
        next.resolvedRoute!,
        (Route<dynamic> route) => false,
      );
      return;
    }

    if (next.status == AuthFlowStatus.failure &&
        next.errorMessage != null &&
        next.errorMessage != previous?.errorMessage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      ref.read(authFlowControllerProvider.notifier).clearOutcome();
    }
  }
}
