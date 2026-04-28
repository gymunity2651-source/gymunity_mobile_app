import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/atelier_theme.dart';
import '../../../ai_coach/presentation/screens/ai_coach_home_screen.dart';
import '../../../coaches/presentation/screens/coaches_screen.dart';
import '../../../news/presentation/screens/news_feed_screen.dart';
import '../providers/member_providers.dart';
import 'member_home_content.dart';
import 'member_profile_screen.dart';

class MemberHomeScreen extends ConsumerStatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  ConsumerState<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends ConsumerState<MemberHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int? _previousIndex;

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
      _refreshHomeSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _memberHomeTabs;

    // Listen for programmatic tab switches from child widgets.
    ref.listen<int?>(memberHomeTabSwitchProvider, (_, newIndex) {
      if (newIndex != null) {
        _handleDestinationSelected(newIndex);
        ref.read(memberHomeTabSwitchProvider.notifier).state = null;
      }
    });
    // Scope the entire home shell in the editorial light theme.
    return Theme(
      data: AtelierTheme.light,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // dark icons on light bg
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AtelierColors.surfaceContainerLowest,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: PopScope(
          canPop: _currentIndex == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || _currentIndex == 0) {
              return;
            }
            _handleDestinationSelected(0);
          },
          child: Scaffold(
            backgroundColor: AtelierColors.surfaceContainerLowest,
            extendBody: true,
            body: _AnimatedTabStack(
              pages: tabs.map((tab) => tab.page).toList(growable: false),
              currentIndex: _currentIndex,
              previousIndex: _previousIndex,
            ),

            // ── Floating glassmorphic pill nav bar ──
            bottomNavigationBar: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: AnimatedContainer(
                    key: const Key('member-bottom-nav-default-mode'),
                    duration: AppMotion.medium,
                    curve: AppMotion.standardCurve,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AtelierColors.warmGlass,
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: const [
                        BoxShadow(
                          color: AtelierColors.navShadow,
                          blurRadius: 40,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(tabs.length, (index) {
                        final tab = tabs[index];
                        final isSelected = index == _currentIndex;
                        return _NavBarItem(
                          icon: tab.icon,
                          selectedIcon: tab.selectedIcon,
                          label: tab.label,
                          isSelected: isSelected,
                          compact: false,
                          onTap: () => _handleDestinationSelected(index),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleDestinationSelected(int index) {
    if (index == _currentIndex) {
      if (index == 0) {
        _refreshHomeSummary();
      }
      return;
    }

    final previous = _currentIndex;
    setState(() {
      _previousIndex = previous;
      _currentIndex = index;
    });
    if (index == 0) {
      _refreshHomeSummary();
    }

    Future<void>.delayed(AppMotion.medium, () {
      if (!mounted || _previousIndex != previous) {
        return;
      }
      setState(() => _previousIndex = null);
    });
  }

  void _refreshHomeSummary() {
    ref.invalidate(memberHomeSummaryProvider);
  }

  List<_MemberHomeTab> get _memberHomeTabs => const <_MemberHomeTab>[
    _MemberHomeTab(
      page: MemberHomeContent(),
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_filled,
      aiModeIcon: Icons.home_outlined,
      aiModeSelectedIcon: Icons.home_filled,
      label: 'HOME',
    ),
    _MemberHomeTab(
      page: CoachesScreen(),
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      aiModeIcon: Icons.groups_outlined,
      aiModeSelectedIcon: Icons.groups,
      label: 'COACHES',
    ),
    _MemberHomeTab(
      page: AiCoachHomeScreen(),
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      aiModeIcon: Icons.auto_awesome_outlined,
      aiModeSelectedIcon: Icons.auto_awesome,
      label: 'AI',
    ),
    _MemberHomeTab(
      page: NewsFeedScreen(),
      icon: Icons.newspaper_outlined,
      selectedIcon: Icons.newspaper,
      aiModeIcon: Icons.newspaper_outlined,
      aiModeSelectedIcon: Icons.newspaper,
      label: 'NEWS',
    ),
    _MemberHomeTab(
      page: MemberProfileScreen(),
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      aiModeIcon: Icons.person_outline,
      aiModeSelectedIcon: Icons.person,
      label: 'PROFILE',
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
//  NAV BAR ITEM
// ═══════════════════════════════════════════════════════════════════════════

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    this.compact = false,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AtelierColors.primary
        : AtelierColors.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        key: Key('member-nav-$label'),
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Icon(
                isSelected ? selectedIcon : icon,
                key: ValueKey('$label-$isSelected'),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.8,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB MODEL
// ═══════════════════════════════════════════════════════════════════════════

class _MemberHomeTab {
  const _MemberHomeTab({
    required this.page,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.aiModeIcon,
    this.aiModeSelectedIcon,
  });

  final Widget page;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final IconData? aiModeIcon;
  final IconData? aiModeSelectedIcon;
}

// ═══════════════════════════════════════════════════════════════════════════
//  ANIMATED TAB STACK (preserved from original)
// ═══════════════════════════════════════════════════════════════════════════

class _AnimatedTabStack extends StatelessWidget {
  const _AnimatedTabStack({
    required this.pages,
    required this.currentIndex,
    required this.previousIndex,
  });

  final List<Widget> pages;
  final int currentIndex;
  final int? previousIndex;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < pages.length; index++)
          _AnimatedTabPage(
            isActive: index == currentIndex,
            isPrevious: index == previousIndex,
            child: pages[index],
          ),
      ],
    );
  }
}

class _AnimatedTabPage extends StatelessWidget {
  const _AnimatedTabPage({
    required this.isActive,
    required this.isPrevious,
    required this.child,
  });

  final bool isActive;
  final bool isPrevious;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isVisible = isActive || isPrevious;

    return Offstage(
      offstage: !isVisible,
      child: IgnorePointer(
        ignoring: !isActive,
        child: TickerMode(
          enabled: isVisible,
          child: AnimatedOpacity(
            opacity: isActive ? 1 : 0,
            duration: AppMotion.medium,
            curve: isActive ? AppMotion.standardCurve : AppMotion.exitCurve,
            child: AnimatedSlide(
              offset: isActive
                  ? Offset.zero
                  : isPrevious
                  ? AppMotion.tabExitOffset
                  : AppMotion.tabEnterOffset,
              duration: AppMotion.medium,
              curve: isActive ? AppMotion.standardCurve : AppMotion.exitCurve,
              child: AnimatedScale(
                scale: isActive ? 1 : 0.992,
                duration: AppMotion.medium,
                curve: isActive ? AppMotion.standardCurve : AppMotion.exitCurve,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
