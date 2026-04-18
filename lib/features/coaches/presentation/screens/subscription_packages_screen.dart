import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../coach/domain/entities/coach_entity.dart';
import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../coach/presentation/providers/coach_providers.dart';
import '../../../planner/domain/entities/planner_entities.dart';

class SubscriptionPackagesScreen extends ConsumerWidget {
  const SubscriptionPackagesScreen({super.key, this.coach});

  final CoachEntity? coach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (coach == null) {
      return const _UnavailablePackagesScreen();
    }

    final coachAsync = ref.watch(coachDetailsProvider(coach!.id));
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.textDark,
        title: Text('${coach!.name} Offers'),
      ),
      body: coachAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: ElevatedButton(
            onPressed: () => ref.refresh(coachDetailsProvider(coach!.id)),
            child: const Text('Retry'),
          ),
        ),
        data: (data) {
          final currentCoach = data ?? coach!;
          if (currentCoach.packages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Text(
                  'This coach does not have any published offers right now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  'Choose a coaching offer, review the starter plan preview, then start a paid checkout. Once payment is confirmed, your coaching thread and weekly check-ins go live.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              ...currentCoach.packages.map(
                (package) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.lg),
                  child: _OfferCard(
                    package: package,
                    currency: currentCoach.pricingCurrency,
                    onRequest: () => _requestPackage(
                      context: context,
                      ref: ref,
                      package: package,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestPackage({
    required BuildContext context,
    required WidgetRef ref,
    required CoachPackageEntity package,
  }) async {
    final data = await showDialog<_SubscriptionRequestData>(
      context: context,
      builder: (context) =>
          _SubscriptionRequestDialog(packageTitle: package.title),
    );
    if (data == null) {
      return;
    }

    try {
      await ref
          .read(coachRepositoryProvider)
          .requestSubscription(
            packageId: package.id,
            intakeSnapshot: data.intake,
            note: data.note,
            paymentRail: data.paymentRail,
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Checkout started. Confirm payment from My Coaching to activate the coach thread.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.package,
    required this.currency,
    required this.onRequest,
  });

  final CoachPackageEntity package;
  final String currency;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final preview = GeneratedPlanEntity.fromMap(package.planPreviewJson);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (package.subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        package.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                package.checkoutPriceLabel,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            package.outcomeSummary.trim().isEmpty
                ? package.description
                : package.outcomeSummary,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(label: '${package.durationWeeks} weeks'),
              _InfoPill(label: '${package.sessionsPerWeek} sessions / week'),
              _InfoPill(label: _titleize(package.difficultyLevel)),
              _InfoPill(label: _titleize(package.weeklyCheckinType)),
              _InfoPill(label: _titleize(package.locationMode)),
              _InfoPill(label: _titleize(package.deliveryMode)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Renewal: EGP ${package.renewalPriceEgp.toStringAsFixed(0)} | Trial: ${package.trialDays} day${package.trialDays == 1 ? '' : 's'}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
          if (package.idealFor.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Ideal for',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: package.idealFor
                  .map((item) => _Tag(text: item))
                  .toList(growable: false),
            ),
          ],
          if (package.includedFeatures.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Included',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...package.includedFeatures.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: AppColors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (package.supportSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              package.supportSummary,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _PlanPreviewSection(preview: preview),
          if (package.faqItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'FAQ',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...package.faqItems.map(
              (faq) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  faq.question,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      faq.answer,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Start paid checkout'),
            ),
          ),
        ],
      ),
    );
  }

  static String _priceLabel(
    double value,
    String currency,
    String billingCycle,
  ) {
    final symbol = currency.trim().toUpperCase() == 'USD'
        ? '\$'
        : '${currency.trim().toUpperCase()} ';
    final normalized = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$symbol$normalized/${billingCycle.replaceAll('_', ' ')}';
  }

  static String _titleize(String value) => value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

class _PlanPreviewSection extends StatelessWidget {
  const _PlanPreviewSection({required this.preview});

  final GeneratedPlanEntity preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Starter plan preview',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            preview.summary,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ...preview.weeklyStructure
              .take(2)
              .map(
                (week) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Week ${week.weekNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...week.days
                          .take(3)
                          .map(
                            (day) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${day.label}: ${day.focus}',
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
              ),
        ],
      ),
    );
  }
}

class _SubscriptionRequestDialog extends StatefulWidget {
  const _SubscriptionRequestDialog({required this.packageTitle});

  final String packageTitle;

  @override
  State<_SubscriptionRequestDialog> createState() =>
      _SubscriptionRequestDialogState();
}

class _SubscriptionRequestDialogState
    extends State<_SubscriptionRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _goalController = TextEditingController();
  final _daysController = TextEditingController();
  final _minutesController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _limitationsController = TextEditingController();
  final _noteController = TextEditingController();
  final _budgetController = TextEditingController();
  final _cityController = TextEditingController();
  String _experienceLevel = 'beginner';
  String _paymentRail = 'instapay';

  @override
  void dispose() {
    _goalController.dispose();
    _daysController.dispose();
    _minutesController.dispose();
    _equipmentController.dispose();
    _limitationsController.dispose();
    _noteController.dispose();
    _budgetController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Request ${widget.packageTitle}'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _goalController,
                  decoration: const InputDecoration(labelText: 'Primary goal'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Goal is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _experienceLevel,
                  decoration: const InputDecoration(
                    labelText: 'Experience level',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'beginner',
                      child: Text('Beginner'),
                    ),
                    DropdownMenuItem(
                      value: 'intermediate',
                      child: Text('Intermediate'),
                    ),
                    DropdownMenuItem(
                      value: 'advanced',
                      child: Text('Advanced'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _experienceLevel = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _daysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Days per week',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Session minutes',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Budget (EGP)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _equipmentController,
                  decoration: const InputDecoration(
                    labelText: 'Equipment available',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _limitationsController,
                  decoration: const InputDecoration(
                    labelText: 'Limitations or injuries',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Optional note to the coach',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentRail,
                  decoration: const InputDecoration(labelText: 'Payment rail'),
                  items: const [
                    DropdownMenuItem(
                      value: 'instapay',
                      child: Text('Instapay'),
                    ),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _paymentRail = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Submit request')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(
      context,
      _SubscriptionRequestData(
        intake: CoachSubscriptionIntakeEntity(
          goal: _goalController.text.trim(),
          experienceLevel: _experienceLevel,
          daysPerWeek: int.tryParse(_daysController.text.trim()),
          sessionMinutes: int.tryParse(_minutesController.text.trim()),
          equipment: _split(_equipmentController.text),
          limitations: _split(_limitationsController.text),
          budgetEgp: int.tryParse(_budgetController.text.trim()),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
        ),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        paymentRail: _paymentRail,
      ),
    );
  }

  List<String> _split(String raw) => raw
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

class _SubscriptionRequestData {
  const _SubscriptionRequestData({
    required this.intake,
    required this.paymentRail,
    this.note,
  });

  final CoachSubscriptionIntakeEntity intake;
  final String paymentRail;
  final String? note;
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.orange,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _UnavailablePackagesScreen extends StatelessWidget {
  const _UnavailablePackagesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Text(
            'No coach package context was provided for this route.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 15),
          ),
        ),
      ),
    );
  }
}
