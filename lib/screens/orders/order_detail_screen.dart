import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/order.dart';
import '../../providers/orders_provider.dart';
import '../../theme/app_theme.dart';

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
        data: (order) => _buildContent(context, order),
        loading: () => extraOrder != null 
            ? _buildContent(context, extraOrder!) // Optimistic UI if passed via extra
            : const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Orden #${order.odooOrderName ?? order.id.substring(0, 8).toUpperCase()}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                 decoration: BoxDecoration(
                   color: AppColors.primary.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: AppColors.primary),
                 ),
                 child: Text(
                   order.statusLabel,
                   style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                 ),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.createdAt != null
                ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order.createdAt!).toLocal())
                : '',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          
          const Divider(height: 32),

          // Items
          Text('Productos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...order.items.map((item) => Padding(
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
                      Text(item.productName ?? 'Desconocido', style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                      Text('${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
                Text('\$${item.total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          )),

          const Divider(height: 32),

          // Payment & Delivery Info
          _InfoRow(label: 'Método de Pago', value: _paymentMethodLabel(order.paymentMethod)),
          const SizedBox(height: 8),
          _InfoRow(label: 'Entrega', value: order.deliveryType == 'delivery' ? 'Domicilio' : 'Retiro en Tienda'),
          if (order.branch != null) ...[
             const SizedBox(height: 8),
             _InfoRow(label: 'Sucursal', value: order.branch!.name),
          ],
          
          const Divider(height: 32),

          // Totals
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
