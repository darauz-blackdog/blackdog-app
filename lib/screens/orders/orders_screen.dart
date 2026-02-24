import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/order.dart';
import '../../providers/orders_provider.dart';
import '../../theme/app_theme.dart';

import '../../widgets/fade_in_up.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, we fetch the first page of orders without status filter
    final ordersAsync = ref.watch(orderListProvider(const OrderListParams()));

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Pedidos')),
      body: ordersAsync.when(
        data: (result) {
          if (result.orders.isEmpty) {
            return FadeInUp(child: _buildEmptyState(context));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: result.orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return FadeInUp(
                delay: index * 100, // Staggered delay
                child: _OrderCard(order: result.orders[index]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.textLight,
              ),
              const SizedBox(height: 16),
              Text('Error: $err'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.refresh(orderListProvider(const OrderListParams())),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No tienes pedidos aún',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tus compras aparecerán aquí',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Ir a comprar'),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final date = order.createdAt != null
        ? DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(DateTime.parse(order.createdAt!).toLocal())
        : 'Fecha desconocida';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}', extra: order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${order.odooOrderName ?? order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _StatusChip(status: order.status, label: order.statusLabel),
                ],
              ),
              const SizedBox(height: 8),
              Text(date, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 16,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${order.items.length} productos',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    '\$${order.total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final String label;

  const _StatusChip({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'delivered':
        color = AppColors.success;
        break;
      case 'cancelled':
        color = AppColors.error;
        break;
      case 'confirmed':
      case 'ready_pickup':
      case 'shipping':
        color = AppColors.info;
        break;
      default:
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
