import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary,
              child: Text(
                (user?.email?.substring(0, 1) ?? 'U').toUpperCase(),
                style: const TextStyle(fontSize: 32, color: AppColors.secondary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user?.userMetadata?['full_name'] as String? ?? user?.email ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Center(
            child: Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: 32),

          // Menu items
          _MenuItem(
            icon: Icons.person_outlined,
            title: 'Datos personales',
            onTap: () {}, // TODO: Edit profile screen
          ),
          _MenuItem(
            icon: Icons.location_on_outlined,
            title: 'Mis direcciones',
            onTap: () {}, // TODO: Addresses screen
          ),
          _MenuItem(
            icon: Icons.receipt_long_outlined,
            title: 'Mis pedidos',
            onTap: () {}, // TODO: Orders screen
          ),
          _MenuItem(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            onTap: () {}, // TODO: Notifications screen
          ),
          _MenuItem(
            icon: Icons.help_outline,
            title: 'Ayuda',
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // Logout
          OutlinedButton.icon(
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Cerrar sesion', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
