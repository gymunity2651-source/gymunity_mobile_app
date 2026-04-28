import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/theme/atelier_theme.dart';
import '../../../coach/domain/entities/coach_entity.dart';
import '../../../member/presentation/widgets/member_profile_shortcut_button.dart';
import '../../../user/presentation/providers/profile_avatar_provider.dart';
import '../providers/coaches_providers.dart';

class CoachesScreen extends ConsumerStatefulWidget {
  const CoachesScreen({super.key});

  @override
  ConsumerState<CoachesScreen> createState() => _CoachesScreenState();
}

class _CoachesScreenState extends ConsumerState<CoachesScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specialties = ref.watch(coachSpecialtiesProvider);
    final selectedSpecialtyIndex = ref.watch(selectedCoachSpecialtyProvider);
    final selectedSpecialty = specialties[selectedSpecialtyIndex];
    final searchQuery = ref.watch(coachSearchQueryProvider);
    final city = ref.watch(selectedCoachCityProvider);
    final language = ref.watch(selectedCoachLanguageProvider);
    final gender = ref.watch(selectedCoachGenderProvider);
    final budget = ref.watch(selectedCoachBudgetProvider);
    final coachesAsync = ref.watch(coachListProvider);
    final coaches = ref.watch(filteredCoachListProvider);

    if (_searchController.text != searchQuery) {
      _searchController.value = TextEditingValue(
        text: searchQuery,
        selection: TextSelection.collapsed(offset: searchQuery.length),
      );
    }

    final showResetFilters =
        searchQuery.trim().isNotEmpty ||
        selectedSpecialtyIndex != 0 ||
        city != null ||
        budget != null ||
        gender != null;

    return Theme(
      data: AtelierTheme.light,
      child: Scaffold(
        backgroundColor: _MarketplacePalette.background,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator.adaptive(
            color: _MarketplacePalette.primary,
            onRefresh: _refreshMarketplace,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 118),
              children: [
                _MarketplaceTopBar(
                  onMenuTap: () =>
                      Navigator.pushNamed(context, AppRoutes.settings),
                ),
                const SizedBox(height: 28),
                const _MarketplaceHeroCopy(),
                const SizedBox(height: 28),
                _MarketplaceSearchField(
                  controller: _searchController,
                  onChanged: (value) =>
                      ref.read(coachSearchQueryProvider.notifier).state = value,
                  onClear: _clearSearch,
                  showClear: searchQuery.trim().isNotEmpty,
                ),
                const SizedBox(height: 16),
                _SpecialtyChipWrap(
                  labels: specialties,
                  selectedIndex: selectedSpecialtyIndex,
                  onSelected: (index) =>
                      ref.read(selectedCoachSpecialtyProvider.notifier).state =
                          index,
                ),
                const SizedBox(height: 34),
                if (coachesAsync.isLoading && coaches.isEmpty) ...[
                  const _TailoredPanelSkeleton(),
                  const SizedBox(height: 32),
                  const _CoachEditorialCardSkeleton(),
                  const SizedBox(height: 32),
                  const _CoachEditorialCardSkeleton(),
                ] else if (coachesAsync.hasError && coaches.isEmpty) ...[
                  _MarketplaceStateCard(
                    title: 'The marketplace is quiet right now',
                    message:
                        'We could not refresh the coach roster. Pull to retry or load the curation again.',
                    actionLabel: 'Retry Curation',
                    onAction: () {
                      _refreshMarketplace();
                    },
                  ),
                ] else if (coaches.isEmpty) ...[
                  _MarketplaceStateCard(
                    title: searchQuery.trim().isEmpty
                        ? 'No coaches matched this curation'
                        : 'No coaches matched "$searchQuery"',
                    message:
                        'Try another specialty or widen the filters to bring more practitioners into view.',
                    actionLabel: showResetFilters ? 'Reset Filters' : 'Refresh',
                    onAction: showResetFilters
                        ? _clearFilters
                        : () {
                            _refreshMarketplace();
                          },
                  ),
                ] else ...[
                  _TailoredPanel(
                    coaches: coaches,
                    specialtyLabel: selectedSpecialty,
                    city: city,
                    language: language,
                    budget: budget,
                    gender: gender,
                    showResetFilters: showResetFilters,
                    onCityTap: () =>
                        ref.read(selectedCoachCityProvider.notifier).state =
                            city == null ? 'Cairo' : null,
                    onLanguageTap: () =>
                        ref.read(selectedCoachLanguageProvider.notifier).state =
                            language == 'arabic' ? 'english' : 'arabic',
                    onBudgetTap: () =>
                        ref.read(selectedCoachBudgetProvider.notifier).state =
                            budget == null ? 2500 : null,
                    onGenderTap: () =>
                        ref.read(selectedCoachGenderProvider.notifier).state =
                            gender == null ? 'female' : null,
                    onResetTap: _clearFilters,
                  ),
                  const SizedBox(height: 28),
                  _MarketplaceListHeader(
                    count: coaches.length,
                    specialtyLabel: selectedSpecialty,
                  ),
                  const SizedBox(height: 14),
                  for (var index = 0; index < coaches.length; index++) ...[
                    _CoachEditorialCard(
                      coach: coaches[index],
                      onViewProfile: () => Navigator.pushNamed(
                        context,
                        AppRoutes.coachDetails,
                        arguments: coaches[index],
                      ),
                      onViewOffers: () => Navigator.pushNamed(
                        context,
                        AppRoutes.subscriptionPackages,
                        arguments: coaches[index],
                      ),
                    ),
                    if (index != coaches.length - 1) const SizedBox(height: 16),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshMarketplace() async {
    ref.invalidate(coachListProvider);
    await ref.read(coachListProvider.future);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(coachSearchQueryProvider.notifier).state = '';
  }

  void _clearFilters() {
    _clearSearch();
    ref.read(selectedCoachSpecialtyProvider.notifier).state = 0;
    ref.read(selectedCoachCityProvider.notifier).state = null;
    ref.read(selectedCoachLanguageProvider.notifier).state = 'arabic';
    ref.read(selectedCoachBudgetProvider.notifier).state = null;
    ref.read(selectedCoachGenderProvider.notifier).state = null;
  }
}

class _MarketplaceTopBar extends StatelessWidget {
  const _MarketplaceTopBar({required this.onMenuTap});

  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Offstage(
          offstage: true,
          child: _RoundGhostButton(icon: Icons.menu_rounded, onTap: onMenuTap),
        ),
        const Spacer(),
        MemberProfileShortcutButton(
          size: 36,
          backgroundColor: _MarketplacePalette.surface,
          borderColor: _MarketplacePalette.ghostBorder,
          iconColor: _MarketplacePalette.primary,
          tooltip: 'Profile',
        ),
      ],
    );
  }
}

class _MarketplaceHeroCopy extends StatelessWidget {
  const _MarketplaceHeroCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coach\nMarketplace',
          style: GoogleFonts.notoSerif(
            fontSize: 51,
            height: 0.94,
            fontWeight: FontWeight.w500,
            color: _MarketplacePalette.primary,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            'A curated selection of world-class mentors. Find the expertise that aligns with your unique path to vitality and balance.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.7,
              color: _MarketplacePalette.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _MarketplaceSearchField extends StatelessWidget {
  const _MarketplaceSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.showClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _MarketplacePalette.field,
        borderRadius: BorderRadius.circular(26),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _MarketplacePalette.text,
        ),
        decoration: InputDecoration(
          hintText: 'Search by name, specialty, or city',
          hintStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _MarketplacePalette.muted.withValues(alpha: 0.8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: _MarketplacePalette.primary,
          ),
          suffixIcon: showClear
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _MarketplacePalette.muted,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 19,
          ),
        ),
      ),
    );
  }
}

