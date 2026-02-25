import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(profileProvider);

    // Use API profile data if available, fallback to Supabase user metadata
    final profileName = profileAsync.whenOrNull(
      data: (p) => p['full_name'] as String?,
    );
    final profilePhone = profileAsync.whenOrNull(
      data: (p) => p['phone'] as String?,
    );
    final displayName = profileName ??
        user?.userMetadata?['full_name'] as String? ??
        user?.email ??
        '';
    final displayEmail = user?.email ?? '';
    final initial =
        (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(profileProvider);
          // Wait for the profile to reload
          await ref.read(profileProvider.future).catchError((_) => <String, dynamic>{});
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 32,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                displayName,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (displayEmail.isNotEmpty &&
                displayEmail != displayName)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    displayEmail,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            if (profilePhone != null && profilePhone.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    profilePhone,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 28),

            // Section: Cuenta
            _SectionHeader(title: 'Cuenta'),
            const SizedBox(height: 8),
            _MenuItem(
              icon: Icons.person_outlined,
              title: 'Datos personales',
              subtitle: 'Nombre y teléfono',
              onTap: () => context.push('/profile/edit'),
            ),
            _MenuItem(
              icon: Icons.location_on_outlined,
              title: 'Mis direcciones',
              subtitle: 'Direcciones de envío',
              onTap: () => context.push('/profile/addresses'),
            ),
            _MenuItem(
              icon: Icons.receipt_long_outlined,
              title: 'Mis pedidos',
              subtitle: 'Historial de compras',
              onTap: () => context.go('/orders'),
            ),
            const SizedBox(height: 20),

            // Section: Preferencias
            _SectionHeader(title: 'Preferencias'),
            const SizedBox(height: 8),
            _ThemeToggle(),
            const SizedBox(height: 28),

            // Logout
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Cerrar sesión',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).signOut();
            },
            child: const Text('Salir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
              )
            : null,
        trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          'Modo oscuro',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: Switch.adaptive(
          value: isDark,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
          activeThumbColor: AppColors.primary,
          onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
        ),
        onTap: () => ref.read(themeModeProvider.notifier).toggle(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
