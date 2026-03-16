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
        children: tabs
            .map((tab) => tab.page)
            .toList(growable: false),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.cardDark,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.orange.withValues(alpha: 0.18),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? AppColors.orange : AppColors.textMuted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? AppColors.orange : AppColors.textMuted,
              size: 24,
            );
          }),
        ),
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
  const _MemberHomeTab({
    required this.page,
    required this.destination,
  });

  final Widget page;
  final NavigationDestination destination;
}
