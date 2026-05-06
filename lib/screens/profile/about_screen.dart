import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/fade_in_up.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
      body: ResponsiveCenter(
        child: ListView(
        padding: EdgeInsets.all(Responsive.padding(context)),
        children: [
          // Logo + version
          FadeInUp(
            delay: 0,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/icons/Black_Dog_Logo_V.png',
                      width: 72,
                      height: 72,
                      semanticLabel: 'Logo de Black Dog Panamá',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Black Dog Panamá',
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _packageInfo != null
                        ? 'Versión ${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                        : 'Cargando versión...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu tienda de mascotas favorita',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Contact section
          FadeInUp(
            delay: 100,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: _SectionHeader(title: 'Contacto'),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            delay: 150,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: _ContactItem(
              icon: Icons.phone_outlined,
              title: 'Teléfono',
              subtitle: '+507 6000-0000',
              onTap: () => _launchUrl('tel:+50760000000'),
            ),
          ),
          FadeInUp(
            delay: 200,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: _ContactItem(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: 'info@blackdogpanama.com',
              onTap: () => _launchUrl('mailto:info@blackdogpanama.com'),
            ),
          ),
          FadeInUp(
            delay: 250,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: _ContactItem(
              icon: Icons.chat_outlined,
              title: 'WhatsApp',
              subtitle: 'Chatea con nosotros',
              onTap: () => _launchUrl('https://wa.me/50760553232'),
            ),
          ),
          FadeInUp(
            delay: 300,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: _ContactItem(
              icon: Icons.language_outlined,
              title: 'Sitio web',
              subtitle: 'www.blackdogpanama.com',
              onTap: () => _launchUrl('https://www.blackdogpanama.com'),
            ),
          ),
          const SizedBox(height: 24),

          // Legal section
          FadeInUp(
            delay: 350,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: _SectionHeader(title: 'Legal'),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            delay: 400,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: _ContactItem(
              icon: Icons.privacy_tip_outlined,
              title: 'Política de privacidad',
              onTap: () => context.push('/profile/privacy'),
            ),
          ),
          FadeInUp(
            delay: 450,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: _ContactItem(
              icon: Icons.description_outlined,
              title: 'Términos y condiciones',
              onTap: () => context.push('/profile/terms'),
            ),
          ),
          FadeInUp(
            delay: 500,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: _ContactItem(
              icon: Icons.info_outlined,
              title: 'Licencias de terceros',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Black Dog Panamá',
                applicationVersion: _packageInfo?.version ?? '',
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/icons/Black_Dog_Logo_V.png',
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Footer
          Center(
            child: Text(
              '© 2026 Black Dog Panamá. Todos los derechos reservados.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ContactItem({
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
