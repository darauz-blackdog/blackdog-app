import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order.dart';
import '../../providers/orders_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fade_in_up.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  static const _steps = [
    _TrackingStep(status: 'confirmed', label: 'Confirmado', icon: Icons.check_circle_outline),
    _TrackingStep(status: 'preparing', label: 'Preparando', icon: Icons.inventory_2_outlined),
    _TrackingStep(status: 'ready_pickup', label: 'Listo', icon: Icons.store_outlined),
    _TrackingStep(status: 'shipping', label: 'En camino', icon: Icons.local_shipping_outlined),
    _TrackingStep(status: 'delivered', label: 'Entregado', icon: Icons.check_circle),
  ];

  int _statusIndex(String status) {
    final idx = _steps.indexWhere((s) => s.status == status);
    return idx >= 0 ? idx : -1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento')),
      body: orderAsync.when(
        data: (order) => _buildContent(context, order),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Order order) {
    final currentIdx = _statusIndex(order.status);
    final isCancelled = order.status == 'cancelled';

    // Find latest tracking with driver info
    final driverTracking = order.tracking
        .where((t) => t.driverName != null && t.driverName!.isNotEmpty)
        .toList();
    final driver = driverTracking.isNotEmpty ? driverTracking.last : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order header
          FadeInUp(
            delay: 0,
            offset: 15,
            duration: const Duration(milliseconds: 400),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedido #${order.odooOrderName ?? order.id.substring(0, 8).toUpperCase()}',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      color: isCancelled ? AppColors.error : AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Cancelled state
          if (isCancelled)
            FadeInUp(
              delay: 100,
              offset: 15,
              duration: const Duration(milliseconds: 400),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined,
                        color: AppColors.error, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pedido cancelado',
                              style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error)),
                          const SizedBox(height: 4),
                          Text(
                            'Este pedido fue cancelado.',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Timeline
          if (!isCancelled) ...[
            FadeInUp(
              delay: 100,
              offset: 15,
              duration: const Duration(milliseconds: 400),
              child: Text(
                'Estado del pedido',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_steps.length, (i) {
              final step = _steps[i];
              final isCompleted = i <= currentIdx;
              final isCurrent = i == currentIdx;

              // Find tracking entry for this step
              final trackingEntry = order.tracking
                  .where((t) => t.status == step.status)
                  .toList();
              final timestamp = trackingEntry.isNotEmpty
                  ? trackingEntry.last.createdAt
                  : null;

              return FadeInUp(
                delay: 150 + i * 80,
                offset: 15,
                duration: const Duration(milliseconds: 400),
                child: _TimelineItem(
                  step: step,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  isLast: i == _steps.length - 1,
                  timestamp: timestamp,
                  message: trackingEntry.isNotEmpty
                      ? trackingEntry.last.message
                      : null,
                ),
              );
            }),
          ],

          // Driver info
          if (driver != null) ...[
            const SizedBox(height: 24),
            FadeInUp(
              delay: 500,
              offset: 15,
              duration: const Duration(milliseconds: 400),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delivery_dining,
                          color: AppColors.info, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Repartidor',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            driver.driverName!,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (driver.driverPhone != null)
                      IconButton(
                        onPressed: () async {
                          final uri = Uri.parse(
                              'tel:${driver.driverPhone}');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone,
                              color: Colors.white, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _TrackingStep {
  final String status;
  final String label;
  final IconData icon;

  const _TrackingStep({
    required this.status,
    required this.label,
    required this.icon,
  });
}

class _TimelineItem extends StatelessWidget {
  final _TrackingStep step;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;
  final String? timestamp;
  final String? message;

  const _TimelineItem({
    required this.step,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
    this.timestamp,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? (isCurrent ? AppColors.primary : AppColors.success)
        : AppColors.textLight.withValues(alpha: 0.4);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: isCurrent ? 32 : 24,
                  height: isCurrent ? 32 : 24,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? color.withValues(alpha: 0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    isCompleted ? step.icon : Icons.circle_outlined,
                    size: isCurrent ? 16 : 12,
                    color: color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isCompleted
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.textLight.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCompleted
                          ? Theme.of(context).colorScheme.onSurface
                          : AppColors.textLight,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(timestamp!),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                  if (message != null && message!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM, hh:mm a').format(date);
    } catch (_) {
      return '';
    }
  }
}
