import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'animated_status_icon.dart';
import 'fade_in_up.dart';

/// Shared success/error result view for payment screens
class PaymentResultView extends StatelessWidget {
  final bool isSuccess;
  final String title;
  final String? subtitle;
  final String? orderName;
  final String? confirmationNumber;
  final String? paymentMethod;
  final List<Widget> actions;

  const PaymentResultView({
    super.key,
    required this.isSuccess,
    required this.title,
    this.subtitle,
    this.orderName,
    this.confirmationNumber,
    this.paymentMethod,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 40),

        // Animated icon (bounce-in handled internally)
        isSuccess
            ? AnimatedStatusIcon.success()
            : AnimatedStatusIcon.error(),
        const SizedBox(height: 24),

        // Title
        FadeInUp(
          delay: 300,
          offset: 20,
          duration: const Duration(milliseconds: 500),
          child: Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Subtitle
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          FadeInUp(
            delay: 400,
            offset: 20,
            duration: const Duration(milliseconds: 500),
            child: Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        // Order details
        if (orderName != null || confirmationNumber != null) ...[
          const SizedBox(height: 24),
          FadeInUp(
            delay: 500,
            offset: 20,
            duration: const Duration(milliseconds: 500),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (orderName != null)
                    _DetailRow(label: 'Pedido', value: orderName!),
                  if (confirmationNumber != null)
                    _DetailRow(
                      label: 'Confirmación',
                      value: confirmationNumber!,
                    ),
                  if (paymentMethod != null)
                    _DetailRow(
                      label: 'Método',
                      value: _paymentMethodLabel(paymentMethod!),
                    ),
                ],
              ),
            ),
          ),
        ],

        // Error: WhatsApp support link
        if (!isSuccess) ...[
          const SizedBox(height: 16),
          FadeInUp(
            delay: 550,
            offset: 20,
            duration: const Duration(milliseconds: 500),
            child: TextButton.icon(
              onPressed: _openWhatsAppSupport,
              icon: const Icon(Icons.support_agent, size: 18),
              label: const Text('Contactar soporte'),
            ),
          ),
        ],

        // Action buttons
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 32),
          FadeInUp(
            delay: 600,
            offset: 20,
            duration: const Duration(milliseconds: 500),
            child: Column(children: actions),
          ),
        ],
      ],
    );
  }

  static String _paymentMethodLabel(String method) => switch (method) {
        'tilopay' => 'Tarjeta de crédito/débito',
        'yappy' => 'Yappy',
        'in_store' => 'Pago en tienda',
        _ => method,
      };

  static Future<void> _openWhatsAppSupport() async {
    final uri = Uri.parse(
      'https://wa.me/50760553232?text=Hola,%20necesito%20ayuda%20con%20mi%20pago',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
