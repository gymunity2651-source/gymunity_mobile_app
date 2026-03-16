import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/external_link_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/domain/entities/auth_provider_type.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const String _confirmationPhrase = 'DELETE';

  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthProviderType? _authProvider;
  bool _loadingProvider = true;
  bool _obscurePassword = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProvider() async {
    final provider = await ref
        .read(authControllerProvider.notifier)
        .currentAuthProvider();
    if (!mounted) {
      return;
    }
    setState(() {
      _authProvider = provider ?? AuthProviderType.emailPassword;
      _loadingProvider = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Delete Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: Colors.red.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This action is irreversible.',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'GymUnity will permanently delete this account, erase personal profile data, revoke the current session, and keep only required shared records in anonymized form. You can sign up again later with the same email address as a brand new account.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Type $_confirmationPhrase to confirm.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          CustomTextField(
            label: 'Confirmation',
            hint: _confirmationPhrase,
            controller: _confirmationController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),
          if (_loadingProvider)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: CircularProgressIndicator(color: AppColors.orange),
              ),
            )
          else if (_authProvider == AuthProviderType.emailPassword)
            CustomTextField(
              label: 'Current Password',
              hint: 'Required to confirm deletion',
              controller: _passwordController,
              prefixIcon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: GestureDetector(
                onTap: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                child: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
              ),
              textInputAction: TextInputAction.done,
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'This account uses ${_authProvider?.label ?? 'a linked provider'} sign-in. GymUnity will verify the active session before deleting the account.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (_localError != null || authState.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _localError ?? authState.errorMessage!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.red.shade300,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 24),
          CustomButton(
            label: 'DELETE MY ACCOUNT',
            isLoading: authState.isLoading,
            backgroundColor: Colors.red,
            foregroundColor: AppColors.white,
            onPressed: _loadingProvider ? null : _submitDeletion,
          ),
          const SizedBox(height: 12),
          if (_canContactSupport)
            CustomButton(
              label: 'CONTACT SUPPORT',
              variant: ButtonVariant.outlined,
              onPressed: _contactSupport,
            ),
          const SizedBox(height: 18),
          Text(
            'Need final policy details? Review the in-app privacy policy or the reviewer help link configured for this environment.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  bool get _canContactSupport {
    final config = AppConfig.current;
    return config.supportUrl.trim().isNotEmpty ||
        config.supportEmail.trim().isNotEmpty;
  }

  Future<void> _submitDeletion() async {
    setState(() => _localError = null);

    final confirmation = _confirmationController.text.trim().toUpperCase();
    if (confirmation != _confirmationPhrase) {
      setState(() {
        _localError = 'Type $_confirmationPhrase exactly to continue.';
      });
      return;
    }

    if (_authProvider == AuthProviderType.emailPassword &&
        _passwordController.text.trim().isEmpty) {
      setState(() {
        _localError = 'Enter your current password to confirm this deletion.';
      });
      return;
    }

    final deleted = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount(
          currentPassword: _authProvider == AuthProviderType.emailPassword
              ? _passwordController.text.trim()
              : null,
        );
    if (!mounted) {
      return;
    }

    if (!deleted) {
      setState(() {
        _localError =
            ref.read(authControllerProvider).errorMessage ??
            'GymUnity could not delete this account right now. Please retry or contact support.';
      });
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account deleted'),
        content: const Text(
          'Your GymUnity account was permanently deleted and you have been signed out. You can create a new account later with the same email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _contactSupport() async {
    final openedSupportUrl = await ExternalLinkService.openSupportUrl();
    if (openedSupportUrl) {
      return;
    }

    await ExternalLinkService.composeSupportEmail(
      subject: AppConfig.current.supportEmailSubject,
      body: 'I need help with a permanently deleted GymUnity account.',
    );
  }
}