class _SpecialtyChipWrap extends StatelessWidget {
  const _SpecialtyChipWrap({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(labels.length, (index) {
        final selected = index == selectedIndex;
        return _SpecialtyChip(
          label: labels[index],
          selected: selected,
          onTap: () => onSelected(index),
        );
      }),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? null : _MarketplacePalette.section,
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _MarketplacePalette.primary,
                      _MarketplacePalette.primarySoft,
                    ],
                  )
                : null,
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: _MarketplacePalette.shadow,
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: selected
                  ? _MarketplacePalette.surface
                  : _MarketplacePalette.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _TailoredPanel extends StatelessWidget {
  const _TailoredPanel({
    required this.coaches,
    required this.specialtyLabel,
    required this.city,
    required this.language,
    required this.budget,
    required this.gender,
    required this.showResetFilters,
    required this.onCityTap,
    required this.onLanguageTap,
    required this.onBudgetTap,
    required this.onGenderTap,
    required this.onResetTap,
  });

  final List<CoachEntity> coaches;
  final String specialtyLabel;
  final String? city;
  final String? language;
  final double? budget;
  final String? gender;
  final bool showResetFilters;
  final VoidCallback onCityTap;
  final VoidCallback onLanguageTap;
  final VoidCallback onBudgetTap;
  final VoidCallback onGenderTap;
  final VoidCallback onResetTap;

  @override
  Widget build(BuildContext context) {
    final verifiedCount = coaches
        .where(
          (coach) => coach.isVerified || coach.verificationStatus == 'verified',
        )
        .length;
    final maxYears = coaches.isEmpty
        ? 0
        : coaches
              .map((coach) => coach.yearsExperience)
              .reduce((value, element) => value > element ? value : element);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: _MarketplacePalette.section,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tailored To You',
            style: GoogleFonts.notoSerif(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: _MarketplacePalette.primary,
            ),
          ),
          const SizedBox(height: 16),
          _InsightRow(
            icon: Icons.workspace_premium_rounded,
            text: verifiedCount > 0
                ? 'Vetted professionals with up to $maxYears years of practice.'
                : 'Curated professionals selected for consistency and care.',
          ),
          const SizedBox(height: 12),
          const _InsightRow(
            icon: Icons.schedule_rounded,
            text: 'Flexible sessions that respect your schedule and energy.',
          ),
          const SizedBox(height: 12),
          _InsightRow(
            icon: Icons.favorite_rounded,
            text: specialtyLabel == 'All'
                ? 'Holistic guidance across strength, mobility, and recovery.'
                : 'A focused lens on $specialtyLabel with sustainable progression.',
          ),
          const SizedBox(height: 20),
          Text(
            'CURRENT FILTERS',
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: _MarketplacePalette.muted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterTogglePill(
                label: city ?? 'All cities',
                selected: city != null,
                onTap: onCityTap,
              ),
              _FilterTogglePill(
                label: language == 'arabic' ? 'Arabic first' : 'English',
                selected: true,
                onTap: onLanguageTap,
              ),
              _FilterTogglePill(
                label: budget == null
                    ? 'Open budget'
                    : 'Under EGP ${budget!.toStringAsFixed(0)}',
                selected: budget != null,
                onTap: onBudgetTap,
              ),
              _FilterTogglePill(
                label: gender == null ? 'Any coach' : _titleCase(gender!),
                selected: gender != null,
                onTap: onGenderTap,
              ),
            ],
          ),
          if (showResetFilters) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: onResetTap,
              style: TextButton.styleFrom(
                foregroundColor: _MarketplacePalette.primary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Reset filters',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                  decorationColor: _MarketplacePalette.primary.withValues(
                    alpha: 0.35,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarketplaceListHeader extends StatelessWidget {
  const _MarketplaceListHeader({
    required this.count,
    required this.specialtyLabel,
  });

  final int count;
  final String specialtyLabel;

  @override
  Widget build(BuildContext context) {
    final noun = count == 1 ? 'coach' : 'coaches';
    final scope = specialtyLabel == 'All'
        ? 'available coaching profiles'
        : '$specialtyLabel coaching profiles';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count $noun',
          style: GoogleFonts.notoSerif(
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w500,
            color: _MarketplacePalette.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Review $scope, open the coach profile, then inspect the live offers before subscribing.',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.55,
            color: _MarketplacePalette.muted,
          ),
        ),
      ],
    );
  }
}

