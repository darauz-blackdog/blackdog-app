import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/order.dart';
import '../../providers/orders_provider.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fade_in_up.dart';

Color _statusColor(String status) {
  return switch (status) {
    'delivered' => AppColors.success,
    'cancelled' => AppColors.error,
    'confirmed' || 'ready_pickup' || 'shipping' || 'preparing' => AppColors.info,
    'pending_payment' => AppColors.warning,
    _ => AppColors.warning,
  };
}

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  final Order? extraOrder;

  const OrderDetailScreen({super.key, required this.orderId, this.extraOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Pedido')),
      body: orderAsync.when(
        data: (order) => _buildContent(context, ref, order),
        loading: () => extraOrder != null
            ? _buildContent(context, ref, extraOrder!)
            : const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status
          FadeInUp(
            delay: 0,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Builder(builder: (context) {
                  final color = _statusColor(order.status);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                  );
                })
              ],
            ),
          ),
          FadeInUp(
            delay: 50,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                order.createdAt != null
                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order.createdAt!).toLocal())
                    : '',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          ),

          // Pay button (pending payment orders)
          if (order.status == 'pending_payment')
            FadeInUp(
              delay: 80,
              offset: 15,
              duration: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(
                      '/payment/${order.id}',
                      extra: {
                        'payment_url': order.paymentLink,
                        'payment_method': order.paymentMethod,
                      },
                    ),
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Pagar ahora'),
                  ),
                ),
              ),
            ),

          // Tracking button
          if (order.status != 'pending_payment' && order.status != 'cancelled')
            FadeInUp(
              delay: 80,
              offset: 15,
              duration: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/orders/${order.id}/tracking'),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Ver seguimiento'),
                  ),
                ),
              ),
            ),

          // Cancel button
          if (order.canCancel)
            FadeInUp(
              delay: 90,
              offset: 15,
              duration: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmCancel(context, ref, order),
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                    label: const Text('Cancelar pedido'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ),
            ),

          const Divider(height: 32),

          // Items
          FadeInUp(
            delay: 100,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: Text('Productos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          ...order.items.asMap().entries.map((entry) => FadeInUp(
            delay: 150 + entry.key * 60,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.image, color: Theme.of(context).hintColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.value.productName ?? 'Desconocido', style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                        Text('${entry.value.quantity} x \$${entry.value.unitPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                      ],
                    ),
                  ),
                  Text('\$${entry.value.total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),
          )),

          const Divider(height: 32),

          // Payment & Delivery Info
          FadeInUp(
            delay: 150 + order.items.length * 60,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: Column(
              children: [
                _InfoRow(label: 'Método de Pago', value: _paymentMethodLabel(order.paymentMethod)),
                const SizedBox(height: 8),
                _InfoRow(label: 'Entrega', value: order.deliveryType == 'delivery' ? 'Domicilio' : 'Retiro en Tienda'),
                if (order.branch != null) ...[
                   const SizedBox(height: 8),
                   _InfoRow(label: 'Sucursal', value: order.branch!.name),
                ],
              ],
            ),
          ),

          const Divider(height: 32),

          // Totals
          FadeInUp(
            delay: 200 + order.items.length * 60,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: Column(
              children: [
                _TotalRow(label: 'Subtotal', value: order.subtotal),
                _TotalRow(label: 'Envío', value: order.deliveryFee),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    Text('\$${order.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String method) {
    switch(method) {
      case 'tilopay': return 'Tarjeta de Crédito';
      case 'yappy': return 'Yappy';
      case 'in_store': return 'Pago en Tienda';
      default: return method;
    }
  }

  void _confirmCancel(BuildContext context, WidgetRef ref, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text('¿Estás seguro de que deseas cancelar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiServiceProvider);
                await api.cancelOrder(order.id);
                ref.invalidate(orderDetailProvider(order.id));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pedido cancelado')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cancelar: $e')),
                  );
                }
              }
            },
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).hintColor)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  const _TotalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('\$${value.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}
