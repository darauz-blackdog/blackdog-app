import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

/// Responsive main shell: NavigationBar on phones, NavigationRail on tablets (>600dp)
/// Uses StatefulNavigationShell to preserve state across tab switches.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = navigationShell.currentIndex;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Inicio',
      ),
      NavigationDestination(
        icon: Icon(Icons.storefront_outlined),
        selectedIcon: Icon(Icons.storefront_rounded),
        label: 'Catálogo',
      ),
      NavigationDestination(
        icon: Icon(Icons.store_outlined),
        selectedIcon: Icon(Icons.store_rounded),
        label: 'Sucursales',
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
    ];

    const railDestinations = [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: Text('Inicio'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.storefront_outlined),
        selectedIcon: Icon(Icons.storefront_rounded),
        label: Text('Catálogo'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.store_outlined),
        selectedIcon: Icon(Icons.store_rounded),
        label: Text('Sucursales'),
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
    ];

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIdx,
              onDestinationSelected: _onTap,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Theme.of(context).colorScheme.surface,
              indicatorColor: AppColors.primary.withValues(alpha: 0.15),
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              unselectedIconTheme: const IconThemeData(
                color: AppColors.textLight,
              ),
              selectedLabelTextStyle: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
              unselectedLabelTextStyle: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textLight),
              destinations: railDestinations,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIdx,
        onDestinationSelected: _onTap,
        destinations: destinations,
      ),
    );
  }
}