class _CoachEditorialCard extends StatelessWidget {
  const _CoachEditorialCard({
    required this.coach,
    required this.onViewProfile,
    required this.onViewOffers,
  });

  final CoachEntity coach;
  final VoidCallback onViewProfile;
  final VoidCallback onViewOffers;

  @override
  Widget build(BuildContext context) {
    final offerCount = coach.activePackageCount;
    final offerLabel = offerCount <= 0
        ? 'Offers'
        : '$offerCount ${offerCount == 1 ? 'offer' : 'offers'}';

    return Container(
      decoration: BoxDecoration(
        color: _MarketplacePalette.section,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onViewProfile,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        width: 104,
                        height: 132,
                        child: _CoachArtwork(coach: coach),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  coach.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.notoSerif(
                                    fontSize: 23,
                                    height: 1.02,
                                    fontWeight: FontWeight.w500,
                                    color: _MarketplacePalette.text,
                                  ),
                                ),
                              ),
                              if (coach.isVerified ||
                                  coach.verificationStatus == 'verified') ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 19,
                                  color: _MarketplacePalette.primary,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _coachRoleLine(coach),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: _MarketplacePalette.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _CoachMetricPill(
                                icon: Icons.local_offer_outlined,
                                label: offerLabel,
                              ),
                              _CoachMetricPill(
                                icon: Icons.payments_outlined,
                                label: coach.discoveryPriceLabel,
                              ),
                              _CoachMetricPill(
                                icon: Icons.star_rounded,
                                label: _coachReviewLine(coach),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _coachFeatureCopy(coach),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                    color: _MarketplacePalette.muted,
                  ),
                ),
                if (coach.specialties.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: coach.specialties
                        .take(3)
                        .map((specialty) => _CoachSpecialtyPill(specialty))
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _CoachCardButton(
                        label: 'View',
                        icon: Icons.person_outline_rounded,
                        onTap: onViewProfile,
                        primary: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CoachCardButton(
                        label: 'Offers',
                        icon: Icons.inventory_2_outlined,
                        onTap: onViewOffers,
                        primary: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachMetricPill extends StatelessWidget {
  const _CoachMetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: _MarketplacePalette.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _MarketplacePalette.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _MarketplacePalette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachSpecialtyPill extends StatelessWidget {
  const _CoachSpecialtyPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _MarketplacePalette.field.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          color: _MarketplacePalette.primary,
        ),
      ),
    );
  }
}

class _CoachCardButton extends StatelessWidget {
  const _CoachCardButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? _MarketplacePalette.surface
        : _MarketplacePalette.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: primary ? null : _MarketplacePalette.surface,
            gradient: primary
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _MarketplacePalette.primary,
                      _MarketplacePalette.primarySoft,
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachArtwork extends ConsumerWidget {
  const _CoachArtwork({required this.coach});

  final CoachEntity coach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarPath = coach.avatarPath?.trim();
    if (avatarPath == null || avatarPath.isEmpty) {
      return _CoachArtworkFallback(coach: coach);
    }

    final imageUrlAsync = ref.watch(profileAvatarUrlProvider(avatarPath));
    return imageUrlAsync.when(
      loading: () => _CoachArtworkFallback(coach: coach),
      error: (_, _) => _CoachArtworkFallback(coach: coach),
      data: (imageUrl) {
        if (imageUrl == null || imageUrl.isEmpty) {
          return _CoachArtworkFallback(coach: coach);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _CoachArtworkFallback(coach: coach),
            ),
            Container(color: _MarketplacePalette.halo.withValues(alpha: 0.1)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.14),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CoachArtworkFallback extends StatelessWidget {
  const _CoachArtworkFallback({required this.coach});

  final CoachEntity coach;

  @override
  Widget build(BuildContext context) {
    final initial = coach.name.trim().isNotEmpty
        ? coach.name.trim().substring(0, 1).toUpperCase()
        : 'C';
    final isFemale = coach.coachGender == 'female';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isFemale
              ? const [Color(0xFF6F8ED0), Color(0xFF2E477E)]
              : const [Color(0xFF343434), Color(0xFF0E0E0E)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -24,
            top: 28,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _MarketplacePalette.halo.withValues(alpha: 0.36),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 166,
              height: 166,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _MarketplacePalette.primarySoft.withValues(alpha: 0.24),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              initial,
              style: GoogleFonts.notoSerif(
                fontSize: 132,
                fontWeight: FontWeight.w600,
                color: _MarketplacePalette.surface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialPrimaryButton extends StatelessWidget {
  const _EditorialPrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                _MarketplacePalette.primary,
                _MarketplacePalette.primarySoft,
              ],
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _MarketplacePalette.surface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundGhostButton extends StatelessWidget {
  const _RoundGhostButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _MarketplacePalette.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: _MarketplacePalette.primary),
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: _MarketplacePalette.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.6,
              color: _MarketplacePalette.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterTogglePill extends StatelessWidget {
  const _FilterTogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? _MarketplacePalette.surface
                : _MarketplacePalette.field.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: selected
                  ? _MarketplacePalette.primary
                  : _MarketplacePalette.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplaceStateCard extends StatelessWidget {
  const _MarketplaceStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: _MarketplacePalette.section,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSerif(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w500,
              color: _MarketplacePalette.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.7,
              color: _MarketplacePalette.muted,
            ),
          ),
          const SizedBox(height: 18),
          _EditorialPrimaryButton(label: actionLabel, onTap: onAction),
        ],
      ),
    );
  }
}

class _TailoredPanelSkeleton extends StatelessWidget {
  const _TailoredPanelSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: _MarketplacePalette.section,
        borderRadius: BorderRadius.circular(32),
      ),
    );
  }
}

class _CoachEditorialCardSkeleton extends StatelessWidget {
  const _CoachEditorialCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 248,
      decoration: BoxDecoration(
        color: _MarketplacePalette.section,
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }
}

class _MarketplacePalette {
  static const Color background = AtelierColors.surfaceContainerLowest;
  static const Color surface = AtelierColors.surfaceContainerLowest;
  static const Color section = Color(0xFFF4F3F1);
  static const Color field = Color(0xFFE9E8E5);
  static const Color halo = Color(0xFFDEC0B6);
  static const Color primary = Color(0xFF822700);
  static const Color primarySoft = Color(0xFFFE7E4F);
  static const Color text = AtelierColors.onSurface;
  static const Color muted = Color(0xFF6B625D);
  static const Color ghostBorder = Color(0x26DEC0B6);
  static const Color shadow = Color(0x0D1A1C1A);
}

String _coachFeatureCopy(CoachEntity coach) {
  final source = coach.positioningStatement.trim().isNotEmpty
      ? coach.positioningStatement.trim()
      : coach.headline.trim().isNotEmpty
      ? coach.headline.trim()
      : coach.serviceSummary.trim().isNotEmpty
      ? coach.serviceSummary.trim()
      : coach.bio.trim();
  if (source.isNotEmpty) {
    return source;
  }

  final specialties = coach.specialties.isEmpty
      ? 'strength, longevity, and restorative balance'
      : coach.specialties.take(2).join(' and ').toLowerCase();
  return 'Personalized programming designed for sustainable transformation, focused on $specialties with calm, structured progression.';
}

String _coachRoleLine(CoachEntity coach) {
  if (coach.headline.trim().isNotEmpty) {
    return coach.headline.trim();
  }
  if (coach.specialties.isNotEmpty) {
    return '${coach.specialties.take(2).join(' & ')} Expert';
  }
  if (coach.deliveryMode?.trim().isNotEmpty == true) {
    return '${_titleCase(coach.deliveryMode!.replaceAll('_', ' '))} Specialist';
  }
  return 'Personal Wellness Specialist';
}

String _coachReviewLine(CoachEntity coach) {
  final responseRate = coach.responseMetrics['response_rate_percent'];
  if (responseRate is num && responseRate > 0) {
    return '${responseRate.round()}% response - ${coach.rating} rating';
  }
  if (coach.ratingCount <= 0) {
    return '${coach.rating} review pending';
  }
  return '${coach.rating} (${coach.ratingCount} reviews)';
}

String _titleCase(String value) {
  final parts = value
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .map((part) {
        final trimmed = part.trim();
        return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
      })
      .toList();
  return parts.join(' ');
}
