import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

/// Responsive main shell: NavigationBar on phones, NavigationRail on tablets (>600dp)
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home') || location.startsWith('/catalog') || location.startsWith('/search')) return 0;
    if (location.startsWith('/branches')) return 1;
    if (location.startsWith('/orders')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home');
      case 1: context.go('/branches');
      case 2: context.go('/orders');
      case 3: context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _currentIndex(context);
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIdx,
              onDestinationSelected: (index) => _onTap(context, index),
              labelType: NavigationRailLabelType.all,
              backgroundColor: Theme.of(context).colorScheme.surface,
              indicatorColor: AppColors.primary.withValues(alpha: 0.15),
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              unselectedIconTheme: const IconThemeData(color: AppColors.textLight),
              selectedLabelTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textLight,
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Inicio'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_rounded),
                  label: Text('Mapa'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: Text('Pedidos'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outlined),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('Perfil'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIdx,
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
