import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/auth_provider_type.dart';
import '../controllers/google_oauth_controller.dart';
import '../providers/auth_providers.dart';
import 'pre_auth_scene.dart';

class GoogleOnlyAuthScreen extends ConsumerStatefulWidget {
  const GoogleOnlyAuthScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.helperText,
    this.badge = 'GOOGLE-ONLY ACCESS',
    this.secondaryActionLabel,
    this.secondaryActionRoute,
    this.sceneSpec,
    this.showHeader = true,
  });

  final String title;
  final String subtitle;
  final String helperText;
  final String badge;
  final String? secondaryActionLabel;
  final String? secondaryActionRoute;
  final PreAuthSlideSpec? sceneSpec;
  final bool showHeader;

  @override
  ConsumerState<GoogleOnlyAuthScreen> createState() =>
      _GoogleOnlyAuthScreenState();
}

class _GoogleOnlyAuthScreenState extends ConsumerState<GoogleOnlyAuthScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authFlowControllerProvider.notifier).handleAppResumed();
    }
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

    final PreAuthSlideSpec spec =
        widget.sceneSpec ??
        preAuthEmpireSpec.copyWith(
          headlineLines: <PreAuthHeadlineLine>[
            PreAuthHeadlineLine(<PreAuthHeadlineSpan>[
              PreAuthHeadlineSpan(widget.title),
            ]),
          ],
          bodyCopy: widget.subtitle,
          supportingCopy: widget.helperText,
          eyebrow: widget.badge,
          showAccentLine: true,
          ctaType: PreAuthCtaType.google,
          ctaLabel: AppStrings.continueWithGoogle,
          footer: const PreAuthFooter(
            label: AppStrings.poweredBy,
            style: PreAuthFooterStyle.text,
          ),
          showSkip: false,
          showBrandWordmark: false,
          contentAlignment: PreAuthContentAlignment.bottomStart,
        );

    return PreAuthScene(
      spec: spec,
      onPrimaryAction: authFlowState.isBusy ? null : _signInWithGoogle,
      isBusy: authFlowState.isBusy,
      statusText: authFlowState.isBusy
          ? AppStrings.completingGoogleSignIn
          : null,
      headerLeading: widget.showHeader
          ? _BackPill(onPressed: () => _goBack(context))
          : null,
      headerCenter: widget.showHeader
          ? Text(
              AppStrings.appName,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.96),
              ),
            )
          : null,
      secondaryActionLabel: widget.secondaryActionLabel,
      onSecondaryAction: widget.secondaryActionRoute == null
          ? null
          : () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                widget.secondaryActionRoute!,
                (Route<dynamic> route) => false,
              );
            },
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

  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.welcome,
      (Route<dynamic> route) => false,
    );
  }
}

class _BackPill extends StatelessWidget {
  const _BackPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
