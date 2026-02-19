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
    final yappy = orderData?['yappy'] as Map<String, dynamic>?;
    final paymentMethod = order['payment_method'] as String? ?? '';
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
                child: Icon(
                  paymentMethod == 'in_store'
                      ? Icons.check_circle_outline
                      : Icons.receipt_long_outlined,
                  size: 80,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                paymentMethod == 'in_store'
                    ? '¡Pedido Confirmado!'
                    : '¡Pedido Creado!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pedido #$orderNumber',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textLight,
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

              // Payment-specific content
              if (paymentMethod == 'tilopay' && paymentUrl != null)
                _buildTilopaySection(context, paymentUrl),

              if (paymentMethod == 'yappy' && yappy != null)
                _buildYappySection(context, yappy, orderNumber, total),

              if (paymentMethod == 'in_store')
                _buildInStoreSection(context),

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
                  onPressed: () => context.go('/cart'),
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
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.credit_card, size: 40, color: Colors.blue),
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
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYappySection(
    BuildContext context,
    Map<String, dynamic> yappy,
    String orderNumber,
    double total,
  ) {
    final phone = yappy['phone'] as String? ?? '';
    final bankName = yappy['bank_name'] as String? ?? 'Banco General';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF68D391)),
      ),
      child: Column(
        children: [
          const Icon(Icons.phone_android, size: 40, color: Color(0xFF38A169)),
          const SizedBox(height: 12),
          Text('Pagar con Yappy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _yappyRow('Número', phone),
          _yappyRow('Banco', bankName),
          _yappyRow('Referencia', orderNumber),
          _yappyRow('Monto exacto', '\$${total.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Envía el monto EXACTO e incluye la referencia en la descripción.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _yappyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          SelectableText(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInStoreSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.storefront_outlined, size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text('Pago en tienda',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Tu pedido está confirmado. Paga directamente al momento de recogerlo en la sucursal.',
            textAlign: TextAlign.center,
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
