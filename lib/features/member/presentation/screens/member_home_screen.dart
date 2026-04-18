import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/atelier_theme.dart';
import '../../../ai_chat/presentation/screens/ai_chat_home_screen.dart';
import '../../../coaches/presentation/screens/coaches_screen.dart';
import '../../../news/presentation/screens/news_feed_screen.dart';
import 'member_home_content.dart';
import 'member_profile_screen.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  int _currentIndex = 0;
  int? _previousIndex;

  @override
  Widget build(BuildContext context) {
    final tabs = _memberHomeTabs;

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
    );
  }

  void _handleDestinationSelected(int index) {
    if (index == _currentIndex) {
      return;
    }

    final previous = _currentIndex;
    setState(() {
      _previousIndex = previous;
      _currentIndex = index;
    });

    Future<void>.delayed(AppMotion.medium, () {
      if (!mounted || _previousIndex != previous) {
        return;
      }
      setState(() => _previousIndex = null);
    });
  }

  List<_MemberHomeTab> get _memberHomeTabs => const <_MemberHomeTab>[
    _MemberHomeTab(
      page: MemberHomeContent(),
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_filled,
      label: 'HOME',
    ),
    _MemberHomeTab(
      page: CoachesScreen(),
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'COACHES',
    ),
    _MemberHomeTab(
      page: AiChatHomeScreen(),
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      label: 'AI',
    ),
    _MemberHomeTab(
      page: NewsFeedScreen(),
      icon: Icons.newspaper_outlined,
      selectedIcon: Icons.newspaper,
      label: 'NEWS',
    ),
    _MemberHomeTab(
      page: MemberProfileScreen(),
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
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
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
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
  });

  final Widget page;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
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
