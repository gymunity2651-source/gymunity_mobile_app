import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../coach/domain/entities/coach_entity.dart';
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
    final selectedSpecialty = ref.watch(selectedCoachSpecialtyProvider);
    final searchQuery = ref.watch(coachSearchQueryProvider);
    final coachesAsync = ref.watch(coachListProvider);
    final coaches = ref.watch(filteredCoachListProvider);

    if (_searchController.text != searchQuery) {
      _searchController.value = TextEditingValue(
        text: searchQuery,
        selection: TextSelection.collapsed(offset: searchQuery.length),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: () => ref.refresh(coachListProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                    vertical: AppSizes.lg,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        color: AppColors.textDark,
                        size: 26,
                      ),
                      const Spacer(),
                      Text(
                        'Coach Marketplace',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.orange,
                        child: const Icon(
                          Icons.person,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search coaches by name, specialty, or badge',
                    onChanged: (value) {
                      ref.read(coachSearchQueryProvider.notifier).state = value;
                    },
                    leading: const Icon(
                      Icons.search,
                      color: AppColors.textMuted,
                      size: 22,
                    ),
                    trailing: [
                      if (searchQuery.isNotEmpty)
                        IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                    ],
                    backgroundColor: const WidgetStatePropertyAll(
                      AppColors.lightSurface,
                    ),
                    surfaceTintColor: const WidgetStatePropertyAll(
                      AppColors.transparent,
                    ),
                    elevation: const WidgetStatePropertyAll(0),
                    side: const WidgetStatePropertyAll(
                      BorderSide(color: AppColors.border),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    hintStyle: WidgetStatePropertyAll(
                      GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                    textStyle: WidgetStatePropertyAll(
                      GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.screenPadding,
                    ),
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemCount: specialties.length,
                    itemBuilder: (context, index) {
                      final selected = selectedSpecialty == index;
                      return GestureDetector(
                        onTap: () {
                          ref
                                  .read(selectedCoachSpecialtyProvider.notifier)
                                  .state =
                              index;
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.orange
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusFull,
                            ),
                            border: selected
                                ? null
                                : Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            specialties[index],
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppColors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPadding,
                    18,
                    AppSizes.screenPadding,
                    0,
                  ),
                  child: Text(
                    _resultsLabel(
                      coaches.length,
                      specialties[selectedSpecialty],
                      searchQuery,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              if (coachesAsync.isLoading && coaches.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: _CoachCardSkeleton(),
                      ),
                      childCount: 3,
                    ),
                  ),
                )
              else if (coaches.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.screenPadding,
                    ),
                    child: _EmptyCoachState(
                      onClearFilters: _clearFilters,
                      searchQuery: searchQuery,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final coach = coaches[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _CoachCard(
                          coach: coach,
                          onViewProfile: () => Navigator.pushNamed(
                            context,
                            AppRoutes.coachDetails,
                            arguments: coach,
                          ),
                          onViewPackages: () => Navigator.pushNamed(
                            context,
                            AppRoutes.subscriptionPackages,
                            arguments: coach,
                          ),
                        ),
                      );
                    }, childCount: coaches.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(coachSearchQueryProvider.notifier).state = '';
  }

  void _clearFilters() {
    _clearSearch();
    ref.read(selectedCoachSpecialtyProvider.notifier).state = 0;
  }

  String _resultsLabel(int count, String specialty, String query) {
    final buffer = StringBuffer('$count coach');
    if (count != 1) {
      buffer.write('es');
    }
    if (specialty != 'All') {
      buffer.write(' in $specialty');
    }
    if (query.isNotEmpty) {
      buffer.write(' for "$query"');
    }
    return buffer.toString();
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.coach,
    required this.onViewProfile,
    required this.onViewPackages,
  });

  final CoachEntity coach;
  final VoidCallback onViewProfile;
  final VoidCallback onViewPackages;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 180,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppSizes.radiusLg),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person,
                    size: 56,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        coach.rating,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        coach.name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Starting from',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          coach.rateLabel,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  coach.specialty,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _InfoChip(label: coach.reviewsLabel),
                    const SizedBox(width: 8),
                    _InfoChip(label: coach.badge),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onViewProfile,
                        child: const Text('View Profile'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onViewPackages,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: AppColors.white,
                        ),
                        child: const Text('Coaching Packages'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CoachCardSkeleton extends StatelessWidget {
  const _CoachCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        children: [
          Container(
            height: 180,
            decoration: const BoxDecoration(
              color: Color(0xFFEAEAEA),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusLg),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(height: 12, color: const Color(0xFFEAEAEA)),
                const SizedBox(height: 10),
                Container(height: 12, color: const Color(0xFFEAEAEA)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCoachState extends StatelessWidget {
  const _EmptyCoachState({
    required this.onClearFilters,
    required this.searchQuery,
  });

  final VoidCallback onClearFilters;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_outlined,
            color: AppColors.textMuted,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            searchQuery.isEmpty
                ? 'No coaches matched this filter yet.'
                : 'No coaches matched "$searchQuery".',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try another specialty or clear the search to widen the marketplace.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onClearFilters,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}
