import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../ai_chat/presentation/screens/ai_chat_home_screen.dart';
import '../../../coaches/presentation/screens/coaches_screen.dart';
import '../../../news/presentation/screens/news_feed_screen.dart';
import '../../../store/presentation/screens/store_home_screen.dart';
import 'member_home_content.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = _memberHomeTabs;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: tabs.map((tab) => tab.page).toList(growable: false),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.borderSoft.withValues(alpha: 0.46),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cardDark.withValues(alpha: 0.96),
                AppColors.surfacePanel.withValues(alpha: 0.96),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.26),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              destinations: tabs
                  .map((tab) => tab.destination)
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  List<_MemberHomeTab> get _memberHomeTabs => const <_MemberHomeTab>[
    _MemberHomeTab(
      page: MemberHomeContent(),
      destination: NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_filled),
        label: 'Home',
      ),
    ),
    _MemberHomeTab(
      page: StoreHomeScreen(),
      destination: NavigationDestination(
        icon: Icon(Icons.storefront_outlined),
        selectedIcon: Icon(Icons.storefront),
        label: 'Store',
      ),
    ),
    _MemberHomeTab(
      page: AiChatHomeScreen(),
      destination: NavigationDestination(
        icon: Icon(Icons.auto_awesome_outlined),
        selectedIcon: Icon(Icons.auto_awesome),
        label: 'AI',
      ),
    ),
    _MemberHomeTab(
      page: CoachesScreen(),
      destination: NavigationDestination(
        icon: Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups),
        label: 'Coaches',
      ),
    ),
    _MemberHomeTab(
      page: NewsFeedScreen(),
      destination: NavigationDestination(
        icon: Icon(Icons.newspaper_outlined),
        selectedIcon: Icon(Icons.newspaper),
        label: 'News',
      ),
    ),
  ];
}

class _MemberHomeTab {
  const _MemberHomeTab({required this.page, required this.destination});

  final Widget page;
  final NavigationDestination destination;
}
