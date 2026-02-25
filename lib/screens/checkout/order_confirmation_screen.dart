import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';

class OrderConfirmationScreen extends ConsumerWidget {
  final String orderId;
  final Map<String, dynamic>? orderData;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    this.orderData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = orderData?['order'] as Map<String, dynamic>? ?? {};
    final paymentUrl = orderData?['payment_url'] as String?;
    final orderNumber = orderData?['odoo_order_name'] as String? ??
        order['payment_reference'] as String? ??
        orderId.substring(0, 8).toUpperCase();
    final total = (order['total'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Success animation / icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 80,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¡Pedido Creado!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pedido #$orderNumber',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: \$${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 32),

              // Payment section
              if (paymentUrl != null)
                _buildTilopaySection(context, paymentUrl),

              const SizedBox(height: 40),

              // Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Seguir comprando'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/orders'),
                  child: const Text('Mis pedidos'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTilopaySection(BuildContext context, String paymentUrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.credit_card, size: 40, color: AppColors.info),
          const SizedBox(height: 12),
          Text('Pagar con tarjeta',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Serás redirigido a Tilopay para completar tu pago de forma segura.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openPaymentLink(paymentUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ir a pagar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaymentLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
